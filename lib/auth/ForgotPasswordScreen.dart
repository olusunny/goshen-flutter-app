import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../i18n/strings.g.dart';
import '../utils/Alerts.dart';
import '../utils/ApiUrl.dart';
import '../utils/my_colors.dart';
import 'LoginScreen.dart';
import 'auth_ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  static const routeName = "/forgotpassword";

  @override
  ForgotPasswordScreenRouteState createState() =>
      ForgotPasswordScreenRouteState();
}

class ForgotPasswordScreenRouteState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final repeatPasswordController = TextEditingController();
  bool codeSent = false;

  Future<void> requestCode() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      Alerts.show(context, t.error, t.emptyfielderrorhint);
    } else if (!EmailValidator.validate(email)) {
      Alerts.show(context, t.error, t.invalidemailerrorhint);
    } else {
      Alerts.showProgressDialog(context, t.processingpleasewait);
      try {
        final response = await http.post(
          Uri.parse(ApiUrl.REQUEST_PASSWORD_RESET),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "data": {"email": email}
          }),
        );
        Navigator.of(context).pop();
        final res = json.decode(response.body) as Map<String, dynamic>;
        if (response.statusCode != 200 || res["status"] == "error") {
          Alerts.show(context, t.error,
              _messageFrom(res, 'Unable to send reset code.'));
          return;
        }
        setState(() => codeSent = true);
        Alerts.show(
            context,
            t.success,
            _messageFrom(
                res, 'If your email exists, a reset code has been sent.'));
      } catch (_) {
        Navigator.of(context).pop();
        Alerts.show(context, t.error, 'Unable to send reset code right now.');
      }
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    final code = codeController.text.trim();
    final password = passwordController.text;
    final repeatPassword = repeatPasswordController.text;

    if (email.isEmpty ||
        code.isEmpty ||
        password.isEmpty ||
        repeatPassword.isEmpty) {
      Alerts.show(context, t.error, t.emptyfielderrorhint);
    } else if (password.length < 8) {
      Alerts.show(context, t.error, 'Password must be at least 8 characters.');
    } else if (password != repeatPassword) {
      Alerts.show(context, t.error, t.passwordsdontmatch);
    } else {
      Alerts.showProgressDialog(context, t.processingpleasewait);
      try {
        final response = await http.post(
          Uri.parse(ApiUrl.RESET_MOBILE_PASSWORD),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "data": {"email": email, "code": code, "password": password}
          }),
        );
        Navigator.of(context).pop();
        final res = json.decode(response.body) as Map<String, dynamic>;
        if (response.statusCode != 200 || res["status"] == "error") {
          Alerts.show(
              context, t.error, _messageFrom(res, 'Unable to reset password.'));
          return;
        }
        await Alerts.show(
          context,
          'Password reset successful',
          _messageFrom(
            res,
            'Your password has been reset successfully. Please sign in with your new password.',
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
      } catch (_) {
        Navigator.of(context).pop();
        Alerts.show(context, t.error, 'Unable to reset password right now.');
      }
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
    emailController.dispose();
    codeController.dispose();
    passwordController.dispose();
    repeatPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AuthShell(
      title: 'Recover password',
      subtitle: codeSent
          ? 'Enter the reset code before it expires in 30 minutes, then choose a new secure password.'
          : 'We will email a short reset code to your registered address.',
      child: Column(
        children: [
          AuthTextField(
            controller: emailController,
            label: t.emailaddress,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          if (codeSent) ...[
            const SizedBox(height: 14),
            AuthTextField(
              controller: codeController,
              label: 'Reset code',
              icon: Icons.password_rounded,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: passwordController,
              label: 'New password',
              icon: Icons.lock_reset_rounded,
              isPassword: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: repeatPasswordController,
              label: t.repeatpassword,
              icon: Icons.verified_user_outlined,
              isPassword: true,
              textInputAction: TextInputAction.done,
            ),
          ],
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: codeSent ? 'Reset password' : t.resetpassword,
            icon: codeSent
                ? Icons.lock_reset_rounded
                : Icons.mark_email_read_outlined,
            onPressed: codeSent ? resetPassword : requestCode,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pushReplacementNamed(LoginScreen.routeName),
            child: Text(
              t.backtologin,
              style:
                  TextStyle(color: isDark ? Colors.white70 : MyColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
