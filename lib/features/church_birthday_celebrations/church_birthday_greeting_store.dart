import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/Userdata.dart';

class ChurchBirthdayGreetingStore {
  ChurchBirthdayGreetingStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<int?> read(Userdata user, String celebrationId) async {
    try {
      final value =
          (await _preferencesLoader()).getInt(_key(user, celebrationId));
      return value != null && value > 0 ? value : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(
      Userdata user, String celebrationId, int greetingId) async {
    try {
      await (await _preferencesLoader())
          .setInt(_key(user, celebrationId), greetingId);
    } catch (_) {
      // Server data remains authoritative when local cache persistence fails.
    }
  }

  Future<void> clear(Userdata user, String celebrationId) async {
    try {
      await (await _preferencesLoader()).remove(_key(user, celebrationId));
    } catch (_) {
      // Server data remains authoritative when local cache persistence fails.
    }
  }

  String _key(Userdata user, String celebrationId) {
    final account = (user.email ?? user.apiToken ?? '').trim();
    return 'birthday_greeting_${base64Url.encode(utf8.encode('$account:$celebrationId'))}';
  }
}
