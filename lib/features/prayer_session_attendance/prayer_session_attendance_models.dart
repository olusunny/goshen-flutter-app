class PrayerAttendanceCapability {
  const PrayerAttendanceCapability({
    required this.active,
    this.permissions = const [],
    this.eligibleActiveSessionCount = 0,
    this.eligibilityVerified = false,
  });

  final bool active;
  final List<String> permissions;
  final int eligibleActiveSessionCount;
  final bool eligibilityVerified;

  bool allows(String permission) => permissions.contains(permission);
  bool get canCoordinate =>
      allows('prayer_session_attendance.coordinate') ||
      allows('prayer_session_attendance.admin');
  bool get canConfirm =>
      canCoordinate || allows('prayer_session_attendance.confirm');
  bool get canReport =>
      canCoordinate || allows('prayer_session_attendance.report');
  bool get canOpenControlHub => active && (canConfirm || canReport);
  bool get canUseStaffAttendanceTools => canConfirm;
  bool get canAttend =>
      active && eligibilityVerified && eligibleActiveSessionCount > 0;

  PrayerAttendanceCapability withAttendeeEligibility(int eligibleCount) =>
      PrayerAttendanceCapability(
        active: active,
        permissions: permissions,
        eligibleActiveSessionCount: eligibleCount,
        eligibilityVerified: true,
      );
}

class PrayerSessionTicket {
  const PrayerSessionTicket({
    required this.id,
    required this.ticketNumber,
    required this.attendeeName,
  });

  final String id;
  final String ticketNumber;
  final String attendeeName;

  factory PrayerSessionTicket.fromJson(Map<String, dynamic> json) =>
      PrayerSessionTicket(
        id: '${json['id'] ?? ''}',
        ticketNumber: '${json['ticket_number'] ?? ''}',
        attendeeName: '${json['attendee_name'] ?? ''}',
      );
}

class PrayerSessionSummary {
  const PrayerSessionSummary({
    required this.id,
    required this.name,
    required this.status,
    this.description,
    this.metrics = const {},
    this.eligibleTickets = const [],
  });

  final String id;
  final String name;
  final String status;
  final String? description;
  final Map<String, dynamic> metrics;
  final List<PrayerSessionTicket> eligibleTickets;

  bool get isEligibleForAttendee => eligibleTickets.isNotEmpty;

  factory PrayerSessionSummary.fromJson(Map<String, dynamic> json) =>
      PrayerSessionSummary(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? 'Prayer session'}',
        status: '${json['status'] ?? 'scheduled'}',
        description: json['description']?.toString(),
        metrics: Map<String, dynamic>.from(json['metrics'] as Map? ?? const {}),
        eligibleTickets: ((json['eligible_tickets'] as List?) ?? const [])
            .whereType<Map>()
            .map((ticket) =>
                PrayerSessionTicket.fromJson(Map<String, dynamic>.from(ticket)))
            .toList(),
      );
}

class PrayerAttendanceResult {
  const PrayerAttendanceResult({
    required this.sessionName,
    required this.confirmedAt,
    required this.alreadyConfirmed,
  });

  final String sessionName;
  final DateTime? confirmedAt;
  final bool alreadyConfirmed;

  factory PrayerAttendanceResult.fromJson(
    Map<String, dynamic> json, {
    String? sessionName,
  }) {
    final confirmation =
        Map<String, dynamic>.from(json['confirmation'] as Map? ?? const {});
    return PrayerAttendanceResult(
      sessionName: sessionName ??
          '${json['session_name'] ?? json['session'] ?? 'the prayer session'}',
      confirmedAt:
          DateTime.tryParse('${confirmation['confirmed_at'] ?? ''}')?.toLocal(),
      alreadyConfirmed: confirmation['already_confirmed'] == true,
    );
  }
}

class PrayerSessionStaffTicket {
  const PrayerSessionStaffTicket({
    required this.id,
    required this.ticketNumber,
    required this.attendeeName,
  });

  final String id;
  final String ticketNumber;
  final String attendeeName;

  factory PrayerSessionStaffTicket.fromJson(Map<String, dynamic> json) =>
      PrayerSessionStaffTicket(
        id: '${json['id'] ?? ''}',
        ticketNumber: '${json['ticket_number'] ?? ''}',
        attendeeName: '${json['attendee_name'] ?? ''}',
      );
}

class PrayerSessionReport {
  const PrayerSessionReport({
    required this.metrics,
    required this.rows,
  });

  final Map<String, dynamic> metrics;
  final List<Map<String, dynamic>> rows;

  List<Map<String, dynamic>> get confirmed =>
      rows.where((row) => row['status'] == 'Confirmed').toList();

  factory PrayerSessionReport.fromJson(Map<String, dynamic> json) =>
      PrayerSessionReport(
        metrics: Map<String, dynamic>.from(json['metrics'] as Map? ?? const {}),
        rows: ((json['rows'] as List?) ??
                (json['confirmed'] as List?) ??
                const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
      );
}

class PrayerAttendanceOfflineRecord {
  const PrayerAttendanceOfflineRecord({
    required this.id,
    required this.sessionId,
    required this.ticketCode,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String ticketCode;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'ticket_code': ticketCode,
        'created_at': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toSyncJson() => {
        'idempotency_key': id,
        'session_id': sessionId,
        'ticket_identifier': ticketCode,
        'created_at': createdAt.toIso8601String(),
      };

  factory PrayerAttendanceOfflineRecord.fromJson(Map<String, dynamic> json) =>
      PrayerAttendanceOfflineRecord(
        id: '${json['id'] ?? ''}',
        sessionId: '${json['session_id'] ?? ''}',
        ticketCode: '${json['ticket_code'] ?? ''}',
        createdAt:
            DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
      );
}
