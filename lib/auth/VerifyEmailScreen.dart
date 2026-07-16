import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../models/Userdata.dart';
import '../providers/AppStateManager.dart';
import '../utils/Alerts.dart';
import '../utils/ApiUrl.dart';
import 'LoginScreen.dart';
import 'auth_ui.dart';

class VerifyEmailArgs {
  const VerifyEmailArgs({required this.email, this.password});

  final String email;
  final String? password;
}

class VerifyEmailScreen extends StatefulWidget {
  static const routeName = "/verify-email";

  const VerifyEmailScreen({Key? key, required this.email, this.password})
      : super(key: key);

  final String email;
  final String? password;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final codeController = TextEditingController();

  Future<void> verify() async {
    final code = codeController.text.trim();
    if (code.isEmpty) {
      Alerts.show(
          context, t.error, 'Enter the verification code sent to your email.');
      return;
    }

    Alerts.showProgressDialog(context, t.processingpleasewait);
    try {
      final response = await http.post(
        Uri.parse(ApiUrl.VERIFY_EMAIL),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "data": {"email": widget.email, "code": code}
        }),
      );
      Navigator.of(context).pop();
      final res = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || res["status"] == "error") {
        Alerts.show(
            context, t.error, _messageFrom(res, 'Unable to verify email.'));
        return;
      }

      if (res["user"] != null) {
        await Provider.of<AppStateManager>(context, listen: false)
            .setUserData(Userdata.fromJson(res["user"]));
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Alerts.show(context, t.success,
            _messageFrom(res, 'Email verified successfully.'));
        Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
      }
    } catch (_) {
      Navigator.of(context).pop();
      Alerts.show(context, t.error, 'Unable to verify email right now.');
    }
  }

  Future<void> resend() async {
    Alerts.showProgressDialog(context, t.processingpleasewait);
    try {
      final response = await http.post(
        Uri.parse(ApiUrl.RESEND_VERIFICATION),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "data": {"email": widget.email}
        }),
      );
      Navigator.of(context).pop();
      final res = json.decode(response.body) as Map<String, dynamic>;
      Alerts.show(context, res["status"] == "error" ? t.error : t.success,
          _messageFrom(res, 'Verification code sent.'));
    } catch (_) {
      Navigator.of(context).pop();
      Alerts.show(
          context, t.error, 'Unable to resend verification code right now.');
    }
  }

  String _messageFrom(Map<String, dynamic> response, String fallback) {
    final message = response['message'] ?? response['msg'];
    return message == null || message.toString().trim().isEmpty
        ? fallback
        : message.toString();
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AuthShell(
      title: 'Verify email',
      subtitle:
          'Enter the code sent to ${widget.email}. The code expires after 30 minutes. If you cannot find it, please check your Spam or Junk folder too.',
      child: Column(
        children: [
          AuthTextField(
            controller: codeController,
            label: 'Verification code',
            icon: Icons.mark_email_read_outlined,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: 'Verify account',
            icon: Icons.verified_rounded,
            onPressed: verify,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: resend,
            child: Text(
              'Resend code',
              style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF0C2230)),
            ),
          ),
        ],
      ),
    );
  }
}
