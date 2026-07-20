import 'package:churchapp_flutter/models/SplashMedia.dart';
import 'package:churchapp_flutter/service/SplashMediaService.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses enabled splash media config', () {
    final config = SplashMediaConfig.fromJson({
      'enabled': true,
      'media_type': 'video',
      'version': 42,
      'checksum': 'ABCDEF',
      'media_url': 'https://example.test/splash.mp4',
      'duration_ms': '5000',
      'updated_at': '2026-07-20T09:01:29Z',
    });

    expect(config.enabled, isTrue);
    expect(config.mediaType, SplashMediaType.video);
    expect(config.version, '42');
    expect(config.checksum, 'abcdef');
    expect(config.hasRemoteMedia, isTrue);
    expect(config.durationMs, 5000);
    expect(config.updatedAt?.toUtc().year, 2026);
  });

  test('detects unchanged cached splash by checksum or version', () {
    final service = SplashMediaService();
    final cached = CachedSplashMedia(
      localPath: '/tmp/splash.mp4',
      config: SplashMediaConfig.fromJson({
        'enabled': true,
        'media_type': 'video',
        'version': '20260720-1',
        'checksum': 'a' * 64,
      }),
    );

    expect(
      service.cacheMatches(
        cached,
        SplashMediaConfig.fromJson({
          'enabled': true,
          'media_type': 'video',
          'version': '20260720-2',
          'checksum': 'a' * 64,
        }),
      ),
      isTrue,
    );

    expect(
      service.cacheMatches(
        cached,
        SplashMediaConfig.fromJson({
          'enabled': true,
          'media_type': 'video',
          'version': '20260720-1',
          'checksum': 'b' * 64,
        }),
      ),
      isTrue,
    );

    expect(
      service.cacheMatches(
        cached,
        SplashMediaConfig.fromJson({
          'enabled': true,
          'media_type': 'image',
          'version': '20260720-1',
          'checksum': 'a' * 64,
        }),
      ),
      isFalse,
    );
  });

  test('disabled remote config is not treated as usable media', () {
    final config = SplashMediaConfig.fromJson({
      'enabled': false,
      'media_type': 'video',
      'version': '20260720-1',
      'checksum': 'a' * 64,
      'media_url': 'https://example.test/splash.mp4',
    });

    expect(config.enabled, isFalse);
    expect(config.hasRemoteMedia, isFalse);
  });
}
