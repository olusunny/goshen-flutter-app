class Events {
  final int? id;
  final String? title, thumbnail, portraitImage;
  final String? details, time, date, venue, startsAt, endsAt;
  final String? theme, bibleVerse, host, otherMinisters;
  final String? registrationUrl, registrationAvailability, registrationLabel;
  final bool isPilgrimage;
  final List<EventScheduleDay> eventSchedule;
  final List<EventStreamingPlatform> liveStreamingPlatforms;
  final List<EventGospelMusician> invitedGospelMusicians;
  final PilgrimageDetails pilgrimageDetails;

  Events(
      {this.id,
      this.title,
      this.thumbnail,
      this.portraitImage,
      this.details,
      this.time,
      this.date,
      this.venue,
      this.startsAt,
      this.endsAt,
      this.theme,
      this.bibleVerse,
      this.host,
      this.otherMinisters,
      this.registrationUrl,
      this.registrationAvailability,
      this.registrationLabel,
      this.isPilgrimage = false,
      this.eventSchedule = const [],
      this.liveStreamingPlatforms = const [],
      this.invitedGospelMusicians = const [],
      this.pilgrimageDetails = const PilgrimageDetails()});

  factory Events.fromJson(Map<String, dynamic> json) {
    //print(json);
    int id = int.tryParse((json['id'] ?? '0').toString()) ?? 0;
    final startsAt = (json['starts_at'] ?? '').toString();
    final date = json['date'] as String? ??
        (startsAt.length >= 10 ? startsAt.substring(0, 10) : null);
    return Events(
        id: id,
        title: json['title'] as String? ?? '',
        thumbnail: json['thumbnail'] as String? ?? '',
        portraitImage: json['portrait_image'] as String? ?? '',
        details: json['details'] as String? ?? '',
        time: json['time'] as String? ?? '',
        date: date ?? '',
        venue: json['venue'] as String? ?? '',
        startsAt: startsAt,
        endsAt: json['ends_at'] as String? ?? '',
        theme: json['theme'] as String? ?? '',
        bibleVerse: json['bible_verse'] as String? ?? '',
        host: json['host'] as String? ?? '',
        otherMinisters: json['other_ministers'] as String? ?? '',
        registrationUrl: json['registration_url'] as String? ?? '',
        registrationAvailability:
            json['registration_availability'] as String? ?? 'everywhere',
        registrationLabel:
            json['registration_label'] as String? ?? 'Available everywhere',
        isPilgrimage: _parseBool(json['is_pilgrimage']),
        eventSchedule: _parseSchedule(json['event_schedule']),
        liveStreamingPlatforms: _parseStreamingPlatforms(
          json['live_streaming_platforms'],
        ),
        invitedGospelMusicians: _parseMusicians(
          json['invited_gospel_musicians'],
        ),
        pilgrimageDetails: PilgrimageDetails.fromJson(
          _asMap(json['pilgrimage_details']),
        ));
  }

  String get fullScreenImage {
    final portrait = (portraitImage ?? '').trim();
    if (portrait.isNotEmpty) return portrait;
    return (thumbnail ?? '').trim();
  }

  DateTime? get startDateTime =>
      _parseDateTimeFromDateAndTime(date, time) ??
      _parseDateTime(startsAt) ??
      _parseDateTime(date);

  DateTime? get endDateTime {
    final timeRangeEnd = _parseDateTimeFromDateAndTime(
      date,
      time,
      end: true,
    );
    if (timeRangeEnd != null) return timeRangeEnd;

    final parsedEnd = _parseDateTime(endsAt, endOfDayForDateOnly: true);
    if (parsedEnd != null) return parsedEnd;
    final parsedStart = _parseDateTime(startsAt, endOfDayForDateOnly: true);
    if (parsedStart != null) return parsedStart;
    return _parseDateTime(date, endOfDayForDateOnly: true);
  }

  bool get isPast {
    final end = endDateTime;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  bool get hasPilgrimageDetails => isPilgrimage && pilgrimageDetails.hasContent;

  static DateTime? _parseDateTime(
    String? value, {
    bool endOfDayForDateOnly = false,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    if (endOfDayForDateOnly && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59);
    }
    return parsed;
  }

  static DateTime? _parseDateTimeFromDateAndTime(
    String? dateValue,
    String? timeValue, {
    bool end = false,
  }) {
    final base = _parseDateTime(dateValue);
    if (base == null) return null;

    final text = (timeValue ?? '').trim();
    if (text.isEmpty) {
      return end
          ? DateTime(base.year, base.month, base.day, 23, 59, 59)
          : DateTime(base.year, base.month, base.day);
    }

    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'\b12\s*noon\b'), '12:00 pm')
        .replaceAll(RegExp(r'\bnoon\b'), '12:00 pm')
        .replaceAll(RegExp(r'\bmidnight\b'), '12:00 am');
    final matches = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b')
        .allMatches(normalized)
        .toList();
    if (matches.isEmpty) {
      return end
          ? DateTime(base.year, base.month, base.day, 23, 59, 59)
          : DateTime(base.year, base.month, base.day);
    }

    DateTime fromMatch(RegExpMatch match) {
      var hour = int.tryParse(match.group(1) ?? '0') ?? 0;
      final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
      final meridiem = match.group(3) ?? 'am';
      if (meridiem == 'pm' && hour < 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;
      return DateTime(base.year, base.month, base.day, hour, minute);
    }

    final first = fromMatch(matches.first);
    if (!end) return first;

    var last = fromMatch(matches.last);
    if (!last.isAfter(first) && matches.length > 1) {
      last = last.add(const Duration(days: 1));
    }
    return last;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim() ?? '';
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<EventScheduleDay> _parseSchedule(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => EventScheduleDay.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.hasContent)
        .toList();
  }

  static List<EventStreamingPlatform> _parseStreamingPlatforms(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => EventStreamingPlatform.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.platform.isNotEmpty || item.url.isNotEmpty)
        .toList();
  }

  static List<EventGospelMusician> _parseMusicians(dynamic value) {
    if (value is! List) return [];
    return value
        .map((item) {
          if (item is Map) {
            return EventGospelMusician.fromJson(
              Map<String, dynamic>.from(item),
            );
          }
          return EventGospelMusician(
            name: item.toString().trim(),
            imageUrl: '',
          );
        })
        .where((item) => item.hasContent)
        .toList();
  }
}

class EventGospelMusician {
  const EventGospelMusician({
    required this.name,
    required this.imageUrl,
  });

  final String name;
  final String imageUrl;

  bool get hasContent => name.isNotEmpty || imageUrl.isNotEmpty;
  bool get hasImage => imageUrl.isNotEmpty;

  factory EventGospelMusician.fromJson(Map<String, dynamic> json) {
    return EventGospelMusician(
      name: (json['name'] ?? '').toString().trim(),
      imageUrl: (json['image_url'] ?? json['image'] ?? '').toString().trim(),
    );
  }
}

class EventScheduleDay {
  const EventScheduleDay({
    required this.dayLabel,
    required this.dateLabel,
    required this.sessions,
  });

  final String dayLabel;
  final String dateLabel;
  final List<EventScheduleSession> sessions;

  bool get hasContent =>
      dayLabel.isNotEmpty || dateLabel.isNotEmpty || sessions.isNotEmpty;

  factory EventScheduleDay.fromJson(Map<String, dynamic> json) {
    final sessions = json['sessions'] is List
        ? (json['sessions'] as List)
            .whereType<Map>()
            .map((item) => EventScheduleSession.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .where((item) => item.hasContent)
            .toList()
        : <EventScheduleSession>[];

    return EventScheduleDay(
      dayLabel: (json['day_label'] ?? '').toString().trim(),
      dateLabel: (json['date_label'] ?? '').toString().trim(),
      sessions: sessions,
    );
  }
}

class EventScheduleSession {
  const EventScheduleSession({
    required this.title,
    required this.time,
  });

  final String title;
  final String time;

  bool get hasContent => title.isNotEmpty || time.isNotEmpty;

  factory EventScheduleSession.fromJson(Map<String, dynamic> json) {
    return EventScheduleSession(
      title: (json['title'] ?? '').toString().trim(),
      time: (json['time'] ?? '').toString().trim(),
    );
  }
}

class EventStreamingPlatform {
  const EventStreamingPlatform({
    required this.platform,
    required this.url,
  });

  final String platform;
  final String url;

  factory EventStreamingPlatform.fromJson(Map<String, dynamic> json) {
    return EventStreamingPlatform(
      platform: (json['platform'] ?? '').toString().trim(),
      url: (json['url'] ?? '').toString().trim(),
    );
  }
}

class PilgrimageDetails {
  const PilgrimageDetails({
    this.organizer = '',
    this.packagedBy = '',
    this.theme = '',
    this.countryVenue = '',
    this.dateText = '',
    this.ministering = '',
    this.participationFees = const [],
    this.paymentDetails = const [],
    this.registrationContacts = const [],
  });

  final String organizer;
  final String packagedBy;
  final String theme;
  final String countryVenue;
  final String dateText;
  final String ministering;
  final List<PilgrimageFee> participationFees;
  final List<PilgrimagePaymentSection> paymentDetails;
  final List<PilgrimageContact> registrationContacts;

  bool get hasContent =>
      organizer.isNotEmpty ||
      packagedBy.isNotEmpty ||
      theme.isNotEmpty ||
      countryVenue.isNotEmpty ||
      dateText.isNotEmpty ||
      ministering.isNotEmpty ||
      participationFees.isNotEmpty ||
      paymentDetails.isNotEmpty ||
      registrationContacts.isNotEmpty;

  factory PilgrimageDetails.fromJson(Map<String, dynamic> json) {
    return PilgrimageDetails(
      organizer: (json['organizer'] ?? '').toString().trim(),
      packagedBy: (json['packaged_by'] ?? '').toString().trim(),
      theme: (json['theme'] ?? '').toString().trim(),
      countryVenue: (json['country_venue'] ?? '').toString().trim(),
      dateText: (json['date_text'] ?? '').toString().trim(),
      ministering: (json['ministering'] ?? '').toString().trim(),
      participationFees: _parseList(
        json['participation_fees'],
        PilgrimageFee.fromJson,
      ),
      paymentDetails: _parseList(
        json['payment_details'],
        PilgrimagePaymentSection.fromJson,
      ),
      registrationContacts: _parseList(
        json['registration_contacts'],
        PilgrimageContact.fromJson,
      ),
    );
  }

  static List<T> _parseList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) builder,
  ) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => builder(Map<String, dynamic>.from(item)))
        .toList();
  }
}

class PilgrimageFee {
  const PilgrimageFee({
    required this.label,
    required this.amount,
    required this.note,
  });

  final String label;
  final String amount;
  final String note;

  bool get hasContent =>
      label.isNotEmpty || amount.isNotEmpty || note.isNotEmpty;

  factory PilgrimageFee.fromJson(Map<String, dynamic> json) {
    return PilgrimageFee(
      label: (json['label'] ?? '').toString().trim(),
      amount: (json['amount'] ?? '').toString().trim(),
      note: (json['note'] ?? '').toString().trim(),
    );
  }
}

class PilgrimagePaymentSection {
  const PilgrimagePaymentSection({
    required this.title,
    required this.details,
  });

  final String title;
  final String details;

  bool get hasContent => title.isNotEmpty || details.isNotEmpty;

  factory PilgrimagePaymentSection.fromJson(Map<String, dynamic> json) {
    return PilgrimagePaymentSection(
      title: (json['title'] ?? '').toString().trim(),
      details: (json['details'] ?? '').toString().trim(),
    );
  }
}

class PilgrimageContact {
  const PilgrimageContact({
    required this.name,
    required this.phone,
  });

  final String name;
  final String phone;

  bool get hasContent => name.isNotEmpty || phone.isNotEmpty;

  factory PilgrimageContact.fromJson(Map<String, dynamic> json) {
    return PilgrimageContact(
      name: (json['name'] ?? '').toString().trim(),
      phone: (json['phone'] ?? '').toString().trim(),
    );
  }
}
