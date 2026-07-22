class PrayerSessionAttendanceLink {
  const PrayerSessionAttendanceLink({this.sessionId});

  final String? sessionId;
}

PrayerSessionAttendanceLink? parsePrayerSessionAttendanceLink(Uri uri) {
  final isAttendancePath =
      uri.pathSegments.contains('prayer-session-attendance') ||
          uri.pathSegments.contains('prayer-attendance');
  final isAttendanceHost = uri.host == 'prayer-session-attendance' ||
      uri.host == 'prayer-attendance';
  if (!isAttendancePath && !isAttendanceHost) return null;
  final sessionId = uri.queryParameters['session_id']?.trim();
  return PrayerSessionAttendanceLink(
    sessionId: sessionId == null || sessionId.isEmpty ? null : sessionId,
  );
}

bool isPrayerSessionAttendanceNotification(Map<String, dynamic> data) {
  final action = '${data['action'] ?? data['type'] ?? ''}'.trim();
  return action == 'prayer_session_attendance' ||
      action == 'prayer-attendance' ||
      action == 'prayer_attendance';
}
