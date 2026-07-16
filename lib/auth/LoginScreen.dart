import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../models/Userdata.dart';
import '../providers/AppStateManager.dart';
import '../utils/Alerts.dart';
import '../utils/ApiUrl.dart';
import '../utils/my_colors.dart';
import 'ForgotPasswordScreen.dart';
import 'PhoneOtpLoginScreen.dart';
import 'RegisterScreen.dart';
import 'VerifyEmailScreen.dart';
import 'auth_ui.dart';
import 'google_auth_service.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = "/login";

  @override
  LoginScreenRouteState createState() => LoginScreenRouteState();
}

class LoginScreenRouteState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final googleAuth = GoogleAuthService();
  bool googleEnabled = false;
  bool phoneEnabled = false;
  bool googleLoading = false;
  bool loginLoading = false;
  bool _loginProgressVisible = false;

  @override
  void initState() {
    super.initState();
    _loadGoogleConfig();
  }

  Future<void> _loadGoogleConfig() async {
    try {
      final config = await googleAuth.fetchConfig();
      if (!mounted) return;
      setState(() {
        googleEnabled = config.enabled;
        phoneEnabled = config.phoneLoginEnabled;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        googleEnabled = false;
        phoneEnabled = false;
      });
    }
  }

  void verifyFormAndSubmit() {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      Alerts.show(context, t.error, t.emptyfielderrorhint);
    } else if (!EmailValidator.validate(email)) {
      Alerts.show(context, t.error, t.invalidemailerrorhint);
    } else {
      loginUser(email, password);
    }
  }

  Future<void> loginUser(String email, String password) async {
    if (loginLoading) return;
    setState(() => loginLoading = true);
    _showLoginProgress();

    try {
      final response = await http
          .post(
            Uri.parse(ApiUrl.LOGIN),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              "data": {"email": email, "password": password}
            }),
          )
          .timeout(const Duration(seconds: 30));
      _dismissLoginProgress();

      if (response.statusCode != 200) {
        Alerts.show(context, t.error, _httpErrorMessage(response));
        return;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        Alerts.show(context, t.error, 'Unable to read the sign-in response.');
        return;
      }

      final res = decoded;
      if (res["status"] == "error") {
        if (res["needs_verification"] == true) {
          Alerts.show(context, 'Email verification required',
              _messageFrom(res, 'Please verify your email address.'));
          Navigator.of(context).pushNamed(
            VerifyEmailScreen.routeName,
            arguments: VerifyEmailArgs(email: email, password: password),
          );
          return;
        }
        if (res["google_account"] == true) {
          _showGoogleAccountHelp();
          return;
        }
        Alerts.show(context, t.error, _messageFrom(res, t.error));
        return;
      }

      final userPayload = _extractUserPayload(res);
      if (userPayload == null) {
        Alerts.show(context, t.error,
            'Sign-in succeeded but no user profile was returned.');
        return;
      }

      if ((userPayload['api_token'] ?? '').toString().trim().isEmpty) {
        Alerts.show(context, t.error,
            'Sign-in succeeded but no secure session token was returned.');
        return;
      }

      await Provider.of<AppStateManager>(context, listen: false)
          .setUserData(Userdata.fromJson(userPayload));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (exception) {
      debugPrint('Login failed: $exception');
      _dismissLoginProgress();
      if (!mounted) return;
      Alerts.show(context, t.error, _friendlyLoginException(exception));
    } finally {
      if (mounted) setState(() => loginLoading = false);
    }
  }

  void _showLoginProgress() {
    _loginProgressVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator.adaptive(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  t.processingpleasewait,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _dismissLoginProgress() {
    if (!mounted || !_loginProgressVisible) return;
    _loginProgressVisible = false;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Map<String, dynamic>? _extractUserPayload(Map<String, dynamic> response) {
    Map<String, dynamic>? user;
    final directUser = response['user'];
    if (directUser is Map) {
      user = Map<String, dynamic>.from(directUser);
    }

    final data = response['data'];
    if (user == null && data is Map) {
      final nestedUser = data['user'];
      if (nestedUser is Map) {
        user = Map<String, dynamic>.from(nestedUser);
      } else if (_looksLikeUserPayload(data)) {
        user = Map<String, dynamic>.from(data);
      }
    }

    if (user == null) return null;

    final token = response['api_token'] ??
        response['token'] ??
        (data is Map ? data['api_token'] ?? data['token'] : null);
    if ((user['api_token']?.toString().trim().isEmpty ?? true) &&
        token != null) {
      user['api_token'] = token.toString();
    }

    return user;
  }

  bool _looksLikeUserPayload(Map<dynamic, dynamic> payload) {
    return payload.containsKey('email') ||
        payload.containsKey('api_token') ||
        payload.containsKey('token');
  }

  String _friendlyLoginException(Object exception) {
    final message = exception.toString();
    if (message.contains('canManageCounseling') ||
        message.contains('no column named')) {
      return 'The app updated your local profile storage. Please try signing in again.';
    }
    if (message.contains('SocketException') ||
        message.contains('HandshakeException') ||
        message.contains('TimeoutException')) {
      return 'Unable to reach the sign-in service. Please check your connection and try again.';
    }
    return 'Unable to complete sign-in right now. Please try again.';
  }

  String _httpErrorMessage(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return _messageFrom(decoded, 'Unable to sign in right now.');
      }
    } catch (_) {
      // Fall through to the generic message.
    }

    if (response.statusCode == 419) {
      return 'The sign-in session expired. Please try again.';
    }
    if (response.statusCode >= 500) {
      return 'The server could not complete sign-in right now.';
    }

    return 'Unable to sign in right now.';
  }

  String _messageFrom(Map<String, dynamic> response, String fallback) {
    final message = response['message'] ?? response['msg'];
    return message == null || message.toString().trim().isEmpty
        ? fallback
        : message.toString();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => googleLoading = true);
    try {
      final user = await googleAuth.signIn(context);
      if (!mounted) return;
      if (user != null) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        Alerts.show(
            context, t.error, 'Unable to sign in with Google right now.');
      }
    } finally {
      if (mounted) setState(() => googleLoading = false);
    }
  }

  Future<void> _showGoogleAccountHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use Google or create a password'),
        content: const Text(
          'This email was registered with Google. You can continue with Google, or use Forgot Password to create a password for email sign-in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(ForgotPasswordScreen.routeName);
            },
            child: const Text('Create password'),
          ),
          if (googleEnabled)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _signInWithGoogle();
              },
              child: const Text('Use Google'),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Sign in securely to continue with MFM Triumphant Church.',
      child: Column(
        children: [
          AuthTextField(
            controller: emailController,
            label: t.emailaddress,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: passwordController,
            label: t.password,
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context)
                  .pushNamed(ForgotPasswordScreen.routeName),
              child: Text(
                t.forgotpassword,
                style: TextStyle(
                    color: isDark ? const Color(0xFFFFC857) : MyColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AuthPrimaryButton(
            label: loginLoading ? t.processingpleasewait : t.signin,
            icon: Icons.login_rounded,
            onPressed: loginLoading ? null : verifyFormAndSubmit,
          ),
          if (googleEnabled) ...[
            const SizedBox(height: 12),
            _SecondaryAuthButton(
              label: googleLoading ? 'Connecting...' : 'Continue with Google',
              icon: Icons.g_mobiledata_rounded,
              onPressed: googleLoading ? null : _signInWithGoogle,
            ),
          ],
          if (phoneEnabled) ...[
            const SizedBox(height: 12),
            _SecondaryAuthButton(
              label: 'Continue with phone',
              icon: Icons.phone_iphone_rounded,
              onPressed: () => Navigator.of(context)
                  .pushNamed(PhoneOtpLoginScreen.routeName),
            ),
          ],
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pushReplacementNamed(RegisterScreen.routeName),
            child: Text(
              t.signinforanaccount,
              style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF5E6F78)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryAuthButton extends StatelessWidget {
  const _SecondaryAuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: icon == Icons.g_mobiledata_rounded ? 30 : 22),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : MyColors.primary,
          side: BorderSide(
              color: isDark ? Colors.white24 : const Color(0xFFDCE5EA)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
