import 'dart:convert';

import 'package:dio/dio.dart';

import '../../models/Userdata.dart';
import '../../utils/ApiUrl.dart';
import 'counseling_models.dart';

class CounselingApi {
  CounselingApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<CounselingCasePage> fetchCases(Userdata user, {int page = 1}) async {
    final response = await _send(() => _dio.get(
          ApiUrl.COUNSELING_CASES,
          queryParameters: {'page': page, 'per_page': 20},
          options: _options(user),
        ));
    return CounselingCasePage.fromJson(_decodeMap(response.data));
  }

  Future<CounselingCase> fetchCase(Userdata user, int caseId) async {
    final response = await _send(() => _dio.get(
          ApiUrl.counselingCase(caseId.toString()),
          options: _options(user),
        ));
    return CounselingCase.fromJson(_extractData(response.data));
  }

  Future<CounselingCase> createCase({
    required Userdata user,
    required String body,
    String? subject,
    String? category,
    String priority = 'normal',
    String? audioPath,
    int? audioDurationSeconds,
  }) async {
    final formData = FormData.fromMap({
      if ((subject ?? '').trim().isNotEmpty) 'subject': subject!.trim(),
      if ((category ?? '').trim().isNotEmpty) 'category': category!.trim(),
      'priority': priority,
      'country_code': _countryCode(user.countryOfResidence),
      'locale': 'en',
      'timezone': DateTime.now().timeZoneName,
      'message_type': audioPath == null ? 'text' : 'audio',
      if (body.trim().isNotEmpty) 'body': body.trim(),
      if (audioPath != null) ...{
        'audio_duration_seconds': (audioDurationSeconds ?? 1).clamp(1, 300),
        'audio': MultipartFile.fromFileSync(
          audioPath,
          filename: _fileName(audioPath),
        ),
      },
    });

    final response = await _send(() => _dio.post(
          ApiUrl.COUNSELING_CASES,
          data: formData,
          options: _options(user, multipart: true),
        ));
    return CounselingCase.fromJson(_extractData(response.data));
  }

  Future<CounselingMessage> sendMessage({
    required Userdata user,
    required int caseId,
    required String body,
    String? audioPath,
    int? audioDurationSeconds,
  }) async {
    final formData = FormData.fromMap({
      'message_type': audioPath == null ? 'text' : 'audio',
      if (body.trim().isNotEmpty) 'body': body.trim(),
      if (audioPath != null) ...{
        'audio_duration_seconds': (audioDurationSeconds ?? 1).clamp(1, 300),
        'audio': MultipartFile.fromFileSync(
          audioPath,
          filename: _fileName(audioPath),
        ),
      },
    });

    final response = await _send(() => _dio.post(
          ApiUrl.counselingCaseMessages(caseId.toString()),
          data: formData,
          options: _options(user, multipart: true),
        ));
    final data = _extractData(response.data);
    return CounselingMessage.fromJson(data);
  }

  Future<CounselingCase> closeCase({
    required Userdata user,
    required int caseId,
    String? reason,
  }) async {
    final response = await _send(() => _dio.post(
          ApiUrl.counselingCaseClose(caseId.toString()),
          data: {
            if ((reason ?? '').trim().isNotEmpty) 'reason': reason!.trim(),
          },
          options: _options(user),
        ));
    return CounselingCase.fromJson(_extractData(response.data));
  }

  String absoluteAudioUrl(String? url) {
    final value = (url ?? '').trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return '${ApiUrl.BASEURL.substring(0, ApiUrl.BASEURL.length - 1)}$value';
    }
    return '${ApiUrl.BASEURL}$value';
  }

  Map<String, String> authHeaders(Userdata user) {
    final token = (user.apiToken ?? '').trim();
    return {
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
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

  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      if ((response.statusCode ?? 500) >= 400) {
        throw CounselingApiException(
          _messageFromResponse(response) ??
              'Counseling service is unavailable.',
        );
      }
      return response;
    } on DioException catch (error) {
      throw CounselingApiException(
        _messageFromResponse(error.response) ??
            'Counseling service is unavailable.',
      );
    }
  }

  Map<String, dynamic> _extractData(dynamic value) {
    final decoded = _decodeMap(value);
    final data = decoded['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return decoded;
  }

  Map<String, dynamic> _decodeMap(dynamic value) {
    if (value is String) {
      final decoded = json.decode(value);
      return Map<String, dynamic>.from(decoded as Map);
    }
    return Map<String, dynamic>.from(value as Map? ?? {});
  }

  String? _messageFromResponse(Response<dynamic>? response) {
    if (response == null) return null;
    try {
      final data = _decodeMap(response.data);
      final message = data['message'] ?? data['msg'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
    } catch (_) {}
    return null;
  }

  String? _countryCode(String? value) {
    final country = (value ?? '').trim().toUpperCase();
    if (country.length == 2) return country;
    return null;
  }

  static String _fileName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? 'counseling-voice-note.wav' : parts.last;
  }
}

class CounselingApiException implements Exception {
  CounselingApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
