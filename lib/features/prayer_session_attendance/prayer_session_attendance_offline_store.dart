import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/Userdata.dart';
import 'prayer_session_attendance_models.dart';

class PrayerAttendanceOfflineStore {
  PrayerAttendanceOfflineStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
                aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final FlutterSecureStorage _storage;

  String _key(Userdata user) =>
      'prayer_attendance_queue_${user.email ?? 'member'}';
  Future<List<PrayerAttendanceOfflineRecord>> load(Userdata user) async {
    final raw = await _storage.read(key: _key(user));
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) => PrayerAttendanceOfflineRecord.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      await _storage.delete(key: _key(user));
      return const [];
    }
  }

  Future<void> save(
          Userdata user, List<PrayerAttendanceOfflineRecord> values) =>
      _storage.write(
          key: _key(user),
          value: jsonEncode(values.map((value) => value.toJson()).toList()));
  PrayerAttendanceOfflineRecord record(String sessionId, String ticketCode) =>
      PrayerAttendanceOfflineRecord(
          id: '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
          sessionId: sessionId,
          ticketCode: ticketCode,
          createdAt: DateTime.now());
}
