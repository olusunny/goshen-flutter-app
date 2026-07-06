import '../utils/Utility.dart';

class PrayerPoint {
  final int id;
  final String title;
  final String author;
  final String content;
  final String thumbnailUrl;
  final bool isPublished;
  final bool showOnPrayerWall;
  final int date;
  final String? rawDate;
  final String? createdAt;
  final String? updatedAt;

  const PrayerPoint({
    required this.id,
    required this.title,
    required this.author,
    required this.content,
    required this.thumbnailUrl,
    required this.isPublished,
    required this.showOnPrayerWall,
    required this.date,
    this.rawDate,
    this.createdAt,
    this.updatedAt,
  });

  factory PrayerPoint.fromJson(Map<String, dynamic> json) {
    final content = _decodeMaybe(_readString(
        json, const ['content', 'body', 'prayer', 'description', 'text']));
    return PrayerPoint(
      id: _readInt(json, const ['id', 'prayer_point_id']),
      title: _readString(json, const ['title', 'subject']).isEmpty
          ? _titleFromContent(content)
          : _readString(json, const ['title', 'subject']),
      author: _readString(json, const ['author', 'name']),
      content: content,
      thumbnailUrl:
          _readString(json, const ['thumbnail_url', 'thumbnail', 'image_url']),
      isPublished: _readBool(json, const ['is_published', 'published']) ||
          json['is_published'] == null && json['published'] == null,
      showOnPrayerWall:
          _readBool(json, const ['show_on_prayer_wall', 'showOnPrayerWall']) ||
              json['show_on_prayer_wall'] == null &&
                  json['showOnPrayerWall'] == null,
      date:
          _readDate(json, const ['date', 'created_at_timestamp', 'created_at']),
      rawDate: _readNullableString(json, const ['date']),
      createdAt: _readNullableString(json, const ['created_at']),
      updatedAt: _readNullableString(json, const ['updated_at']),
    );
  }

  bool get hasThumbnail => thumbnailUrl.trim().isNotEmpty;
}

class PrayerRequest {
  final int id;
  final String title;
  final String content;
  final String? audioUrl;
  final String name;
  final String email;
  final String avatar;
  final bool anonymous;
  final int commentsCount;
  final int date;
  final int ownerId;
  final bool canComment;

  PrayerRequest({
    required this.id,
    required this.title,
    required this.content,
    required this.audioUrl,
    required this.name,
    required this.email,
    required this.avatar,
    required this.anonymous,
    required this.commentsCount,
    required this.date,
    required this.ownerId,
    required this.canComment,
  });

  factory PrayerRequest.fromJson(Map<String, dynamic> json) {
    final content =
        _readString(json, ['text', 'content', 'body', 'prayer', 'request']);
    return PrayerRequest(
      id: _readInt(json, ['id', 'prayer_id']),
      title: _readString(json, ['title', 'subject']).isEmpty
          ? _titleFromContent(content)
          : _readString(json, ['title', 'subject']),
      content: _decodeMaybe(content),
      audioUrl: _readNullableString(
          json, ['audio_url', 'audio', 'voice_url', 'attachment']),
      name: _readString(json, ['identity', 'name', 'fullname', 'user_name']),
      email: _readString(json, ['email', 'user_email']),
      avatar: _readString(json, ['avatar', 'photo', 'profile_photo']),
      anonymous: _readBool(json, ['anonymous', 'is_anonymous']) ||
          _readString(json, ['identity']) == 'Anonymous',
      commentsCount:
          _readInt(json, ['comments_count', 'comment_count', 'commentsCount']),
      date: _readInt(json, ['date', 'created_at_timestamp', 'timestamp']),
      ownerId: _readInt(json, ['owner_id', 'mobile_user_id', 'user_id']),
      canComment:
          json['can_comment'] == null ? true : _readBool(json, ['can_comment']),
    );
  }

  String get displayName => anonymous || name.isEmpty ? 'Anonymous' : name;
  String get displayAvatar => anonymous ? '' : avatar;
}

class PrayerSubmissionStatus {
  final bool canSubmit;
  final int cooldownSeconds;
  final String? nextAvailableAt;
  final String? message;

  const PrayerSubmissionStatus({
    required this.canSubmit,
    required this.cooldownSeconds,
    this.nextAvailableAt,
    this.message,
  });

  factory PrayerSubmissionStatus.fromJson(Map<String, dynamic> json) {
    return PrayerSubmissionStatus(
      canSubmit: _readBool(json, ['can_submit_prayer', 'can_submit']) ||
          json['can_submit_prayer'] == null && json['can_submit'] == null,
      cooldownSeconds:
          _readInt(json, ['cooldown_seconds', 'countdown_seconds']),
      nextAvailableAt:
          _readNullableString(json, ['next_available_at', 'next_allowed_at']),
      message: _readNullableString(json, ['message', 'msg']),
    );
  }
}

class PrayerFeed {
  final List<PrayerRequest> requests;
  final PrayerSubmissionStatus submissionStatus;

  const PrayerFeed({
    required this.requests,
    required this.submissionStatus,
  });
}

class PrayerComment {
  final int id;
  final String content;
  final String? audioUrl;
  final String name;
  final String avatar;
  final bool anonymous;
  final int date;

  PrayerComment({
    required this.id,
    required this.content,
    this.audioUrl,
    required this.name,
    required this.avatar,
    required this.anonymous,
    required this.date,
  });

  factory PrayerComment.fromJson(Map<String, dynamic> json) {
    return PrayerComment(
      id: _readInt(json, ['id', 'comment_id']),
      content: _decodeMaybe(
          _readString(json, ['text', 'content', 'body', 'comment'])),
      audioUrl: _readNullableString(
          json, ['audio_url', 'audio', 'voice_url', 'attachment']),
      name: _readString(json, ['identity', 'name', 'fullname', 'user_name']),
      avatar: _readString(json, ['avatar', 'photo', 'profile_photo']),
      anonymous: _readBool(json, ['anonymous', 'is_anonymous']) ||
          _readString(json, ['identity']) == 'Anonymous',
      date: _readInt(json, ['date', 'created_at_timestamp', 'timestamp']),
    );
  }

  String get displayName => anonymous || name.isEmpty ? 'Anonymous' : name;
  String get displayAvatar => anonymous ? '' : avatar;
}

class PropheticDecree {
  final int id;
  final String label;
  final String audioUrl;
  final String goName;
  final String goAvatar;
  final int date;
  final bool active;

  PropheticDecree({
    required this.id,
    required this.label,
    required this.audioUrl,
    required this.goName,
    required this.goAvatar,
    required this.date,
    required this.active,
  });

  factory PropheticDecree.fromJson(Map<String, dynamic> json) {
    final go = json['go'] is Map
        ? Map<String, dynamic>.from(json['go'] as Map)
        : <String, dynamic>{};
    return PropheticDecree(
      id: _readInt(json, ['id', 'decree_id']),
      label: _readString(json, ['label', 'title', 'name']).isEmpty
          ? 'Daily Prophet Decree'
          : _readString(json, ['label', 'title', 'name']),
      audioUrl:
          _readString(json, ['audio_url', 'audio', 'voice_url', 'attachment']),
      goName: _readString(go, ['name', 'fullname', 'user_name']).isNotEmpty
          ? _readString(go, ['name', 'fullname', 'user_name'])
          : _readString(json, [
              'go_name',
              'g_o_name',
              'general_overseer_name',
              'name',
              'fullname',
              'user_name'
            ]),
      goAvatar: _readString(go, ['profile_image', 'avatar', 'photo']).isNotEmpty
          ? _readString(go, ['profile_image', 'avatar', 'photo'])
          : _readString(json, [
              'go_avatar',
              'g_o_avatar',
              'general_overseer_avatar',
              'avatar',
              'photo',
              'profile_photo'
            ]),
      date: _readDate(
          json, ['date', 'created_at_timestamp', 'timestamp', 'created_at']),
      active: !_readBool(json, ['inactive', 'archived']) &&
          (_readBool(json, ['active', 'is_active']) ||
              json['active'] == null && json['is_active'] == null),
    );
  }

  bool get hasAudio => audioUrl.isNotEmpty;
  String get displayName => goName.isEmpty ? 'G.O' : goName;
}

int _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    return int.tryParse(value.toString()) ?? 0;
  }
  return 0;
}

String _readString(Map<String, dynamic> json, List<String> keys) {
  return _readNullableString(json, keys) ?? '';
}

String? _readNullableString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return null;
}

bool _readBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    return value == true ||
        value.toString() == '1' ||
        value.toString() == 'true';
  }
  return false;
}

int _readDate(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final parsedInt = int.tryParse(value.toString());
    if (parsedInt != null) {
      return parsedInt > 9999999999 ? (parsedInt / 1000).round() : parsedInt;
    }
    final parsedDate = DateTime.tryParse(value.toString());
    if (parsedDate != null) {
      return (parsedDate.millisecondsSinceEpoch / 1000).round();
    }
  }
  return 0;
}

String _decodeMaybe(String text) {
  if (text.isEmpty) return text;
  try {
    return Utility.getBase64DecodedString(text);
  } catch (_) {
    return text;
  }
}

String _titleFromContent(String content) {
  final plain = _decodeMaybe(content).replaceAll('\n', ' ').trim();
  if (plain.length <= 42) return plain.isEmpty ? 'Prayer Request' : plain;
  return plain.substring(0, 42).trim() + '...';
}
