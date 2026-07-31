class ChurchBirthdayCapability {
  const ChurchBirthdayCapability({
    required this.active,
    this.eligible = false,
    this.eligibilityVerified = false,
  });

  final bool active;
  final bool eligible;
  final bool eligibilityVerified;

  bool get canOpenMemberExperience => active && eligibilityVerified && eligible;

  ChurchBirthdayCapability withEligibility(bool value) =>
      ChurchBirthdayCapability(
        active: active,
        eligible: value,
        eligibilityVerified: true,
      );
}

class BirthdayCelebrationPreferences {
  const BirthdayCelebrationPreferences({
    required this.eligible,
    required this.visibilityEnabled,
    required this.greetingsEnabled,
    required this.useProfilePhoto,
    this.preferredName,
    this.templateId,
    this.verseId,
  });

  final bool eligible;
  final bool visibilityEnabled;
  final bool greetingsEnabled;
  final bool useProfilePhoto;
  final String? preferredName;
  final int? templateId;
  final int? verseId;

  factory BirthdayCelebrationPreferences.fromJson(Map<String, dynamic> json,
          {bool eligible = false}) =>
      BirthdayCelebrationPreferences(
        eligible: eligible || _readBool(json['eligible']),
        visibilityEnabled:
            _readBool(json['visibility_enabled'], fallback: true),
        greetingsEnabled: _readBool(json['greetings_enabled'], fallback: true),
        useProfilePhoto: _readBool(json['use_profile_photo'], fallback: true),
        preferredName: _optionalString(json['preferred_name']),
        templateId: _readId(json['template_id']),
        verseId: _readId(json['verse_id']),
      );

  BirthdayCelebrationPreferences copyWith({
    bool? eligible,
    bool? visibilityEnabled,
    bool? greetingsEnabled,
    bool? useProfilePhoto,
    String? preferredName,
    int? templateId,
    int? verseId,
    bool clearTemplate = false,
    bool clearVerse = false,
  }) =>
      BirthdayCelebrationPreferences(
        eligible: eligible ?? this.eligible,
        visibilityEnabled: visibilityEnabled ?? this.visibilityEnabled,
        greetingsEnabled: greetingsEnabled ?? this.greetingsEnabled,
        useProfilePhoto: useProfilePhoto ?? this.useProfilePhoto,
        preferredName: preferredName ?? this.preferredName,
        templateId: clearTemplate ? null : templateId ?? this.templateId,
        verseId: clearVerse ? null : verseId ?? this.verseId,
      );
}

class BirthdayPresentationChoice {
  const BirthdayPresentationChoice({
    required this.id,
    required this.label,
    this.description,
  });

  final int id;
  final String label;
  final String? description;

  factory BirthdayPresentationChoice.template(Map<String, dynamic> json) =>
      BirthdayPresentationChoice(
        id: _readId(json['id']) ?? 0,
        label: '${json['name'] ?? 'Birthday template'}',
        description: json['is_default'] == true || json['is_default'] == 1
            ? 'Default template'
            : 'Version ${json['version'] ?? 1}',
      );

  factory BirthdayPresentationChoice.verse(Map<String, dynamic> json) =>
      BirthdayPresentationChoice(
        id: _readId(json['id']) ?? 0,
        label: '${json['reference'] ?? 'Bible verse'}',
        description: _optionalString(json['body']),
      );
}

class ChurchBirthdayContext {
  const ChurchBirthdayContext({
    required this.capability,
    required this.preferences,
    this.templates = const [],
    this.verses = const [],
  });

  final ChurchBirthdayCapability capability;
  final BirthdayCelebrationPreferences preferences;
  final List<BirthdayPresentationChoice> templates;
  final List<BirthdayPresentationChoice> verses;
}

class BirthdayCelebrationMember {
  const BirthdayCelebrationMember({
    required this.id,
    required this.displayName,
    required this.dayMonth,
    required this.state,
    required this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String dayMonth;
  final String state;
  final String avatarUrl;

  factory BirthdayCelebrationMember.fromJson(Map<String, dynamic> json) =>
      BirthdayCelebrationMember(
        id: '${json['id'] ?? json['celebration_id'] ?? ''}',
        displayName:
            '${json['name'] ?? json['display_name'] ?? 'Church member'}',
        dayMonth: '${json['birthday_month_day'] ?? json['day_month'] ?? ''}',
        state: '${json['status'] ?? json['state'] ?? ''}',
        avatarUrl: '${json['avatar_url'] ?? json['avatar'] ?? ''}'.trim(),
      );
}

class BirthdayCelebrationHub {
  const BirthdayCelebrationHub({required this.today, required this.upcoming});

  final List<BirthdayCelebrationMember> today;
  final List<BirthdayCelebrationMember> upcoming;

  factory BirthdayCelebrationHub.fromJson(Map<String, dynamic> json) {
    List<BirthdayCelebrationMember> rows(String key) => ((json[key] as List?) ??
            const [])
        .whereType<Map>()
        .map((row) =>
            BirthdayCelebrationMember.fromJson(Map<String, dynamic>.from(row)))
        .where((member) => member.id.isNotEmpty)
        .toList();
    return BirthdayCelebrationHub(
        today: rows('today'), upcoming: rows('upcoming'));
  }

  List<BirthdayCelebrationMember> upcomingWithinDays(int days,
      {DateTime? now}) {
    final today = now ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day);

    return upcoming.where((member) {
      final parts = member.dayMonth.split('-');
      if (parts.length != 2) return false;
      final month = int.tryParse(parts[0]);
      final day = int.tryParse(parts[1]);
      if (month == null || day == null) return false;

      DateTime date;
      try {
        date = DateTime(start.year, month, day);
      } catch (_) {
        return false;
      }
      if (date.month != month || date.day != day) return false;
      if (date.isBefore(start)) date = DateTime(start.year + 1, month, day);
      final difference = date.difference(start).inDays;
      return difference >= 1 && difference <= days;
    }).toList();
  }
}

class BirthdayGreeting {
  const BirthdayGreeting({
    required this.id,
    required this.body,
    this.isMine = false,
    this.createdAt,
  });

  final int id;
  final String body;
  final bool isMine;
  final DateTime? createdAt;

  factory BirthdayGreeting.fromJson(Map<String, dynamic> json) =>
      BirthdayGreeting(
        id: int.tryParse('${json['id'] ?? ''}') ?? 0,
        body: '${json['body'] ?? ''}',
        isMine: _readBool(json['is_mine']),
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      );
}

class BirthdayCelebrationDetail extends BirthdayCelebrationMember {
  const BirthdayCelebrationDetail({
    required super.id,
    required super.displayName,
    required super.dayMonth,
    required super.state,
    required super.avatarUrl,
    required this.isCelebrant,
    required this.reactions,
    required this.greetings,
    required this.isInteractive,
    this.myGreetingId,
    this.closesAt,
    this.thankYou,
  });

  final bool isCelebrant;
  final bool isInteractive;
  final int? myGreetingId;
  final DateTime? closesAt;
  final String? thankYou;
  final Map<String, int> reactions;
  final List<BirthdayGreeting> greetings;

  factory BirthdayCelebrationDetail.fromJson(Map<String, dynamic> json) {
    final reactionValues =
        Map<String, dynamic>.from(json['reactions'] as Map? ?? const {});
    return BirthdayCelebrationDetail(
      id: '${json['id'] ?? ''}',
      displayName: '${json['name'] ?? json['display_name'] ?? 'Church member'}',
      dayMonth: '${json['birthday_month_day'] ?? json['day_month'] ?? ''}',
      state: '${json['status'] ?? ''}',
      avatarUrl: '${json['avatar_url'] ?? json['avatar'] ?? ''}'.trim(),
      isCelebrant: _readBool(json['is_celebrant']),
      isInteractive: _readBool(json['is_interactive']),
      myGreetingId: _readId(json['my_greeting_id']),
      closesAt: DateTime.tryParse('${json['closes_at'] ?? ''}'),
      thankYou: _optionalString(json['thank_you']),
      reactions: reactionValues.map(
        (key, value) => MapEntry(key, int.tryParse('$value') ?? 0),
      ),
      greetings: ((json['greetings'] as List?) ?? const [])
          .whereType<Map>()
          .map((value) =>
              BirthdayGreeting.fromJson(Map<String, dynamic>.from(value)))
          .where(
              (greeting) => greeting.id > 0 && greeting.body.trim().isNotEmpty)
          .toList(),
    );
  }
}

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  return '${value ?? ''}'.trim().toLowerCase() == 'true' ||
      '${value ?? ''}'.trim() == '1';
}

int? _readId(dynamic value) {
  final id = int.tryParse('${value ?? ''}');
  return id != null && id > 0 ? id : null;
}

String? _optionalString(dynamic value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}
