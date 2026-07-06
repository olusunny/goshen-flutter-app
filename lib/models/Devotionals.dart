class Devotionals {
  final int? id;
  final String? title, thumbnail, date, excerpt;
  final String? author, content, biblereading, confession, studies;
  final bool isPublished;

  Devotionals(
      {this.id,
      this.title,
      this.thumbnail,
      this.date,
      this.excerpt,
      this.author,
      this.content,
      this.biblereading,
      this.confession,
      this.studies,
      this.isPublished = true});

  factory Devotionals.fromJson(Map<String, dynamic> json) {
    return Devotionals(
      id: _readInt(json['id']),
      title: _readText(json['title']),
      thumbnail: _readText(json['thumbnail_url']).isNotEmpty
          ? _readText(json['thumbnail_url'])
          : _readText(json['thumbnail']),
      date: _readText(json['date']),
      excerpt: _readText(json['excerpt']),
      author: _readText(json['author']),
      content: _readText(json['content']),
      biblereading: _readText(json['bible_reading']),
      confession: _readText(json['confession']),
      studies: _readText(json['studies']),
      isPublished: _readBool(json['is_published']),
    );
  }
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse('${value ?? ''}');
}

String _readText(dynamic value) => value?.toString() ?? '';

bool _readBool(dynamic value) {
  if (value == null) return true;
  if (value is bool) return value;
  final text = value.toString().toLowerCase().trim();
  return text == '1' || text == 'true' || text == 'yes' || text == 'on';
}
