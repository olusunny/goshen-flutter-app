class VerseOfDayManagement {
  const VerseOfDayManagement({
    required this.id,
    required this.date,
    required this.reference,
    required this.version,
    required this.text,
    required this.reflection,
    required this.prayer,
    required this.isPublished,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String date;
  final String reference;
  final String version;
  final String text;
  final String reflection;
  final String prayer;
  final bool isPublished;
  final String? publishedAt;
  final String? createdAt;
  final String? updatedAt;

  factory VerseOfDayManagement.fromJson(Map<String, dynamic> json) {
    return VerseOfDayManagement(
      id: _readInt(json, const ['id', 'verse_id']),
      date: _readString(json, const ['date']),
      reference: _readString(json, const ['reference']),
      version: _readString(json, const ['version']).isEmpty
          ? 'KJV'
          : _readString(json, const ['version']),
      text: _readString(json, const ['text', 'verse']),
      reflection: _readString(json, const ['reflection']),
      prayer: _readString(json, const ['prayer']),
      isPublished: _readBool(json['is_published'] ?? json['published']),
      publishedAt: _readNullableString(json, const ['published_at']),
      createdAt: _readNullableString(json, const ['created_at']),
      updatedAt: _readNullableString(json, const ['updated_at']),
    );
  }

  String get statusLabel => isPublished ? 'Published' : 'Draft';
}

String _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

String? _readNullableString(Map<String, dynamic> json, List<String> keys) {
  final value = _readString(json, keys);
  return value.isEmpty ? null : value;
}

int _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

bool _readBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  final text = value.toString().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes';
}
