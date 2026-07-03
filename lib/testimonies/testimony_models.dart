class Testimony {
  Testimony({
    required this.id,
    required this.title,
    required this.body,
    required this.identity,
    required this.isAnonymous,
    this.avatar,
    this.countryOfResidence,
    this.countryFlag,
    this.audioUrl,
    this.audioDurationSeconds,
    this.createdAt,
    this.approvedAt,
  });

  final int id;
  final String title;
  final String body;
  final String identity;
  final bool isAnonymous;
  final String? avatar;
  final String? countryOfResidence;
  final String? countryFlag;
  final String? audioUrl;
  final int? audioDurationSeconds;
  final DateTime? createdAt;
  final DateTime? approvedAt;

  factory Testimony.fromJson(Map<String, dynamic> json) {
    return Testimony(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? json['content'] ?? ''}',
      identity: '${json['identity'] ?? 'Member'}',
      isAnonymous: _bool(json['is_anonymous']),
      avatar: _stringOrNull(json['avatar']),
      countryOfResidence: _stringOrNull(json['country_of_residence']),
      countryFlag: _stringOrNull(json['country_flag']),
      audioUrl: _stringOrNull(json['audio_url']),
      audioDurationSeconds:
          int.tryParse('${json['audio_duration_seconds'] ?? ''}'),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      approvedAt: DateTime.tryParse('${json['approved_at'] ?? ''}'),
    );
  }
}

String? _stringOrNull(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  return ['1', 'true', 'yes', 'on'].contains('${value ?? ''}'.toLowerCase());
}
