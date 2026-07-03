import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/Userdata.dart';
import '../utils/ApiUrl.dart';
import 'prayer_models.dart';

class PrayerApiClient {
  PrayerApiClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static final Map<String, PrayerFeed> _feedCache = {};
  static PropheticDecree? _decreeCache;
  static bool _hasDecreeCache = false;

  PrayerFeed? cachedPrayerFeed(Userdata? user) =>
      _feedCache[_userCacheKey(user)];

  PropheticDecree? get cachedActivePropheticDecree =>
      _hasDecreeCache ? _decreeCache : null;

  Future<PrayerFeed> fetchPrayerFeed({Userdata? user, int afterId = 0}) async {
    final response = await _dio.get(
      ApiUrl.PRAYER_COMMUNITY,
      queryParameters: {
        'page': afterId <= 0 ? 1 : afterId,
        if (user != null)
          'data': jsonEncode({
            'email': user.email,
            'api_token': user.apiToken,
          }),
      },
      options: user == null ? null : _authOptions(user),
    );
    final data = _decode(response.data);
    final list = _extractList(data, ['prayer_requests', 'items', 'data']);
    final status =
        data is Map<String, dynamic> && data['submission_status'] is Map
            ? PrayerSubmissionStatus.fromJson(
                Map<String, dynamic>.from(data['submission_status'] as Map),
              )
            : const PrayerSubmissionStatus(canSubmit: true, cooldownSeconds: 0);
    final feed = PrayerFeed(
      requests: list.map((item) => PrayerRequest.fromJson(item)).toList(),
      submissionStatus: status,
    );
    if (afterId <= 0) _feedCache[_userCacheKey(user)] = feed;
    return feed;
  }

  Future<List<PrayerRequest>> fetchPrayers({int afterId = 0}) async {
    return (await fetchPrayerFeed(afterId: afterId)).requests;
  }

  Future<PropheticDecree?> fetchActivePropheticDecree() async {
    final response = await _dio.get(ApiUrl.PROPHETIC_DECREE);
    final data = _decode(response.data);
    final decree = _extractObject(
        data, ['prophetic_decree', 'decree', 'active_decree', 'item', 'data']);
    if (decree.isEmpty) {
      _hasDecreeCache = true;
      _decreeCache = null;
      return null;
    }
    final parsed = PropheticDecree.fromJson(decree);
    final active = parsed.active ? parsed : null;
    _hasDecreeCache = true;
    _decreeCache = active;
    return active;
  }

  Future<PropheticDecree> submitPropheticDecree({
    required Userdata user,
    required String label,
    required String audioPath,
    int audioDuration = 0,
  }) async {
    final formData = FormData.fromMap({
      'data': jsonEncode({
        'email': user.email,
        'api_token': user.apiToken,
        'title': label,
        'duration': audioDuration,
        'audio_duration_seconds': audioDuration,
      })
    });
    formData.files.add(MapEntry(
      'audio',
      MultipartFile.fromFileSync(audioPath, filename: _fileName(audioPath)),
    ));
    final response = await _send(
      () => _dio.post(
        ApiUrl.PROPHETIC_DECREE,
        data: formData,
        options: _authOptions(user),
      ),
    );
    final data = _decode(response.data);
    final decree = _extractObject(
        data, ['prophetic_decree', 'decree', 'active_decree', 'item', 'data']);
    return PropheticDecree.fromJson(decree);
  }

  Future<PrayerRequest> submitPrayer({
    required Userdata user,
    required String content,
    required bool anonymous,
    String? audioPath,
    int audioDuration = 0,
  }) async {
    final hasAudio = audioPath != null && audioPath.isNotEmpty;
    final payload = <String, dynamic>{
      'email': user.email,
      'api_token': user.apiToken,
      'type': hasAudio ? 'audio' : 'text',
      'text': content,
      'is_anonymous': anonymous ? 1 : 0,
    };
    if (hasAudio) {
      payload['audio_duration_seconds'] = audioDuration.clamp(1, 30).toInt();
    }

    final formData = FormData.fromMap({
      'data': jsonEncode(payload),
    });
    if (hasAudio) {
      formData.files.add(MapEntry(
        'audio',
        MultipartFile.fromFileSync(audioPath, filename: _fileName(audioPath)),
      ));
    }
    final response = await _send(
      () => _dio.post(
        ApiUrl.PRAYER_COMMUNITY,
        data: formData,
        options: _authOptions(user),
      ),
    );
    final data = _decode(response.data);
    final prayer = _extractObject(data, ['prayer_request', 'item', 'data']);
    return PrayerRequest.fromJson(prayer);
  }

  Future<List<PrayerComment>> fetchComments(int prayerId) async {
    final response = await _dio.get('${ApiUrl.PRAYER_COMMUNITY}/$prayerId');
    final data = _decode(response.data);
    final prayer = _extractObject(data, ['prayer_request', 'item', 'data']);
    final list = _extractList(prayer, ['comments']);
    return list.map((item) => PrayerComment.fromJson(item)).toList();
  }

  Future<PrayerComment> submitComment({
    required int prayerId,
    required Userdata user,
    required String content,
    required bool anonymous,
    String? audioPath,
    int audioDuration = 0,
  }) async {
    final hasAudio = audioPath != null && audioPath.isNotEmpty;
    if (hasAudio) {
      final payload = <String, dynamic>{
        'email': user.email,
        'api_token': user.apiToken,
        'type': 'audio',
        'text': content,
        'is_anonymous': anonymous ? 1 : 0,
        'audio_duration_seconds': audioDuration.clamp(1, 10).toInt(),
      };
      final formData = FormData.fromMap({
        'data': jsonEncode(payload),
      });
      formData.files.add(MapEntry(
        'audio',
        MultipartFile.fromFileSync(audioPath, filename: _fileName(audioPath)),
      ));
      final response = await _send(
        () => _dio.post(
          '${ApiUrl.PRAYER_COMMUNITY}/$prayerId/comments',
          data: formData,
          options: _authOptions(user),
        ),
      );
      final data = _decode(response.data);
      final comment = _extractObject(data, ['comment', 'item', 'data']);
      return PrayerComment.fromJson(comment);
    } else {
      final response = await _send(
        () => _dio.post(
          '${ApiUrl.PRAYER_COMMUNITY}/$prayerId/comments',
          data: jsonEncode({
            'data': {
              'email': user.email,
              'api_token': user.apiToken,
              'text': content,
              'is_anonymous': anonymous ? 1 : 0,
            }
          }),
          options: _authOptions(user),
        ),
      );
      final data = _decode(response.data);
      final comment = _extractObject(data, ['comment', 'item', 'data']);
      return PrayerComment.fromJson(comment);
    }
  }

  Future<int> flagPrayer({
    required int prayerId,
    required Userdata user,
    String reason = 'inappropriate',
  }) async {
    final response = await _send(
      () => _dio.post(
        '${ApiUrl.PRAYER_COMMUNITY}/$prayerId/flags',
        data: jsonEncode({
          'data': {
            'email': user.email,
            'api_token': user.apiToken,
            'reason': reason,
          }
        }),
        options: _authOptions(user),
      ),
    );
    final data = _decode(response.data);
    if (data is Map<String, dynamic>) {
      return int.tryParse((data['flags_count'] ?? 0).toString()) ?? 0;
    }
    return 0;
  }

  Future<String> rewritePrayer(Userdata user, String content) async {
    return _aiText(ApiUrl.PRAYER_AI_REWRITE, user, content);
  }

  Future<List<String>> suggestPrayers(Userdata user, String content) async {
    final response = await _send(
      () => _dio.post(
        ApiUrl.PRAYER_AI_SUGGEST,
        data: jsonEncode({
          'data': {
            'email': user.email,
            'api_token': user.apiToken,
            'text': content
          }
        }),
        options: _authOptions(user),
      ),
    );
    final data = _decode(response.data);
    if (data is Map<String, dynamic>) {
      final suggestions = data['suggestions'] ?? data['data'] ?? data['items'];
      if (suggestions is List) {
        return suggestions.map((item) => item.toString()).toList();
      }
      final text = data['suggestion'] ?? data['text'] ?? data['message'];
      if (text != null) return [text.toString()];
    }
    return [];
  }

  /// Ask the AI to explain a Bible verse in depth.
  Future<String> explainBibleVerse(
      Userdata user, String reference, String verseText) async {
    final response = await _send(
      () => _dio.post(
        ApiUrl.AI_BIBLE_EXPLAIN,
        data: jsonEncode({
          'data': {
            'email': user.email,
            'api_token': user.apiToken,
            'reference': reference,
            'text': verseText,
          }
        }),
        options: _authOptions(user),
      ),
    );
    final data = _decode(response.data);
    if (data is Map<String, dynamic>) {
      return (data['explanation'] ?? data['text'] ?? '').toString();
    }
    return '';
  }

  /// Search for Bible verses related to a topic using AI.
  Future<List<Map<String, String>>> searchBibleByTopic(
      Userdata user, String topic) async {
    final response = await _send(
      () => _dio.post(
        ApiUrl.AI_BIBLE_SEARCH,
        data: jsonEncode({
          'data': {
            'email': user.email,
            'api_token': user.apiToken,
            'topic': topic,
          }
        }),
        options: _authOptions(user),
      ),
    );
    final data = _decode(response.data);
    if (data is Map<String, dynamic>) {
      final results = data['results'];
      if (results is List) {
        return results
            .whereType<Map>()
            .map((item) => Map<String, String>.from(
                item.map((k, v) => MapEntry(k.toString(), v.toString()))))
            .toList();
      }
    }
    return [];
  }

  Future<String> uploadProfileImage(Userdata user, String avatarPath) async {
    final formData = FormData.fromMap({
      'email': user.email,
      'api_token': user.apiToken,
      'fullname': user.name,
      'date_of_birth': user.dateOfBirth,
      'phone': user.phone,
      'gender': user.gender,
      'location': user.location,
      'qualification': user.qualification,
      'about_me': user.aboutMe,
      'facebook': user.facebook,
      'twitter': user.twitter,
      'linkedln': user.linkdln,
    });
    formData.files.add(MapEntry(
      'avatar',
      MultipartFile.fromFileSync(avatarPath, filename: _fileName(avatarPath)),
    ));
    final response = await _send(
      () => _dio.post(
        ApiUrl.UPDATE_PROFILE_PHOTO,
        data: formData,
        options: _authOptions(user),
      ),
    );
    final data = _decode(response.data);
    if (data is Map<String, dynamic>) {
      final userJson = data['user'];
      if (userJson is Map<String, dynamic>) {
        return (userJson['avatar'] ?? userJson['profile_photo'] ?? '')
            .toString();
      }
      return (data['avatar'] ?? data['profile_photo'] ?? '').toString();
    }
    return '';
  }

  Future<String> _aiText(String url, Userdata user, String content) async {
    final response = await _send(
      () => _dio.post(
        url,
        data: jsonEncode({
          'data': {
            'email': user.email,
            'api_token': user.apiToken,
            'text': content
          }
        }),
        options: _authOptions(user),
      ),
    );
    final data = _decode(response.data);
    if (data is Map<String, dynamic>) {
      return (data['text'] ??
              data['content'] ??
              data['rewrite'] ??
              data['data'] ??
              '')
          .toString();
    }
    return data.toString();
  }

  dynamic _decode(dynamic value) {
    if (value is String) {
      try {
        return jsonDecode(value);
      } catch (_) {
        return value;
      }
    }
    return value;
  }

  Options _authOptions(Userdata user) {
    final token = (user.apiToken ?? '').trim();
    return Options(
      headers: {
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
  }

  String _userCacheKey(Userdata? user) {
    if (user == null) return 'guest';
    final token = (user.apiToken ?? '').trim();
    return token.isNotEmpty ? token : '${user.email ?? ''}'.trim();
  }

  Future<Response<dynamic>> _send(
      Future<Response<dynamic>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw PrayerApiException(_messageFromResponse(e.response) ??
          e.message ??
          'Prayer request service is unavailable.');
    }
  }

  String? _messageFromResponse(Response<dynamic>? response) {
    if (response == null) return null;
    final data = _decode(response.data);
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
      return (data['msg'] ?? data['message'] ?? data['error'])?.toString();
    }
    return data?.toString();
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last.trim();
    return name.isEmpty ? 'upload.m4a' : name;
  }

  List<Map<String, dynamic>> _extractList(dynamic data, List<String> keys) {
    dynamic current = data;
    if (current is Map<String, dynamic>) {
      for (final key in keys) {
        if (current[key] is List) {
          current = current[key];
          break;
        }
      }
    }
    if (current is List) {
      return current
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> _extractObject(dynamic data, List<String> keys) {
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        if (data[key] is Map) return Map<String, dynamic>.from(data[key]);
      }
      return data;
    }
    return {};
  }
}

class PrayerApiException implements Exception {
  PrayerApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
