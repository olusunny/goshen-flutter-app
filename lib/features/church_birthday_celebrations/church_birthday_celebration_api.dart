import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../models/Userdata.dart';
import '../../utils/ApiUrl.dart';
import '../../utils/api_response.dart';
import 'church_birthday_celebration_models.dart';

class BirthdayApiException implements Exception {
  const BirthdayApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isUnavailable =>
      statusCode == 403 || statusCode == 404 || statusCode == 410;
  bool get isClosed => statusCode == 409;

  @override
  String toString() => message;
}

class ChurchBirthdayCelebrationApi {
  ChurchBirthdayCelebrationApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<ChurchBirthdayCapability> fetchCapability(Userdata user) async {
    try {
      final response = await _request(user, 'get', ApiUrl.ADDON_CAPABILITIES);
      final capabilities =
          ((response['data'] as Map?)?['capabilities'] as List?) ?? const [];
      final active = capabilities.whereType<Map>().any(
            (item) => item['key']?.toString() == 'church_birthday_celebrations',
          );
      return ChurchBirthdayCapability(active: active);
    } catch (_) {
      return const ChurchBirthdayCapability(active: false);
    }
  }

  Future<ChurchBirthdayContext> context(Userdata user) async {
    final data = _data(await _request(
        user, 'get', ApiUrl.CHURCH_BIRTHDAY_CELEBRATION_CONTEXT));
    final eligible = _bool(data['eligible']);
    final preferences = BirthdayCelebrationPreferences.fromJson(
      Map<String, dynamic>.from(data['preferences'] as Map? ?? const {}),
      eligible: eligible,
    );
    return ChurchBirthdayContext(
      capability: ChurchBirthdayCapability(
        active:
            data['capability']?.toString() == 'church_birthday_celebrations',
        eligible: eligible,
        eligibilityVerified: true,
      ),
      preferences: preferences,
      templates:
          _choices(data['templates'], BirthdayPresentationChoice.template),
      verses: _choices(data['verses'], BirthdayPresentationChoice.verse),
    );
  }

  Future<ChurchBirthdayContext> updatePreferences(
    Userdata user,
    BirthdayCelebrationPreferences preferences,
  ) async {
    final data = _data(await _request(
      user,
      'put',
      ApiUrl.CHURCH_BIRTHDAY_CELEBRATION_PREFERENCES,
      body: {
        'visibility_enabled': preferences.visibilityEnabled,
        'greetings_enabled': preferences.greetingsEnabled,
        'use_profile_photo': preferences.useProfilePhoto,
        'preferred_name': preferences.preferredName?.trim() ?? '',
        'template_id': preferences.templateId,
        'verse_id': preferences.verseId,
      },
    ));
    final eligible = _bool(data['eligible']);
    return ChurchBirthdayContext(
      capability: ChurchBirthdayCapability(
        active: true,
        eligible: eligible,
        eligibilityVerified: true,
      ),
      preferences: BirthdayCelebrationPreferences.fromJson(
        Map<String, dynamic>.from(data['preferences'] as Map? ?? const {}),
        eligible: eligible,
      ),
      templates:
          _choices(data['templates'], BirthdayPresentationChoice.template),
      verses: _choices(data['verses'], BirthdayPresentationChoice.verse),
    );
  }

  Future<BirthdayCelebrationHub> hub(Userdata user) async =>
      BirthdayCelebrationHub.fromJson(
        _data(await _request(
            user, 'get', ApiUrl.CHURCH_BIRTHDAY_CELEBRATION_HUB)),
      );

  Future<BirthdayCelebrationDetail> detail(Userdata user, String id) async =>
      BirthdayCelebrationDetail.fromJson(_data(await _request(
        user,
        'get',
        ApiUrl.churchBirthdayCelebration(id),
      )));

  Future<void> react(Userdata user, String id, String? reaction) => _request(
        user,
        'put',
        ApiUrl.churchBirthdayCelebrationReaction(id),
        body: {'reaction': reaction},
      );

  Future<BirthdayGreeting> greet(
    Userdata user,
    String id,
    String body,
  ) async {
    final data = _data(await _request(
      user,
      'put',
      ApiUrl.churchBirthdayCelebrationGreeting(id),
      body: {
        'body': body.trim(),
        'idempotency_key': '${DateTime.now().microsecondsSinceEpoch}',
      },
    ));
    return BirthdayGreeting.fromJson(
      Map<String, dynamic>.from(data['greeting'] as Map? ?? const {}),
    );
  }

  Future<void> deleteGreeting(Userdata user, String id, int greetingId) =>
      _request(user, 'delete',
          ApiUrl.churchBirthdayCelebrationGreetingById(id, greetingId));

  Future<void> thank(Userdata user, String id, String body) => _request(
        user,
        'put',
        ApiUrl.churchBirthdayCelebrationThankYou(id),
        body: {'body': body.trim()},
      );

  Future<void> report(
    Userdata user,
    String id,
    int greetingId,
    String reason,
  ) =>
      _request(
        user,
        'post',
        ApiUrl.churchBirthdayCelebrationGreetingReport(id, greetingId),
        body: {'reason': reason.trim()},
      );

  Future<void> requestCorrection(
    Userdata user, {
    required int month,
    required int day,
    String? reason,
  }) =>
      _request(
        user,
        'post',
        ApiUrl.CHURCH_BIRTHDAY_CELEBRATION_CORRECTIONS,
        body: {
          'birthday_month': month,
          'birthday_day': day,
          'reason': reason?.trim() ?? '',
        },
      );

  Future<Uint8List> card(Userdata user, String id,
      {String variant = 'portrait'}) async {
    final response = await _dio.get<List<int>>(
      ApiUrl.churchBirthdayCelebrationCard(id, variant: variant),
      options: _options(user).copyWith(responseType: ResponseType.bytes),
    );
    if (response.statusCode != 200 || response.data == null) {
      throw BirthdayApiException('This birthday card is unavailable.',
          statusCode: response.statusCode);
    }
    return Uint8List.fromList(response.data!);
  }

  Future<Map<String, dynamic>> _request(
    Userdata user,
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _dio.request<dynamic>(
      url,
      data: body,
      options: _options(user).copyWith(method: method),
    );
    final mapped = _map(response.data, response.statusCode);
    return mapped;
  }

  Map<String, dynamic> _data(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(response['data'] as Map? ?? const {});

  Map<String, dynamic> _map(dynamic value, int? statusCode) {
    final decoded = decodeApiResponse(value);
    final data = Map<String, dynamic>.from(decoded as Map? ?? const {});
    if ((statusCode ?? 500) >= 400 ||
        (data['status'] != null && data['status'] != 'ok')) {
      throw BirthdayApiException(
        '${data['message'] ?? 'Birthday celebrations are unavailable.'}',
        statusCode: statusCode,
        code: data['code']?.toString(),
      );
    }
    return data;
  }

  Options _options(Userdata user) => Options(
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          if ((user.apiToken ?? '').trim().isNotEmpty)
            'Authorization': 'Bearer ${user.apiToken}',
        },
        validateStatus: (status) => status != null && status < 500,
      );
}

List<BirthdayPresentationChoice> _choices(
  dynamic source,
  BirthdayPresentationChoice Function(Map<String, dynamic>) parse,
) =>
    (source as List? ?? const [])
        .whereType<Map>()
        .map((row) => parse(Map<String, dynamic>.from(row)))
        .where((choice) => choice.id > 0)
        .toList();

bool _bool(dynamic value) =>
    value == true ||
    value == 1 ||
    '${value ?? ''}'.trim() == '1' ||
    '${value ?? ''}'.trim().toLowerCase() == 'true';
