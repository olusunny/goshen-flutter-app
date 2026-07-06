import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/Userdata.dart';
import '../providers/AppStateManager.dart';
import '../utils/Alerts.dart';
import '../utils/ApiUrl.dart';

class GoogleAuthConfig {
  const GoogleAuthConfig({
    required this.enabled,
    this.webClientId = '',
    this.androidClientId = '',
    this.iosClientId = '',
    this.phoneLoginEnabled = false,
  });

  final bool enabled;
  final String webClientId;
  final String androidClientId;
  final String iosClientId;
  final bool phoneLoginEnabled;

  factory GoogleAuthConfig.fromJson(Map<String, dynamic> json) {
    return GoogleAuthConfig(
      enabled: _readBool(json['google_login_enabled']),
      webClientId: (json['google_web_client_id'] ?? '').toString(),
      androidClientId: (json['google_android_client_id'] ?? '').toString(),
      iosClientId: (json['google_ios_client_id'] ?? '').toString(),
      phoneLoginEnabled: _readBool(json['mobile_phone_otp_login_enabled']),
    );
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().toLowerCase().trim() ?? '';
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }
}

class GoogleAuthService {
  GoogleAuthConfig? _config;

  Future<GoogleAuthConfig> fetchConfig({bool force = false}) async {
    if (_config != null && !force) return _config!;

    final response = await http.get(Uri.parse(ApiUrl.DISCOVER));
    if (response.statusCode != 200) {
      throw Exception('Unable to load Google sign-in settings.');
    }

    _config = GoogleAuthConfig.fromJson(
        json.decode(response.body) as Map<String, dynamic>);
    return _config!;
  }

  Future<Userdata?> signIn(BuildContext context) async {
    final result = await signInWithResult(context);
    return result?.user;
  }

  Future<GoogleAuthResult?> signInWithResult(BuildContext context) async {
    final config = await fetchConfig();
    if (!config.enabled) {
      Alerts.show(context, 'Google sign-in unavailable',
          'Google sign-in has not been enabled by the church admin yet.');
      return null;
    }

    final googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId:
          config.webClientId.trim().isEmpty ? null : config.webClientId.trim(),
    );

    GoogleSignInAccount? account;
    GoogleSignInAuthentication auth;
    try {
      account = await googleSignIn.signIn();
      if (account == null) return null;

      auth = await account.authentication;
    } on PlatformException catch (error) {
      debugPrint(
          'Google sign-in platform error: ${error.code} ${error.message}');
      Alerts.show(
        context,
        'Google sign-in setup issue',
        _platformMessage(error),
      );
      return null;
    }

    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      Alerts.show(context, 'Google setup required',
          'Google did not return a secure identity token. Add the Web client ID in the admin Google auth settings and try again.');
      return null;
    }

    final response = await http.post(
      Uri.parse(ApiUrl.GOOGLE_AUTH),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'data': {
          'id_token': idToken,
          'email': account.email,
          'name': account.displayName,
          'photo_url': account.photoUrl,
        }
      }),
    );

    final result = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || result['status'] == 'error') {
      final message = result['message'] ??
          result['msg'] ??
          'Unable to sign in with Google right now.';
      Alerts.show(context, 'Google sign-in failed', message.toString());
      return null;
    }

    final user = Userdata.fromJson(result['user'] as Map<String, dynamic>);
    await Provider.of<AppStateManager>(context, listen: false)
        .setUserData(user);
    return GoogleAuthResult(
      user: user,
      isNewUser: _readBool(result['is_new_user']),
      profileNeedsUpdate: _readBool(result['profile_needs_update']),
    );
  }

  String _platformMessage(PlatformException error) {
    final details = '${error.message ?? ''} ${error.details ?? ''}';
    if (details.contains('ApiException: 10') ||
        details.toLowerCase().contains('developer_error')) {
      return 'Google rejected this app configuration. Confirm the Android app package, release SHA-1/SHA-256 fingerprints, and Android OAuth client are present in Firebase/Google Cloud, then download a fresh google-services.json.';
    }

    if (details.contains('ApiException: 12500')) {
      return 'Google sign-in is not fully configured for this Firebase project. Check the OAuth consent screen and Google sign-in provider settings.';
    }

    return 'Google could not complete sign-in on this device. Please try again, or contact the church admin if this continues.';
  }
}

class GoogleAuthResult {
  const GoogleAuthResult({
    required this.user,
    required this.isNewUser,
    required this.profileNeedsUpdate,
  });

  final Userdata user;
  final bool isNewUser;
  final bool profileNeedsUpdate;
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase().trim() ?? '';
  return text == '1' || text == 'true' || text == 'yes' || text == 'on';
}
