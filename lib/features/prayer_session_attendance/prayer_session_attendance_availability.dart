import '../../models/Userdata.dart';
import 'prayer_session_attendance_api.dart';
import 'prayer_session_attendance_models.dart';

class PrayerSessionAttendanceAvailability {
  PrayerSessionAttendanceAvailability({PrayerSessionAttendanceApi? api})
      : _api = api ?? PrayerSessionAttendanceApi();
  final PrayerSessionAttendanceApi _api;

  Future<PrayerAttendanceCapability> check(Userdata user,
      {bool force = false}) async {
    final capability = await _api.fetchCapability(user);
    if (!capability.active) {
      return capability;
    }

    PrayerAttendanceCapability next;
    try {
      final sessions = await _api.activeSessions(user);
      next = capability.withAttendeeEligibility(
          sessions.where((session) => session.isEligibleForAttendee).length);
    } catch (_) {
      // Server availability is authoritative. A failed eligibility check must
      // not turn a capability into an attendee entry point.
      next = capability;
    }
    return next;
  }
}
