import 'package:dio/dio.dart';

import '../../models/Userdata.dart';
import '../../utils/ApiUrl.dart';
import '../../utils/api_response.dart';
import 'prayer_session_attendance_models.dart';

class PrayerSessionAttendanceApi {
  PrayerSessionAttendanceApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<PrayerAttendanceCapability> fetchCapability(Userdata user) async {
    try {
      final data = _map(
          (await _dio.get(ApiUrl.ADDON_CAPABILITIES, options: _options(user)))
              .data);
      final capabilities =
          ((data['data'] as Map?)?['capabilities'] as List?) ?? const [];
      for (final item in capabilities.whereType<Map>()) {
        final capability = Map<String, dynamic>.from(item);
        if (capability['key'] == 'prayer_session_attendance') {
          return PrayerAttendanceCapability(
            active: true,
            permissions: ((capability['permissions'] as List?) ?? const [])
                .map((entry) => '$entry')
                .toList(),
          );
        }
      }
    } catch (_) {
      // The feature remains hidden until both authority checks succeed.
    }
    return const PrayerAttendanceCapability(active: false);
  }

  Future<List<PrayerSessionSummary>> activeSessions(Userdata user) async {
    final data =
        await _get(user, ApiUrl.PRAYER_SESSION_ATTENDANCE_ACTIVE_SESSIONS);
    return _sessionRows(data);
  }

  Future<List<PrayerSessionSummary>> controlSessions(Userdata user) async {
    final data =
        await _get(user, ApiUrl.PRAYER_SESSION_ATTENDANCE_CONTROL_SESSIONS);
    return _sessionRows(data);
  }

  Future<PrayerAttendanceResult> confirmSelf(
    Userdata user,
    String qrToken,
    String? ticketIdentifier,
    String idempotencyKey, {
    String? sessionName,
  }) async {
    final data =
        await _post(user, ApiUrl.PRAYER_SESSION_ATTENDANCE_SELF_CONFIRMATIONS, {
      'qr_token': qrToken,
      if (ticketIdentifier != null && ticketIdentifier.isNotEmpty)
        'ticket_identifier': ticketIdentifier,
      'idempotency_key': idempotencyKey,
    });
    return PrayerAttendanceResult.fromJson(
      _dataMap(data),
      sessionName: sessionName,
    );
  }

  Future<PrayerAttendanceResult> staffConfirm(
    Userdata user,
    PrayerSessionSummary session,
    String ticketIdentifier,
    String idempotencyKey,
  ) async {
    final data = await _post(
      user,
      ApiUrl.prayerSessionAttendanceStaffConfirmation(session.id),
      {
        'ticket_identifier': ticketIdentifier,
        'method': 'staff_ticket_scan',
        'idempotency_key': idempotencyKey,
      },
    );
    return PrayerAttendanceResult.fromJson(_dataMap(data),
        sessionName: session.name);
  }

  Future<PrayerSessionStaffTicket> staffLookup(
    Userdata user,
    PrayerSessionSummary session,
    String identifier,
  ) async {
    final data = await _get(
      user,
      ApiUrl.prayerSessionAttendanceStaffTicket(session.id, identifier),
    );
    return PrayerSessionStaffTicket.fromJson(
      Map<String, dynamic>.from(_dataMap(data)['ticket'] as Map? ?? const {}),
    );
  }

  Future<PrayerSessionReport> report(
    Userdata user,
    PrayerSessionSummary session,
  ) async {
    final data = await _get(
      user,
      ApiUrl.prayerSessionAttendanceReport(session.id),
    );
    return PrayerSessionReport.fromJson(_dataMap(data));
  }

  Future<void> activate(Userdata user, PrayerSessionSummary session) => _post(
        user,
        ApiUrl.prayerSessionAttendanceControlSessionAction(
            session.id, 'activate'),
        const {},
      );

  Future<void> close(Userdata user, PrayerSessionSummary session) => _post(
        user,
        ApiUrl.prayerSessionAttendanceControlSessionAction(session.id, 'close'),
        const {},
      );

  Future<void> remind(Userdata user, PrayerSessionSummary session) => _post(
        user,
        ApiUrl.prayerSessionAttendanceControlSessionAction(
            session.id, 'reminder'),
        const {},
      );

  Future<List<PrayerAttendanceOfflineRecord>> sync(
    Userdata user,
    List<PrayerAttendanceOfflineRecord> records,
  ) async {
    final data = await _post(user, ApiUrl.PRAYER_SESSION_ATTENDANCE_STAFF_SYNC,
        {'records': records.map((record) => record.toSyncJson()).toList()});
    final rejected = (_dataMap(data)['rejected'] as List?) ?? const [];
    return rejected
        .whereType<Map>()
        .map((record) => PrayerAttendanceOfflineRecord.fromJson(
            Map<String, dynamic>.from(record)))
        .toList();
  }

  static bool isRetryableConnectionFailure(Object error) {
    if (error is! DioException || error.response != null) return false;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      _ => false,
    };
  }

  Future<Map<String, dynamic>> _get(Userdata user, String url) async =>
      _map((await _dio.get(url, options: _options(user))).data);

  Future<Map<String, dynamic>> _post(
    Userdata user,
    String url,
    Map<String, dynamic> body,
  ) async =>
      _map((await _dio.post(url, data: body, options: _options(user))).data);

  List<PrayerSessionSummary> _sessionRows(Map<String, dynamic> response) {
    final rows = (_dataMap(response)['sessions'] as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map((row) =>
            PrayerSessionSummary.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(response['data'] as Map? ?? const {});

  Map<String, dynamic> _map(dynamic value) {
    final decoded = decodeApiResponse(value);
    final data = Map<String, dynamic>.from(decoded as Map? ?? const {});
    // Capability discovery originally shipped without the standard status
    // envelope. Accept that legacy success shape while production migrates.
    if (data['status'] != null && data['status'] != 'ok') {
      throw Exception(
          '${data['message'] ?? 'Prayer attendance is unavailable.'}');
    }
    return data;
  }

  Options _options(Userdata user) => Options(
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          if ((user.apiToken ?? '').trim().isNotEmpty)
            'Authorization': 'Bearer ${user.apiToken}',
        },
        validateStatus: (status) => status != null && status < 500,
      );
}
