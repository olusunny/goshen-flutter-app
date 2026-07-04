class ChurchEventManagement {
  const ChurchEventManagement({
    required this.id,
    required this.title,
    required this.details,
    required this.venue,
    required this.theme,
    required this.bibleVerse,
    required this.host,
    required this.otherMinisters,
    required this.thumbnail,
    required this.thumbnailUrl,
    required this.portraitImage,
    required this.portraitImageUrl,
    required this.registrationUrl,
    required this.registrationAvailability,
    required this.startsAt,
    required this.endsAt,
    required this.isPublished,
    required this.isPilgrimage,
    required this.recurrenceType,
    required this.recurrenceInterval,
    required this.recurrenceWeekday,
    required this.recurrenceWeekOfMonth,
    required this.recurrenceUntil,
    required this.recurrenceLabel,
  });

  final int id;
  final String title;
  final String details;
  final String venue;
  final String theme;
  final String bibleVerse;
  final String host;
  final String otherMinisters;
  final String thumbnail;
  final String thumbnailUrl;
  final String portraitImage;
  final String portraitImageUrl;
  final String registrationUrl;
  final String registrationAvailability;
  final String startsAt;
  final String endsAt;
  final bool isPublished;
  final bool isPilgrimage;
  final String recurrenceType;
  final int recurrenceInterval;
  final int? recurrenceWeekday;
  final int? recurrenceWeekOfMonth;
  final String recurrenceUntil;
  final String recurrenceLabel;

  factory ChurchEventManagement.fromJson(Map<String, dynamic> json) {
    return ChurchEventManagement(
      id: _readInt(json['id']),
      title: _readString(json, const ['title']),
      details: _readString(json, const ['details']),
      venue: _readString(json, const ['venue']),
      theme: _readString(json, const ['theme']),
      bibleVerse: _readString(json, const ['bible_verse', 'bibleVerse']),
      host: _readString(json, const ['host']),
      otherMinisters:
          _readString(json, const ['other_ministers', 'otherMinisters']),
      thumbnail: _readString(json, const ['thumbnail']),
      thumbnailUrl: _readString(json, const ['thumbnail_url', 'thumbnailUrl']),
      portraitImage:
          _readString(json, const ['portrait_image', 'portraitImage']),
      portraitImageUrl:
          _readString(json, const ['portrait_image_url', 'portraitImageUrl']),
      registrationUrl:
          _readString(json, const ['registration_url', 'registrationUrl']),
      registrationAvailability: _readString(
          json, const ['registration_availability', 'registrationAvailability'],
          fallback: 'everywhere'),
      startsAt: _readString(json, const ['starts_at', 'startsAt']),
      endsAt: _readString(json, const ['ends_at', 'endsAt']),
      isPublished: _readBool(json['is_published'] ?? json['isPublished']),
      isPilgrimage: _readBool(json['is_pilgrimage'] ?? json['isPilgrimage']),
      recurrenceType: _readString(
          json, const ['recurrence_type', 'recurrenceType'],
          fallback: 'none'),
      recurrenceInterval: _readInt(
          json['recurrence_interval'] ?? json['recurrenceInterval'],
          fallback: 1),
      recurrenceWeekday: _readNullableInt(
          json['recurrence_weekday'] ?? json['recurrenceWeekday']),
      recurrenceWeekOfMonth: _readNullableInt(
          json['recurrence_week_of_month'] ?? json['recurrenceWeekOfMonth']),
      recurrenceUntil:
          _readString(json, const ['recurrence_until', 'recurrenceUntil']),
      recurrenceLabel:
          _readString(json, const ['recurrence_label', 'recurrenceLabel']),
    );
  }

  DateTime? get startDateTime => _parseServerDate(startsAt);
  DateTime? get endDateTime => _parseServerDate(endsAt);
  DateTime? get recurrenceUntilDate => _parseServerDate(recurrenceUntil);
  bool get isRecurring => recurrenceType != 'none';

  String get statusLabel => isPublished ? 'Published' : 'Draft';
}

DateTime? _parseServerDate(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final raw = json[key]?.toString().trim() ?? '';
    if (raw.isNotEmpty && raw.toLowerCase() != 'null') return raw;
  }
  return fallback;
}

int _readInt(dynamic value, {int fallback = 0}) {
  return int.tryParse('${value ?? ''}') ?? fallback;
}

int? _readNullableInt(dynamic value) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return int.tryParse(text);
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  final text = '${value ?? ''}'.trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes';
}
