import 'package:dio/dio.dart';

import '../models/Userdata.dart';
import '../models/VerseOfDayManagement.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';

class ControlHubVerseOfDayApi {
  ControlHubVerseOfDayApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<List<VerseOfDayManagement>> fetchVerses(
    Userdata user, {
    String query = '',
  }) async {
    final response = await _dio.post(
      ApiUrl.CONTROL_HUB_VERSE_OF_DAY_SEARCH,
      options: _options(user),
      data: {
        'data': {
          ..._authPayload(user),
          if (query.trim().isNotEmpty) 'query': query.trim(),
        }
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load Verse of the Day.');
    }

    final payload = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;
    final verses = payload['verses'] ?? payload['data'] ?? payload['items'];
    return ((verses as List?) ?? const [])
        .whereType<Map>()
        .map((item) =>
            VerseOfDayManagement.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<VerseOfDayManagement> createVerse({
    required Userdata user,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.post(
      ApiUrl.CONTROL_HUB_VERSE_OF_DAY,
      options: _options(user),
      data: {
        'data': {..._authPayload(user), ...payload}
      },
    );

    return _verseFromResponse(response.data, 'Unable to create verse.');
  }

  Future<VerseOfDayManagement> updateVerse({
    required Userdata user,
    required VerseOfDayManagement verse,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.post(
      ApiUrl.controlHubVerseOfDay('${verse.id}'),
      options: _options(user),
      data: {
        'data': {..._authPayload(user), ...payload}
      },
    );

    return _verseFromResponse(response.data, 'Unable to update verse.');
  }

  Future<VerseOfDayManagement> updateStatus({
    required Userdata user,
    required VerseOfDayManagement verse,
    required bool isPublished,
  }) async {
    final response = await _dio.post(
      ApiUrl.controlHubVerseOfDayStatus('${verse.id}'),
      options: _options(user),
      data: {
        'data': {
          ..._authPayload(user),
          'is_published': isPublished,
        }
      },
    );

    return _verseFromResponse(response.data, 'Unable to update verse.');
  }

  Future<void> deleteVerse({
    required Userdata user,
    required VerseOfDayManagement verse,
  }) async {
    final response = await _dio.post(
      ApiUrl.controlHubVerseOfDayDelete('${verse.id}'),
      options: _options(user),
      data: {'data': _authPayload(user)},
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to delete verse.');
    }
  }

  VerseOfDayManagement _verseFromResponse(dynamic value, String fallback) {
    final data = _decodeMap(value);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? fallback);
    }

    final raw = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;
    return VerseOfDayManagement.fromJson(raw);
  }

  Map<String, dynamic> _authPayload(Userdata user) {
    return {
      'email': user.email,
      'api_token': user.apiToken,
    };
  }

  Options _options(Userdata user) {
    final token = (user.apiToken ?? '').trim();
    return Options(
      validateStatus: (status) => status != null && status < 600,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  Map<String, dynamic> _decodeMap(dynamic value) {
    try {
      final decoded = decodeApiResponse(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{};
    } on FormatException {
      throw Exception(
        'The server returned a web page instead of app data.',
      );
    } on TypeError {
      throw Exception(
        'The Verse of the Day response was not in the expected format.',
      );
    }
  }
}
