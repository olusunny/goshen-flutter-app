import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/Userdata.dart';

class ChurchBirthdayGreetingStore {
  Future<int?> read(Userdata user, String celebrationId) async {
    final value = (await SharedPreferences.getInstance())
        .getInt(_key(user, celebrationId));
    return value != null && value > 0 ? value : null;
  }

  Future<void> write(
      Userdata user, String celebrationId, int greetingId) async {
    await (await SharedPreferences.getInstance())
        .setInt(_key(user, celebrationId), greetingId);
  }

  Future<void> clear(Userdata user, String celebrationId) async {
    await (await SharedPreferences.getInstance())
        .remove(_key(user, celebrationId));
  }

  String _key(Userdata user, String celebrationId) {
    final account = (user.email ?? user.apiToken ?? '').trim();
    return 'birthday_greeting_${base64Url.encode(utf8.encode('$account:$celebrationId'))}';
  }
}
