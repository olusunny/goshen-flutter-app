class SplashMediaConfig {
  const SplashMediaConfig({
    required this.enabled,
    required this.mediaType,
    required this.version,
    required this.checksum,
    required this.mediaUrl,
    required this.thumbnailUrl,
    required this.durationMs,
    required this.updatedAt,
  });

  final bool enabled;
  final String? mediaType;
  final String? version;
  final String? checksum;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? durationMs;
  final DateTime? updatedAt;

  bool get hasRemoteMedia =>
      enabled &&
      (mediaType == SplashMediaType.image ||
          mediaType == SplashMediaType.video) &&
      mediaUrl != null &&
      mediaUrl!.trim().isNotEmpty;

  factory SplashMediaConfig.fromJson(Map<String, dynamic> json) {
    return SplashMediaConfig(
      enabled: _truthy(json['enabled']),
      mediaType: _clean(json['media_type']),
      version: _clean(json['version']),
      checksum: _clean(json['checksum'])?.toLowerCase(),
      mediaUrl: _clean(json['media_url']),
      thumbnailUrl: _clean(json['thumbnail_url']),
      durationMs: _intOrNull(json['duration_ms']),
      updatedAt: _dateOrNull(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'media_type': mediaType,
        'version': version,
        'checksum': checksum,
        'media_url': mediaUrl,
        'thumbnail_url': thumbnailUrl,
        'duration_ms': durationMs,
        'updated_at': updatedAt?.toIso8601String(),
      };

  static bool _truthy(Object? value) {
    if (value is bool) return value;
    final text = '$value'.trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes';
  }

  static String? _clean(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  static int? _intOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('$value');
  }

  static DateTime? _dateOrNull(Object? value) {
    final text = _clean(value);
    return text == null ? null : DateTime.tryParse(text);
  }
}

class CachedSplashMedia {
  const CachedSplashMedia({
    required this.config,
    required this.localPath,
  });

  final SplashMediaConfig config;
  final String localPath;

  Map<String, dynamic> toJson() => {
        'config': config.toJson(),
        'local_path': localPath,
      };

  factory CachedSplashMedia.fromJson(Map<String, dynamic> json) {
    return CachedSplashMedia(
      config: SplashMediaConfig.fromJson(
        Map<String, dynamic>.from(json['config'] as Map? ?? {}),
      ),
      localPath: '${json['local_path'] ?? ''}',
    );
  }
}

class SplashMediaType {
  static const image = 'image';
  static const video = 'video';
}
