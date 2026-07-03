class Inbox {
  final int? id;
  final String? title, message, imageUrl, toneUrl, toneLabel;
  final bool toneEnabled;
  final int? date;

  Inbox({
    this.id,
    this.title,
    this.message,
    this.imageUrl,
    this.toneUrl,
    this.toneLabel,
    this.toneEnabled = false,
    this.date,
  });

  factory Inbox.fromJson(Map<String, dynamic> json) {
    return Inbox(
        id: _readInt(json['id']),
        title: _readText(json['title']),
        message: _firstText([
          json['message'],
          json['content'],
          json['body'],
          json['description'],
        ]),
        imageUrl:
            '${json['image_url'] ?? json['thumbnail'] ?? ''}'.trim().isEmpty
                ? null
                : '${json['image_url'] ?? json['thumbnail']}',
        toneUrl: '${json['tone_url'] ?? ''}'.trim().isEmpty
            ? null
            : '${json['tone_url']}',
        toneLabel: '${json['tone_label'] ?? ''}'.trim(),
        toneEnabled: _readBool(json['tone_enabled']),
        date: _readInt(json['date']));
  }
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return int.tryParse(text);
}

String? _readText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return text;
}

String? _firstText(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return null;
}

bool _readBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  final text = value.toString().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes';
}
