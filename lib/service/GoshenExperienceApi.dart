import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/GoshenExperience.dart';
import '../models/Userdata.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';

class GoshenExperienceApi {
  GoshenExperienceApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static final Map<String, List<GoshenExperienceSurvey>> _surveyCache = {};

  List<GoshenExperienceSurvey>? cachedSurveys(Userdata? user) =>
      _surveyCache[_userCacheKey(user)];

  Future<List<GoshenExperienceSurvey>> fetchSurveys(Userdata? user) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_EXPERIENCE,
      options: user == null ? null : _mobileOptions(user),
      data: user == null
          ? null
          : {
              'email': user.email,
              'api_token': user.apiToken,
            },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load Goshen Experience.');
    }

    final surveys = ((data['data'] as List?) ?? const [])
        .map((item) =>
            GoshenExperienceSurvey.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    _surveyCache[_userCacheKey(user)] = surveys;
    return surveys;
  }

  Future<String> submitSurvey({
    required Userdata user,
    required GoshenExperienceSurvey survey,
    required String story,
    required Map<String, dynamic> answers,
    String? audioPath,
    int? audioDurationSeconds,
  }) async {
    final form = FormData.fromMap({
      'email': user.email,
      'api_token': user.apiToken,
      'story': story,
      for (final entry in answers.entries)
        'answers[${entry.key}]': entry.value is Map || entry.value is List
            ? jsonEncode(entry.value)
            : entry.value,
      if (audioPath != null) 'audio': await MultipartFile.fromFile(audioPath),
      if (audioDurationSeconds != null)
        'audio_duration_seconds': audioDurationSeconds,
    });

    final response = await _dio.post(
      ApiUrl.goshenExperienceSurvey('${survey.id}'),
      options: _mobileOptions(user),
      data: form,
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to submit your experience.');
    }

    return '${data['message'] ?? 'Thank you for sharing your Goshen Experience.'}';
  }

  Future<GoshenExperienceStats> fetchStats({
    required Userdata user,
    required String eventId,
  }) async {
    final response = await _dio.post(
      ApiUrl.goshenExperienceStats('$eventId'),
      options: _mobileOptions(user),
      data: {
        'email': user.email,
        'api_token': user.apiToken,
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load experience stats.');
    }

    return GoshenExperienceStats.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Future<GoshenExperienceSurveySummary> updateSurveySettings({
    required Userdata user,
    required GoshenExperienceSurveySummary survey,
    bool? isActive,
    bool? allowAudio,
    bool? allowVideo,
    bool? allowAllAuthenticatedUsers,
  }) async {
    final payload = <String, dynamic>{
      'email': user.email,
      'api_token': user.apiToken,
      if (isActive != null) 'is_active': isActive,
      if (allowAudio != null) 'allow_audio': allowAudio,
      if (allowVideo != null) 'allow_video': allowVideo,
      if (allowAllAuthenticatedUsers != null)
        'allow_all_authenticated_users': allowAllAuthenticatedUsers,
    };

    final response = await _dio.post(
      ApiUrl.goshenExperienceSurveySettings('${survey.id}'),
      options: _mobileOptions(user),
      data: payload,
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to update survey settings.');
    }

    final surveyJson = data['survey'];
    if (surveyJson is! Map) {
      throw const FormatException(
          'Survey settings response did not include survey data.');
    }

    return GoshenExperienceSurveySummary.fromJson(
      Map<String, dynamic>.from(surveyJson),
    );
  }

  Options _mobileOptions(Userdata user) {
    final token = (user.apiToken ?? '').trim();
    return Options(
      validateStatus: (status) => status != null && status < 500,
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  String _userCacheKey(Userdata? user) {
    if (user == null) return 'guest';
    final token = (user.apiToken ?? '').trim();
    return token.isNotEmpty ? token : '${user.email ?? ''}'.trim();
  }
}
