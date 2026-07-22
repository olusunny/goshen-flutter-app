import 'package:churchapp_flutter/features/prayer_session_attendance/prayer_session_attendance_api.dart';
import 'package:churchapp_flutter/features/prayer_session_attendance/prayer_session_attendance_availability.dart';
import 'package:churchapp_flutter/features/prayer_session_attendance/prayer_session_attendance_models.dart';
import 'package:churchapp_flutter/features/prayer_session_attendance/prayer_session_attendance_link.dart';
import 'package:churchapp_flutter/models/Userdata.dart';
import 'package:churchapp_flutter/utils/ApiUrl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('members can discover an active attendance feature before eligibility',
      () {
    const unavailable = PrayerAttendanceCapability(
      active: true,
      permissions: ['prayer_session_attendance.view'],
    );
    expect(unavailable.canOpenMemberExperience, isTrue);
    expect(unavailable.canAttend, isFalse);

    expect(unavailable.withAttendeeEligibility(0).canAttend, isFalse);
    expect(unavailable.withAttendeeEligibility(1).canAttend, isTrue);
  });

  test('members cannot discover an inactive attendance feature', () {
    const inactive = PrayerAttendanceCapability(active: false);

    expect(inactive.canOpenMemberExperience, isFalse);
  });

  test('a signed-in member entry remains available while capability refreshes',
      () {
    expect(shouldShowPrayerSessionAttendanceMemberEntry(null), isFalse);
    expect(
      shouldShowPrayerSessionAttendanceMemberEntry(
          Userdata(apiToken: 'member-token')),
      isTrue,
    );
  });

  test('capability discovery accepts the legacy successful API envelope',
      () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: const {
          'data': {
            'capabilities': [
              {'key': 'prayer_session_attendance', 'permissions': []},
            ],
          },
        },
      ));
    }));

    final capability = await PrayerSessionAttendanceApi(dio: dio)
        .fetchCapability(Userdata(apiToken: 'member-token'));

    expect(capability.canOpenMemberExperience, isTrue);
  });

  test('report-only staff can open the control hub without attendance tools',
      () {
    const reportOnly = PrayerAttendanceCapability(
      active: true,
      permissions: ['prayer_session_attendance.report'],
    );

    expect(reportOnly.canOpenControlHub, isTrue);
    expect(reportOnly.canReport, isTrue);
    expect(reportOnly.canUseStaffAttendanceTools, isFalse);
    expect(reportOnly.canConfirm, isFalse);
    expect(reportOnly.canCoordinate, isFalse);
  });

  test('confirm-only staff cannot access reports or session controls', () {
    const confirmOnly = PrayerAttendanceCapability(
      active: true,
      permissions: ['prayer_session_attendance.confirm'],
    );

    expect(confirmOnly.canOpenControlHub, isTrue);
    expect(confirmOnly.canUseStaffAttendanceTools, isTrue);
    expect(confirmOnly.canReport, isFalse);
    expect(confirmOnly.canCoordinate, isFalse);
  });

  test('active-session payload preserves server eligible tickets', () {
    final session = PrayerSessionSummary.fromJson({
      'id': 'ps_123',
      'name': 'Morning prayer',
      'status': 'active',
      'eligible_tickets': [
        {
          'id': 'ticket_123',
          'ticket_number': 'GOS-001',
          'attendee_name': 'Great Greatest',
        },
      ],
    });

    expect(session.isEligibleForAttendee, isTrue);
    expect(session.eligibleTickets.single.id, 'ticket_123');
    expect(session.eligibleTickets.single.ticketNumber, 'GOS-001');
  });

  test('mobile API constants use the canonical package routes', () {
    expect(ApiUrl.PRAYER_SESSION_ATTENDANCE_ACTIVE_SESSIONS,
        endsWith('/sessions/active'));
    expect(ApiUrl.PRAYER_SESSION_ATTENDANCE_SELF_CONFIRMATIONS,
        endsWith('/confirmations/self'));
    expect(ApiUrl.prayerSessionAttendanceStaffConfirmation('ps_123'),
        endsWith('/sessions/ps_123/staff/confirmations'));
    expect(
        ApiUrl.PRAYER_SESSION_ATTENDANCE_STAFF_SYNC, endsWith('/staff/sync'));
    expect(ApiUrl.prayerSessionAttendanceStaffTicket('ps_123', 'GOS 001'),
        endsWith('/sessions/ps_123/staff/tickets/GOS%20001'));
    expect(ApiUrl.prayerSessionAttendanceReport('ps_123'),
        endsWith('/control/sessions/ps_123/report'));
  });

  test('prayer attendance links and notifications are narrowly routed', () {
    final link = parsePrayerSessionAttendanceLink(
      Uri.parse(
          'https://portal.goshenretreat.uk/prayer-session-attendance?session_id=ps_123'),
    );
    expect(link?.sessionId, 'ps_123');
    expect(
        parsePrayerSessionAttendanceLink(
            Uri.parse('https://portal.goshenretreat.uk/goshen-retreat')),
        isNull);
    expect(
        isPrayerSessionAttendanceNotification(
            const {'action': 'prayer_session_attendance'}),
        isTrue);
    expect(isPrayerSessionAttendanceNotification(const {'action': 'inbox'}),
        isFalse);
  });

  test('staff ticket and report payloads preserve authorized server fields',
      () {
    final ticket = PrayerSessionStaffTicket.fromJson(const {
      'id': 'ticket_123',
      'ticket_number': 'GOS-001',
      'attendee_name': 'Great Greatest',
    });
    final report = PrayerSessionReport.fromJson(const {
      'metrics': {'confirmed': 1, 'not_confirmed': 2},
      'rows': [
        {
          'status': 'Confirmed',
          'ticket_id': 'ticket_123',
          'confirmed_at': '2026-07-22T10:00:00Z',
        },
        {
          'status': 'Not Confirmed',
          'ticket_id': 'ticket_456',
        },
      ],
    });
    expect(ticket.ticketNumber, 'GOS-001');
    expect(report.metrics['not_confirmed'], 2);
    expect(report.rows, hasLength(2));
    expect(report.confirmed.single['ticket_id'], 'ticket_123');
  });
}
