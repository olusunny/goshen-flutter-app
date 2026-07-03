import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/Userdata.dart';
import '../utils/ApiUrl.dart';
import 'testimony_models.dart';

class TestimonyApiClient {
  TestimonyApiClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static bool? _enabledCache;
  static List<Testimony>? _testimoniesCache;

  bool? get cachedEnabled => _enabledCache;

  List<Testimony>? get cachedTestimonies => _testimoniesCache;

  Future<bool> isEnabled() async {
    final response = await _dio.get(ApiUrl.TESTIMONIES_STATUS);
    final data = _decode(response.data);
    final enabled = data is Map && data['enabled'] != false;
    _enabledCache = enabled;
    return enabled;
  }

  Future<List<Testimony>> fetchTestimonies({int page = 1}) async {
    final response = await _dio.get(
      ApiUrl.TESTIMONIES,
      queryParameters: {'page': page},
    );
    final data = _decode(response.data);
    final list = _extractList(data, ['testimonies', 'items', 'data']);
    final testimonies = list.map((item) => Testimony.fromJson(item)).toList();
    if (page == 1) _testimoniesCache = testimonies;
    return testimonies;
  }

  Future<Testimony> submit({
    required Userdata user,
    required String title,
    required String body,
    required bool anonymous,
    String? audioPath,
    int audioDuration = 0,
  }) async {
    final payload = <String, dynamic>{
      'email': user.email,
      'api_token': user.apiToken,
      'title': title,
      'body': body,
      'is_anonymous': anonymous ? 1 : 0,
      if (audioPath != null && audioPath.isNotEmpty)
        'audio_duration_seconds': audioDuration.clamp(1, 120).toInt(),
    };
    final formData = FormData.fromMap({'data': jsonEncode(payload)});
    if (audioPath != null && audioPath.isNotEmpty) {
      formData.files.add(MapEntry(
        'audio',
        MultipartFile.fromFileSync(audioPath, filename: _fileName(audioPath)),
      ));
    }

    final response = await _send(
      () => _dio.post(
        ApiUrl.TESTIMONIES,
        data: formData,
        options: _authOptions(user),
      ),
    );
    final data = _decode(response.data);
    final testimony = _extractObject(data, ['testimony', 'item', 'data']);
    return Testimony.fromJson(testimony);
  }

  Options _authOptions(Userdata user) {
    return Options(headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer ${user.apiToken ?? ''}',
    });
  }

  Future<Response<dynamic>> _send(
      Future<Response<dynamic>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw TestimonyApiException(_messageFromResponse(e.response) ??
          'Testimony service is unavailable.');
    }
  }

  static dynamic _decode(dynamic data) {
    if (data is String) {
      try {
        return json.decode(data);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  static List<Map<String, dynamic>> _extractList(
      dynamic data, List<String> keys) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final value = data[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return [];
  }

  static Map<String, dynamic> _extractObject(dynamic data, List<String> keys) {
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final value = data[key];
        if (value is Map) return Map<String, dynamic>.from(value);
      }
      return data;
    }
    return {};
  }

  static String? _messageFromResponse(Response<dynamic>? response) {
    final data = _decode(response?.data);
    if (data is Map) {
      return (data['message'] ?? data['msg'])?.toString();
    }
    return null;
  }

  static String _fileName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? 'testimony-audio.m4a' : parts.last;
  }
}

class TestimonyApiException implements Exception {
  TestimonyApiException(this.message);

  final String message;
}
