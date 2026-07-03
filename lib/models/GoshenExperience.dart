class GoshenExperienceSurvey {
  GoshenExperienceSurvey({
    required this.id,
    required this.title,
    required this.description,
    required this.allowAudio,
    required this.allowVideo,
    required this.allowAllAuthenticatedUsers,
    required this.alreadySubmitted,
    required this.eligibleToSubmit,
    required this.questions,
    this.eventId,
    this.eventPublicId,
    this.eventName,
    this.opensAt,
    this.closesAt,
    this.myResponse,
  });

  final int id;
  final String title;
  final String description;
  final bool allowAudio;
  final bool allowVideo;
  final bool allowAllAuthenticatedUsers;
  final bool alreadySubmitted;
  final bool eligibleToSubmit;
  final int? eventId;
  final String? eventPublicId;
  final String? eventName;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final List<GoshenExperienceQuestion> questions;
  final GoshenExperienceResponse? myResponse;

  factory GoshenExperienceSurvey.fromJson(Map<String, dynamic> json) {
    final event = _asMap(json['event']);
    return GoshenExperienceSurvey(
      id: _asInt(json['id']),
      title: '${json['title'] ?? 'Goshen Experience'}',
      description: '${json['description'] ?? ''}',
      allowAudio: _asBool(json['allow_audio']),
      allowVideo: _asBool(json['allow_video']),
      allowAllAuthenticatedUsers:
          _asBool(json['allow_all_authenticated_users']),
      alreadySubmitted: _asBool(json['already_submitted']),
      eligibleToSubmit: _asBool(json['eligible_to_submit']),
      eventId: event['id'] == null ? null : _asInt(event['id']),
      eventPublicId: event['public_id']?.toString(),
      eventName: event['name']?.toString(),
      opensAt: _asDate(json['opens_at']),
      closesAt: _asDate(json['closes_at']),
      questions: ((json['questions'] as List?) ?? const [])
          .map((item) => GoshenExperienceQuestion.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
      myResponse: json['my_response'] is Map
          ? GoshenExperienceResponse.fromJson(
              Map<String, dynamic>.from(json['my_response'] as Map),
            )
          : null,
    );
  }
}

class GoshenExperienceQuestion {
  GoshenExperienceQuestion({
    required this.id,
    required this.prompt,
    required this.type,
    required this.options,
    required this.settings,
    required this.conditionalLogic,
    required this.isRequired,
    required this.sortOrder,
  });

  final int id;
  final String prompt;
  final String type;
  final List<GoshenExperienceQuestionOption> options;
  final Map<String, dynamic> settings;
  final GoshenQuestionCondition conditionalLogic;
  final bool isRequired;
  final int sortOrder;

  int get ratingMax {
    final value = _asInt(settings['rating_max']);
    if (value < 1) return 5;
    if (value > 10) return 10;
    return value;
  }

  bool get requireRatingReason => _asBool(settings['require_rating_reason']);

  String get ratingReasonLabel {
    final label = '${settings['rating_reason_label'] ?? ''}'.trim();
    return label.isEmpty ? 'Tell us the reason for your rating' : label;
  }

  factory GoshenExperienceQuestion.fromJson(Map<String, dynamic> json) {
    return GoshenExperienceQuestion(
      id: _asInt(json['id']),
      prompt: '${json['prompt'] ?? ''}',
      type: '${json['type'] ?? 'textarea'}',
      options: ((json['options'] as List?) ?? const [])
          .map(GoshenExperienceQuestionOption.fromJson)
          .where((option) => option.value.isNotEmpty)
          .toList(),
      settings: _asMap(json['settings']),
      conditionalLogic: GoshenQuestionCondition.fromJson(
        _asMap(json['conditional_logic']),
      ),
      isRequired: _asBool(json['is_required']),
      sortOrder: _asInt(json['sort_order']),
    );
  }
}

class GoshenExperienceQuestionOption {
  const GoshenExperienceQuestionOption({
    required this.label,
    required this.value,
    this.imagePath,
    this.imageUrl,
    this.colorHex,
  });

  final String label;
  final String value;
  final String? imagePath;
  final String? imageUrl;
  final String? colorHex;

  factory GoshenExperienceQuestionOption.fromJson(dynamic json) {
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      final label = '${map['label'] ?? map['value'] ?? ''}'.trim();
      final value = '${map['value'] ?? label}'.trim();
      final color = '${map['color_hex'] ?? ''}'.trim();

      return GoshenExperienceQuestionOption(
        label: label.isEmpty ? value : label,
        value: value.isEmpty ? label : value,
        imagePath: map['image_path']?.toString(),
        imageUrl: map['image_url']?.toString(),
        colorHex: color.isEmpty ? null : _normalizeColorHex(color),
      );
    }

    final value = '$json'.trim();
    return GoshenExperienceQuestionOption(label: value, value: value);
  }
}

class GoshenQuestionCondition {
  const GoshenQuestionCondition({
    required this.enabled,
    required this.questionId,
    required this.operator,
    required this.value,
  });

  final bool enabled;
  final int questionId;
  final String operator;
  final String value;

  factory GoshenQuestionCondition.fromJson(Map<String, dynamic> json) {
    return GoshenQuestionCondition(
      enabled: _asBool(json['enabled']),
      questionId: _asInt(json['question_id']),
      operator: '${json['operator'] ?? 'equals'}',
      value: '${json['value'] ?? ''}',
    );
  }
}

class GoshenExperienceResponse {
  GoshenExperienceResponse({
    required this.id,
    required this.answers,
    this.story,
    this.audioUrl,
    this.audioDurationSeconds,
    this.videoUrl,
    this.videoDurationSeconds,
    this.submittedAt,
  });

  final int id;
  final String? story;
  final Map<String, dynamic> answers;
  final String? audioUrl;
  final int? audioDurationSeconds;
  final String? videoUrl;
  final int? videoDurationSeconds;
  final DateTime? submittedAt;

  factory GoshenExperienceResponse.fromJson(Map<String, dynamic> json) {
    return GoshenExperienceResponse(
      id: _asInt(json['id']),
      story: json['story']?.toString(),
      answers: _asMap(json['answers']),
      audioUrl: json['audio_url']?.toString(),
      audioDurationSeconds: json['audio_duration_seconds'] == null
          ? null
          : _asInt(json['audio_duration_seconds']),
      videoUrl: json['video_url']?.toString(),
      videoDurationSeconds: json['video_duration_seconds'] == null
          ? null
          : _asInt(json['video_duration_seconds']),
      submittedAt: _asDate(json['submitted_at']),
    );
  }
}

class GoshenExperienceStats {
  GoshenExperienceStats({
    required this.checkedInAttendees,
    required this.responses,
    required this.responseRate,
    required this.byGender,
    required this.byCountry,
    required this.byState,
    required this.byAgeGroup,
    required this.surveys,
    required this.questionStats,
    required this.recentResponses,
  });

  final int checkedInAttendees;
  final int responses;
  final double responseRate;
  final Map<String, int> byGender;
  final Map<String, int> byCountry;
  final Map<String, int> byState;
  final Map<String, int> byAgeGroup;
  final List<GoshenExperienceSurveySummary> surveys;
  final List<GoshenSurveyQuestionStats> questionStats;
  final List<GoshenSurveyRecentResponse> recentResponses;

  factory GoshenExperienceStats.fromJson(Map<String, dynamic> json) {
    return GoshenExperienceStats(
      checkedInAttendees: _asInt(json['checked_in_attendees']),
      responses: _asInt(json['responses']),
      responseRate: _asDouble(json['response_rate']),
      byGender: _asIntMap(json['by_gender']),
      byCountry: _asIntMap(json['by_country']),
      byState: _asIntMap(json['by_state']),
      byAgeGroup: _asIntMap(json['by_age_group']),
      surveys: ((json['surveys'] as List?) ?? const [])
          .map((item) => GoshenExperienceSurveySummary.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
      questionStats: ((json['question_stats'] as List?) ?? const [])
          .map((item) => GoshenSurveyQuestionStats.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
      recentResponses: ((json['recent_responses'] as List?) ?? const [])
          .map((item) => GoshenSurveyRecentResponse.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class GoshenExperienceSurveySummary {
  const GoshenExperienceSurveySummary({
    required this.id,
    required this.title,
    required this.isActive,
    required this.allowAudio,
    required this.allowVideo,
    required this.allowAllAuthenticatedUsers,
    required this.questionsCount,
    required this.responsesCount,
  });

  final int id;
  final String title;
  final bool isActive;
  final bool allowAudio;
  final bool allowVideo;
  final bool allowAllAuthenticatedUsers;
  final int questionsCount;
  final int responsesCount;

  factory GoshenExperienceSurveySummary.fromJson(Map<String, dynamic> json) {
    return GoshenExperienceSurveySummary(
      id: _asInt(json['id']),
      title: '${json['title'] ?? 'Goshen Experience'}',
      isActive: _asBool(json['is_active']),
      allowAudio: _asBool(json['allow_audio']),
      allowVideo: _asBool(json['allow_video']),
      allowAllAuthenticatedUsers:
          _asBool(json['allow_all_authenticated_users']),
      questionsCount: _asInt(json['questions_count']),
      responsesCount: _asInt(json['responses_count']),
    );
  }
}

class GoshenSurveyQuestionStats {
  const GoshenSurveyQuestionStats({
    required this.questionId,
    required this.surveyId,
    required this.prompt,
    required this.type,
    required this.isRequired,
    required this.responses,
    required this.breakdown,
    required this.samples,
  });

  final int questionId;
  final int surveyId;
  final String prompt;
  final String type;
  final bool isRequired;
  final int responses;
  final List<GoshenSurveyAnswerBreakdown> breakdown;
  final List<String> samples;

  factory GoshenSurveyQuestionStats.fromJson(Map<String, dynamic> json) {
    return GoshenSurveyQuestionStats(
      questionId: _asInt(json['question_id']),
      surveyId: _asInt(json['survey_id']),
      prompt: '${json['prompt'] ?? 'Question'}',
      type: '${json['type'] ?? 'text'}',
      isRequired: _asBool(json['is_required']),
      responses: _asInt(json['responses']),
      breakdown: ((json['breakdown'] as List?) ?? const [])
          .map((item) => GoshenSurveyAnswerBreakdown.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
      samples: ((json['samples'] as List?) ?? const [])
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }
}

class GoshenSurveyAnswerBreakdown {
  const GoshenSurveyAnswerBreakdown({
    required this.key,
    required this.label,
    required this.count,
    required this.percentage,
    this.imageUrl,
    this.colorHex,
  });

  final String key;
  final String label;
  final int count;
  final double percentage;
  final String? imageUrl;
  final String? colorHex;

  factory GoshenSurveyAnswerBreakdown.fromJson(Map<String, dynamic> json) {
    final imageUrl = '${json['image_url'] ?? ''}'.trim();
    final colorHex = '${json['color_hex'] ?? ''}'.trim();

    return GoshenSurveyAnswerBreakdown(
      key: '${json['key'] ?? ''}',
      label: '${json['label'] ?? json['key'] ?? 'Answer'}',
      count: _asInt(json['count']),
      percentage: _asDouble(json['percentage']),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      colorHex: colorHex.isEmpty ? null : _normalizeColorHex(colorHex),
    );
  }
}

class GoshenSurveyRecentResponse {
  const GoshenSurveyRecentResponse({
    required this.id,
    required this.surveyId,
    required this.surveyTitle,
    required this.memberName,
    required this.memberEmail,
    required this.story,
    required this.answers,
    this.audioUrl,
    this.audioDurationSeconds,
    this.videoUrl,
    this.videoDurationSeconds,
    this.submittedAt,
  });

  final int id;
  final int surveyId;
  final String surveyTitle;
  final String memberName;
  final String memberEmail;
  final String story;
  final List<GoshenSurveyResponseAnswer> answers;
  final String? audioUrl;
  final int? audioDurationSeconds;
  final String? videoUrl;
  final int? videoDurationSeconds;
  final DateTime? submittedAt;

  bool get hasMedia =>
      (audioUrl ?? '').trim().isNotEmpty || (videoUrl ?? '').trim().isNotEmpty;

  factory GoshenSurveyRecentResponse.fromJson(Map<String, dynamic> json) {
    final audioUrl = '${json['audio_url'] ?? ''}'.trim();
    final videoUrl = '${json['video_url'] ?? ''}'.trim();

    return GoshenSurveyRecentResponse(
      id: _asInt(json['id']),
      surveyId: _asInt(json['survey_id']),
      surveyTitle: '${json['survey_title'] ?? 'Goshen Experience'}',
      memberName: '${json['member_name'] ?? 'Member'}',
      memberEmail: '${json['member_email'] ?? ''}',
      story: '${json['story'] ?? ''}'.trim(),
      answers: ((json['answers'] as List?) ?? const [])
          .map((item) => GoshenSurveyResponseAnswer.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
      audioUrl: audioUrl.isEmpty ? null : audioUrl,
      audioDurationSeconds: json['audio_duration_seconds'] == null
          ? null
          : _asInt(json['audio_duration_seconds']),
      videoUrl: videoUrl.isEmpty ? null : videoUrl,
      videoDurationSeconds: json['video_duration_seconds'] == null
          ? null
          : _asInt(json['video_duration_seconds']),
      submittedAt: _asDate(json['submitted_at']),
    );
  }
}

class GoshenSurveyResponseAnswer {
  const GoshenSurveyResponseAnswer({
    required this.questionId,
    required this.prompt,
    required this.type,
    required this.answer,
  });

  final int questionId;
  final String prompt;
  final String type;
  final String answer;

  factory GoshenSurveyResponseAnswer.fromJson(Map<String, dynamic> json) {
    return GoshenSurveyResponseAnswer(
      questionId: _asInt(json['question_id']),
      prompt: '${json['prompt'] ?? 'Question'}',
      type: '${json['type'] ?? 'text'}',
      answer: '${json['answer'] ?? ''}',
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return {'1', 'true', 'yes', 'on'}.contains('$value'.toLowerCase());
}

DateTime? _asDate(dynamic value) {
  if (value == null || '$value'.isEmpty) return null;
  return DateTime.tryParse('$value');
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

Map<String, int> _asIntMap(dynamic value) {
  final map = _asMap(value);
  return map.map((key, value) => MapEntry('$key', _asInt(value)));
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

String _normalizeColorHex(String value) {
  final clean = value.trim().replaceFirst('#', '');
  final isHex = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(clean);
  return isHex ? '#${clean.toLowerCase()}' : '#ffffff';
}
