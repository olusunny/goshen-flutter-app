import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/Userdata.dart';
import '../providers/AppStateManager.dart';
import '../utils/Alerts.dart';
import '../utils/ApiUrl.dart';

class PhoneAuthConfig {
  const PhoneAuthConfig({required this.enabled});

  final bool enabled;

  factory PhoneAuthConfig.fromJson(Map<String, dynamic> json) {
    return PhoneAuthConfig(
      enabled: _readBool(json['mobile_phone_otp_login_enabled']),
    );
  }
}

class PhoneAuthService {
  PhoneAuthConfig? _config;

  Future<PhoneAuthConfig> fetchConfig({bool force = false}) async {
    if (_config != null && !force) return _config!;

    final response = await http.get(Uri.parse(ApiUrl.DISCOVER));
    if (response.statusCode != 200) {
      throw Exception('Unable to load phone sign-in settings.');
    }

    _config = PhoneAuthConfig.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
    return _config!;
  }

  Future<Userdata?> completeBackendLogin(
    BuildContext context, {
    required String idToken,
  }) async {
    final response = await http.post(
      Uri.parse(ApiUrl.PHONE_AUTH),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'data': {'id_token': idToken}
      }),
    );

    final result = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || result['status'] == 'error') {
      final message = result['message'] ??
          result['msg'] ??
          'Unable to sign in with phone right now.';
      Alerts.show(context, 'Phone sign-in failed', message.toString());
      return null;
    }

    final user = Userdata.fromJson(result['user'] as Map<String, dynamic>);
    await Provider.of<AppStateManager>(context, listen: false)
        .setUserData(user);
    return user;
  }
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase().trim() ?? '';
  return text == '1' || text == 'true' || text == 'yes' || text == 'on';
}
