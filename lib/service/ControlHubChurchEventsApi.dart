import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../models/ChurchEventManagement.dart';
import '../models/Userdata.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';

class ControlHubChurchEventsApi {
  ControlHubChurchEventsApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<List<ChurchEventManagement>> fetchEvents(
    Userdata user, {
    String query = '',
  }) async {
    final response = await _dio.post(
      ApiUrl.CONTROL_HUB_CHURCH_EVENTS_SEARCH,
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
      throw Exception(data['message'] ?? 'Unable to load church events.');
    }

    final payload = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;
    final events = payload['events'] ?? payload['data'] ?? payload['items'];
    return ((events as List?) ?? const [])
        .whereType<Map>()
        .map((item) =>
            ChurchEventManagement.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ChurchEventManagement> createEvent({
    required Userdata user,
    required Map<String, dynamic> payload,
    PlatformFile? thumbnail,
    PlatformFile? portraitImage,
  }) async {
    final response = await _dio.post(
      ApiUrl.CONTROL_HUB_CHURCH_EVENTS,
      options: _options(user, multipart: true),
      data: await _formData(
        user: user,
        payload: payload,
        thumbnail: thumbnail,
        portraitImage: portraitImage,
      ),
    );

    return _eventFromResponse(response.data, 'Unable to create church event.');
  }

  Future<ChurchEventManagement> updateEvent({
    required Userdata user,
    required ChurchEventManagement event,
    required Map<String, dynamic> payload,
    PlatformFile? thumbnail,
    PlatformFile? portraitImage,
  }) async {
    final response = await _dio.post(
      ApiUrl.controlHubChurchEvent('${event.id}'),
      options: _options(user, multipart: true),
      data: await _formData(
        user: user,
        payload: payload,
        thumbnail: thumbnail,
        portraitImage: portraitImage,
      ),
    );

    return _eventFromResponse(response.data, 'Unable to update church event.');
  }

  Future<ChurchEventManagement> updateStatus({
    required Userdata user,
    required ChurchEventManagement event,
    required bool isPublished,
  }) async {
    final response = await _dio.post(
      ApiUrl.controlHubChurchEventStatus('${event.id}'),
      options: _options(user),
      data: {
        'data': {
          ..._authPayload(user),
          'is_published': isPublished,
        }
      },
    );

    return _eventFromResponse(response.data, 'Unable to update church event.');
  }

  Future<void> deleteEvent({
    required Userdata user,
    required ChurchEventManagement event,
  }) async {
    final response = await _dio.post(
      ApiUrl.controlHubChurchEventDelete('${event.id}'),
      options: _options(user),
      data: {'data': _authPayload(user)},
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to delete church event.');
    }
  }

  Future<FormData> _formData({
    required Userdata user,
    required Map<String, dynamic> payload,
    PlatformFile? thumbnail,
    PlatformFile? portraitImage,
  }) async {
    final formData = FormData();
    formData.fields.add(
      MapEntry(
        'data',
        jsonEncode({
          ..._authPayload(user),
          ...payload,
        }),
      ),
    );

    await _appendFile(formData, 'thumbnail', thumbnail);
    await _appendFile(formData, 'portrait_image', portraitImage);

    return formData;
  }

  Future<void> _appendFile(
    FormData formData,
    String field,
    PlatformFile? file,
  ) async {
    final path = file?.path;
    if (file == null || path == null || path.trim().isEmpty) return;
    formData.files.add(MapEntry(
      field,
      await MultipartFile.fromFile(path, filename: file.name),
    ));
  }

  ChurchEventManagement _eventFromResponse(dynamic value, String fallback) {
    final data = _decodeMap(value);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? fallback);
    }

    final raw = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;
    return ChurchEventManagement.fromJson(raw);
  }

  Map<String, dynamic> _authPayload(Userdata user) {
    return {
      'email': user.email,
      'api_token': user.apiToken,
    };
  }

  Options _options(Userdata user, {bool multipart = false}) {
    final token = (user.apiToken ?? '').trim();
    return Options(
      validateStatus: (status) => status != null && status < 600,
      headers: {
        'Accept': 'application/json',
        if (!multipart) 'Content-Type': 'application/json',
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
      throw Exception('The server returned an unexpected response.');
    } on TypeError {
      throw Exception(
          'The church event response was not in the expected format.');
    }
  }
}
