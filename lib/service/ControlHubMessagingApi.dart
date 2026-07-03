import 'package:dio/dio.dart';

import '../models/Userdata.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';

class ControlHubMessagingApi {
  ControlHubMessagingApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<ControlHubMessageOptions> fetchOptions(Userdata user) async {
    final response = await _dio.post(
      ApiUrl.CONTROL_HUB_MESSAGE_OPTIONS,
      options: _mobileOptions(user),
      data: {'data': _authPayload(user)},
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load message options.');
    }

    return ControlHubMessageOptions.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Future<ControlHubMessageResult> send({
    required Userdata user,
    required String title,
    required String content,
    required String notificationCategory,
    required bool sendInbox,
    required bool sendPush,
    required bool sendEmail,
    required String recipientMode,
    List<String> countries = const [],
    List<String> genders = const [],
    List<int> roleIds = const [],
    int? goshenEventId,
    String? goshenPaidFrom,
    String? goshenPaidUntil,
    int? goshenRecentDays,
    String? goshenPaidWeek,
    String? goshenPaidMonth,
    int? fundraisingCampaignId,
    int? goshenQuizId,
    DateTime? scheduledFor,
  }) async {
    final response = await _dio.post(
      ApiUrl.CONTROL_HUB_MESSAGE_SEND,
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          'title': title,
          'content': content,
          'notification_category': notificationCategory,
          'send_inbox': sendInbox,
          'send_push': sendPush,
          'send_email': sendEmail,
          'recipient_mode': recipientMode,
          if (countries.isNotEmpty) 'selected_country_of_residences': countries,
          if (genders.isNotEmpty) 'selected_genders': genders,
          if (roleIds.isNotEmpty) 'selected_role_ids': roleIds,
          if (goshenEventId != null) 'goshen_event_id': goshenEventId,
          if (goshenPaidFrom != null) 'goshen_paid_from': goshenPaidFrom,
          if (goshenPaidUntil != null) 'goshen_paid_until': goshenPaidUntil,
          if (goshenRecentDays != null) 'goshen_recent_days': goshenRecentDays,
          if (goshenPaidWeek != null) 'goshen_paid_week': goshenPaidWeek,
          if (goshenPaidMonth != null) 'goshen_paid_month': goshenPaidMonth,
          if (fundraisingCampaignId != null)
            'fundraising_campaign_id': fundraisingCampaignId,
          if (goshenQuizId != null) 'goshen_quiz_id': goshenQuizId,
          if (scheduledFor != null) ...{
            'schedule_enabled': true,
            'scheduled_at': scheduledFor.toIso8601String(),
          },
        }
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to send admin message.');
    }

    return ControlHubMessageResult.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> _authPayload(Userdata user) {
    return {
      'email': user.email,
      'api_token': user.apiToken,
    };
  }

  Options _mobileOptions(Userdata user) {
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
      return Map<String, dynamic>.from(decodeApiResponse(value));
    } on FormatException {
      throw Exception('The server returned an unexpected response.');
    } on TypeError {
      throw Exception('The message response was not in the expected format.');
    }
  }
}

class ControlHubMessageOptions {
  const ControlHubMessageOptions({
    required this.categories,
    required this.countries,
    required this.genders,
    required this.roles,
    required this.goshenEvents,
    required this.fundraisingCampaigns,
    required this.quizzes,
    required this.personalizationTags,
  });

  final List<ControlHubMessageOption> categories;
  final List<String> countries;
  final List<String> genders;
  final List<ControlHubRoleOption> roles;
  final List<ControlHubIdOption> goshenEvents;
  final List<ControlHubIdOption> fundraisingCampaigns;
  final List<ControlHubIdOption> quizzes;
  final List<ControlHubPersonalizationTag> personalizationTags;

  factory ControlHubMessageOptions.fromJson(Map<String, dynamic> json) {
    return ControlHubMessageOptions(
      categories: ((json['categories'] as List?) ?? const [])
          .map((item) => ControlHubMessageOption.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      countries: ((json['countries'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      genders: ((json['genders'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      roles: ((json['roles'] as List?) ?? const [])
          .map((item) => ControlHubRoleOption.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      goshenEvents: ((json['goshen_events'] as List?) ?? const [])
          .map((item) => ControlHubIdOption.fromJson(
                Map<String, dynamic>.from(item),
                labelKeys: const ['name', 'title', 'label'],
              ))
          .toList(),
      fundraisingCampaigns:
          ((json['fundraising_campaigns'] as List?) ?? const [])
              .map((item) => ControlHubIdOption.fromJson(
                    Map<String, dynamic>.from(item),
                    labelKeys: const ['title', 'name', 'label'],
                  ))
              .toList(),
      quizzes: ((json['quizzes'] as List?) ?? const [])
          .map((item) => ControlHubIdOption.fromJson(
                Map<String, dynamic>.from(item),
                labelKeys: const ['title', 'name', 'label'],
              ))
          .toList(),
      personalizationTags: ((json['personalization_tags'] as List?) ?? const [])
          .map((item) => ControlHubPersonalizationTag.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => item.tag.trim().isNotEmpty)
          .toList(),
    );
  }
}

class ControlHubPersonalizationTag {
  const ControlHubPersonalizationTag({
    required this.tag,
    required this.label,
    required this.example,
  });

  final String tag;
  final String label;
  final String example;

  factory ControlHubPersonalizationTag.fromJson(Map<String, dynamic> json) {
    return ControlHubPersonalizationTag(
      tag: '${json['tag'] ?? ''}',
      label: '${json['label'] ?? json['tag'] ?? ''}',
      example: '${json['example'] ?? ''}',
    );
  }
}

class ControlHubMessageOption {
  const ControlHubMessageOption({required this.key, required this.label});

  final String key;
  final String label;

  factory ControlHubMessageOption.fromJson(Map<String, dynamic> json) {
    return ControlHubMessageOption(
      key: '${json['key'] ?? ''}',
      label: '${json['label'] ?? json['key'] ?? ''}',
    );
  }
}

class ControlHubRoleOption {
  const ControlHubRoleOption({required this.id, required this.name});

  final int id;
  final String name;

  factory ControlHubRoleOption.fromJson(Map<String, dynamic> json) {
    return ControlHubRoleOption(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: '${json['name'] ?? ''}',
    );
  }
}

class ControlHubIdOption {
  const ControlHubIdOption({required this.id, required this.label});

  final int id;
  final String label;

  factory ControlHubIdOption.fromJson(
    Map<String, dynamic> json, {
    List<String> labelKeys = const ['label', 'name', 'title'],
  }) {
    String label = '';
    for (final key in labelKeys) {
      final value = '${json[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        label = value;
        break;
      }
    }

    return ControlHubIdOption(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      label: label.isEmpty ? '${json['id'] ?? ''}' : label,
    );
  }
}

class ControlHubMessageResult {
  const ControlHubMessageResult({
    required this.id,
    required this.title,
    required this.pushSentCount,
    required this.pushFailedCount,
    required this.emailSentCount,
    required this.emailFailedCount,
    required this.scheduled,
    this.pushLastError,
    this.emailLastError,
  });

  final int id;
  final String title;
  final int pushSentCount;
  final int pushFailedCount;
  final int emailSentCount;
  final int emailFailedCount;
  final bool scheduled;
  final String? pushLastError;
  final String? emailLastError;

  factory ControlHubMessageResult.fromJson(Map<String, dynamic> json) {
    return ControlHubMessageResult(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      title: '${json['title'] ?? ''}',
      pushSentCount: int.tryParse('${json['push_sent_count'] ?? 0}') ?? 0,
      pushFailedCount: int.tryParse('${json['push_failed_count'] ?? 0}') ?? 0,
      emailSentCount: int.tryParse('${json['email_sent_count'] ?? 0}') ?? 0,
      emailFailedCount: int.tryParse('${json['email_failed_count'] ?? 0}') ?? 0,
      scheduled: json['scheduled'] == true || '${json['scheduled']}' == '1',
      pushLastError: json['push_last_error']?.toString(),
      emailLastError: json['email_last_error']?.toString(),
    );
  }
}
