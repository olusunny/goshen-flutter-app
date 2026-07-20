import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/SplashMedia.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';

class SplashMediaService {
  SplashMediaService({Dio? dio, SharedPreferences? prefs})
      : _dio = dio ?? Dio(),
        _prefs = prefs;

  static const bundledFallbackAsset = 'assets/splash/default-splash-video.mp4';
  static const bundledFallbackDurationMs = 5000;

  static const _cacheKey = 'managed_splash_media_cache_v1';
  static const _cacheDirName = 'managed_splash_media';

  final Dio _dio;
  SharedPreferences? _prefs;

  Future<CachedSplashMedia?> loadCached() async {
    final prefs = await _preferences();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final cached = CachedSplashMedia.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (cached.localPath.trim().isEmpty) return null;
      if (!await File(cached.localPath).exists()) return null;
      return cached;
    } catch (_) {
      return null;
    }
  }

  Future<SplashMediaConfig?> fetchConfig() async {
    final response = await _dio.get(
      ApiUrl.APP_SPLASH_MEDIA,
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: const {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );

    if ((response.statusCode ?? 0) >= 400) return null;

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    return SplashMediaConfig.fromJson(data);
  }

  Future<CachedSplashMedia?> refreshInBackground({
    CachedSplashMedia? current,
  }) async {
    try {
      final config = await fetchConfig();
      if (config == null) return current;
      if (!config.enabled) {
        await clearCached();
        return null;
      }
      if (!config.hasRemoteMedia) return current;
      if (current != null && cacheMatches(current, config)) return current;

      return await _downloadAndCache(config) ?? current;
    } catch (_) {
      return current;
    }
  }

  Future<void> clearCached() async {
    final prefs = await _preferences();
    await prefs.remove(_cacheKey);

    try {
      final dir = await _cacheDirectory();
      await for (final entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  bool cacheMatches(CachedSplashMedia cached, SplashMediaConfig next) {
    final versionMatches = next.version != null &&
        cached.config.version != null &&
        next.version == cached.config.version;
    final checksumMatches = next.checksum != null &&
        cached.config.checksum != null &&
        next.checksum == cached.config.checksum;

    return cached.config.enabled &&
        cached.config.mediaType == next.mediaType &&
        (checksumMatches || versionMatches);
  }

  SplashMediaConfig bundledFallbackConfig() {
    return SplashMediaConfig(
      enabled: true,
      mediaType: SplashMediaType.video,
      version: 'bundled-default',
      checksum: null,
      mediaUrl: null,
      thumbnailUrl: null,
      durationMs: bundledFallbackDurationMs,
      updatedAt: null,
    );
  }

  Future<CachedSplashMedia?> _downloadAndCache(SplashMediaConfig config) async {
    final url = config.mediaUrl;
    if (url == null || url.trim().isEmpty) return null;

    final dir = await _cacheDirectory();
    final extension = _extensionFor(config);
    final baseName = _safeVersion(config);
    final targetPath = p.join(dir.path, '$baseName$extension');
    final temporaryPath = p.join(dir.path, '$baseName.tmp');

    final response = await _dio.download(
      url,
      temporaryPath,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'Accept': '*/*'},
      ),
    );

    if ((response.statusCode ?? 0) >= 400) {
      await _deleteQuietly(temporaryPath);
      return null;
    }

    if (!await _checksumIsValid(temporaryPath, config.checksum)) {
      await _deleteQuietly(temporaryPath);
      return null;
    }

    final file = File(temporaryPath);
    if (await File(targetPath).exists()) {
      await File(targetPath).delete();
    }
    await file.rename(targetPath);

    final cached = CachedSplashMedia(config: config, localPath: targetPath);
    final prefs = await _preferences();
    await prefs.setString(_cacheKey, jsonEncode(cached.toJson()));
    unawaited(_removeOldFiles(dir, targetPath));

    return cached;
  }

  Future<Directory> _cacheDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, _cacheDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _extensionFor(SplashMediaConfig config) {
    final uriExtension = config.mediaUrl == null
        ? ''
        : p.extension(Uri.parse(config.mediaUrl!).path).toLowerCase();
    if (uriExtension == '.jpg' ||
        uriExtension == '.jpeg' ||
        uriExtension == '.png' ||
        uriExtension == '.webp' ||
        uriExtension == '.mp4') {
      return uriExtension;
    }
    return config.mediaType == SplashMediaType.image ? '.jpg' : '.mp4';
  }

  String _safeVersion(SplashMediaConfig config) {
    final seed = (config.checksum?.isNotEmpty == true
            ? config.checksum
            : config.version ?? DateTime.now().millisecondsSinceEpoch)
        .toString();
    return seed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  Future<bool> _checksumIsValid(String path, String? expected) async {
    if (expected == null || expected.trim().isEmpty) return true;
    final bytes = await File(path).readAsBytes();
    return sha256.convert(bytes).toString().toLowerCase() ==
        expected.toLowerCase();
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _removeOldFiles(Directory dir, String keepPath) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path != keepPath) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  Future<SharedPreferences> _preferences() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }
}
