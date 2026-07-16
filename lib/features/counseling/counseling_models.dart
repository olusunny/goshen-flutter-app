class CounselingCasePage {
  CounselingCasePage({
    required this.cases,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<CounselingCase> cases;
  final int currentPage;
  final int lastPage;
  final int total;

  factory CounselingCasePage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CounselingCase.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final meta = Map<String, dynamic>.from(json['meta'] as Map? ?? {});
    return CounselingCasePage(
      cases: items,
      currentPage: _int(meta['current_page'], fallback: 1),
      lastPage: _int(meta['last_page'], fallback: 1),
      total: _int(meta['total'], fallback: items.length),
    );
  }
}

class CounselingCase {
  CounselingCase({
    required this.id,
    required this.reference,
    required this.status,
    required this.priority,
    this.category,
    this.subject,
    this.countryCode,
    this.locale,
    this.timezone,
    this.requester,
    this.assignedProvider,
    this.lastMessageAt,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
    this.messages = const [],
  });

  final int id;
  final String reference;
  final String status;
  final String priority;
  final String? category;
  final String? subject;
  final String? countryCode;
  final String? locale;
  final String? timezone;
  final CounselingPerson? requester;
  final CounselingProviderSummary? assignedProvider;
  final DateTime? lastMessageAt;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<CounselingMessage> messages;

  bool get isClosed => status.toLowerCase() == 'closed' || closedAt != null;

  String get displaySubject {
    final value = subject?.trim() ?? '';
    if (value.isNotEmpty) return value;
    final type = category?.trim() ?? '';
    return type.isNotEmpty ? type : 'Private counseling request';
  }

  factory CounselingCase.fromJson(Map<String, dynamic> json) {
    final provider = json['assigned_provider'];
    final messages = (json['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((item) =>
            CounselingMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return CounselingCase(
      id: _int(json['id']),
      reference: '${json['reference'] ?? ''}',
      status: '${json['status'] ?? 'submitted'}',
      priority: '${json['priority'] ?? 'normal'}',
      category: _stringOrNull(json['category']),
      subject: _stringOrNull(json['subject']),
      countryCode: _stringOrNull(json['country_code']),
      locale: _stringOrNull(json['locale']),
      timezone: _stringOrNull(json['timezone']),
      requester: json['requester'] is Map
          ? CounselingPerson.fromJson(
              Map<String, dynamic>.from(json['requester']))
          : null,
      assignedProvider: provider is Map
          ? CounselingProviderSummary.fromJson(
              Map<String, dynamic>.from(provider),
            )
          : null,
      lastMessageAt: _date(json['last_message_at']),
      closedAt: _date(json['closed_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      messages: messages,
    );
  }
}

class CounselingProviderSummary {
  CounselingProviderSummary({
    required this.id,
    required this.displayName,
    required this.role,
  });

  final int id;
  final String displayName;
  final String role;

  factory CounselingProviderSummary.fromJson(Map<String, dynamic> json) {
    return CounselingProviderSummary(
      id: _int(json['id']),
      displayName: '${json['display_name'] ?? 'Counselor'}',
      role: '${json['role'] ?? ''}',
    );
  }
}

class CounselingPerson {
  CounselingPerson({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatar,
    this.type,
  });

  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatar;
  final String? type;

  factory CounselingPerson.fromJson(Map<String, dynamic> json) {
    return CounselingPerson(
      id: _int(json['id']),
      name: _stringOrNull(json['name']) ?? 'Member',
      email: _stringOrNull(json['email']),
      phone: _stringOrNull(json['phone']),
      avatar: _stringOrNull(json['avatar']),
      type: _stringOrNull(json['type']),
    );
  }
}

class CounselingAttachment {
  CounselingAttachment({
    this.url,
    this.mime,
    this.name,
    this.sizeBytes,
  });

  final String? url;
  final String? mime;
  final String? name;
  final int? sizeBytes;

  factory CounselingAttachment.fromJson(Map<String, dynamic> json) {
    return CounselingAttachment(
      url: _stringOrNull(json['url']),
      mime: _stringOrNull(json['mime']),
      name: _stringOrNull(json['name']),
      sizeBytes: json['size_bytes'] == null ? null : _int(json['size_bytes']),
    );
  }
}

class CounselingReaction {
  CounselingReaction({required this.emoji, required this.count});

  final String emoji;
  final int count;
}

class CounselingMessage {
  CounselingMessage({
    required this.id,
    required this.direction,
    required this.messageType,
    this.body,
    this.sender,
    this.mediaUrl,
    this.audioUrl,
    this.audioDurationSeconds,
    this.attachment,
    this.reactions = const [],
    this.createdAt,
  });

  final int id;
  final String direction;
  final String messageType;
  final String? body;
  final CounselingPerson? sender;
  final String? mediaUrl;
  final String? audioUrl;
  final int? audioDurationSeconds;
  final CounselingAttachment? attachment;
  final List<CounselingReaction> reactions;
  final DateTime? createdAt;

  bool get isAudio => messageType.toLowerCase() == 'audio';
  bool get isImage => messageType.toLowerCase() == 'image';
  bool get isFile => messageType.toLowerCase() == 'file';
  bool get isFromRequester => direction.toLowerCase() == 'inbound';

  factory CounselingMessage.fromJson(Map<String, dynamic> json) {
    final reactions = <CounselingReaction>[];
    final rawReactions = json['reactions'];
    if (rawReactions is List) {
      for (final item in rawReactions.whereType<Map>()) {
        reactions.add(CounselingReaction(
          emoji: _stringOrNull(item['emoji']) ?? '',
          count: _int(item['count']),
        ));
      }
    } else if (rawReactions is Map) {
      final counts = <String, int>{};
      rawReactions.forEach((key, value) {
        final emoji = value is Map
            ? _stringOrNull(value['reaction'])
            : _stringOrNull(value);
        if (emoji == null || emoji.isEmpty) return;
        counts[emoji] = (counts[emoji] ?? 0) + 1;
      });
      counts.forEach((emoji, count) {
        reactions.add(CounselingReaction(emoji: emoji, count: count));
      });
    }

    return CounselingMessage(
      id: _int(json['id']),
      direction: '${json['direction'] ?? 'inbound'}',
      messageType: '${json['message_type'] ?? 'text'}',
      body: _stringOrNull(json['body']),
      sender: json['sender'] is Map
          ? CounselingPerson.fromJson(Map<String, dynamic>.from(json['sender']))
          : null,
      mediaUrl: _stringOrNull(json['media_url']),
      audioUrl: _stringOrNull(json['audio_url']),
      audioDurationSeconds: json['audio_duration_seconds'] == null
          ? null
          : _int(json['audio_duration_seconds']),
      attachment: json['attachment'] is Map
          ? CounselingAttachment.fromJson(
              Map<String, dynamic>.from(json['attachment']),
            )
          : null,
      reactions:
          reactions.where((reaction) => reaction.emoji.isNotEmpty).toList(),
      createdAt: _date(json['created_at']),
    );
  }
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? fallback;
}

DateTime? _date(dynamic value) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? null : DateTime.tryParse(text);
}

String? _stringOrNull(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return text;
}
