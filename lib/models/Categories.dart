class Categories {
  final int? id;
  final String? title;
  final String? thumbnailUrl;
  final int? mediaCount;

  static const String TABLE = "categories";
  static final columns = ["id", "title", "thumbnailUrl", "mediaCount"];

  Categories({this.id, this.title, this.thumbnailUrl, this.mediaCount});

  factory Categories.fromJson(Map<String, dynamic> json) {
    return Categories(
      id: _readInt(json['id']),
      title: _readText(json['name']),
      thumbnailUrl: _readText(json['thumbnail']),
      mediaCount: _readInt(json['media_count']) ?? 0,
    );
  }

  factory Categories.fromJson2(Map<String, dynamic> json) {
    return Categories(
      id: _readInt(json['id']),
      title: _readText(json['name']),
      thumbnailUrl: "",
      mediaCount: 0,
    );
  }

  factory Categories.fromMap(Map<String, dynamic> data) {
    return Categories(
        id: _readInt(data['id']),
        title: _readText(data['title']),
        thumbnailUrl: _readText(data['thumbnailUrl']),
        mediaCount: _readInt(data['mediaCount']));
  }

  Map<String, dynamic> toMap() => {
        "id": id,
        "title": title,
        "thumbnailUrl": thumbnailUrl,
        "mediaCount": mediaCount
      };
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
