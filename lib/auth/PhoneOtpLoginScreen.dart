import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../utils/Alerts.dart';
import '../utils/my_colors.dart';
import '../utils/phone_country_codes.dart';
import 'auth_ui.dart';
import 'phone_auth_service.dart';

class PhoneOtpLoginScreen extends StatefulWidget {
  const PhoneOtpLoginScreen({Key? key}) : super(key: key);

  static const routeName = '/phone-otp-login';

  @override
  State<PhoneOtpLoginScreen> createState() => _PhoneOtpLoginScreenState();
}

class _PhoneOtpLoginScreenState extends State<PhoneOtpLoginScreen>
    with CodeAutoFill {
  final _dialCodeController = TextEditingController(text: defaultDialCode());
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _service = PhoneAuthService();

  String? _verificationId;
  int? _resendToken;
  bool _loading = false;
  bool _codeSent = false;
  bool _autoVerifying = false;

  @override
  void dispose() {
    cancel();
    unregisterListener();
    _dialCodeController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  void codeUpdated() {
    final receivedCode = (code ?? '').trim();
    if (receivedCode.isEmpty || !_codeSent || _autoVerifying) return;

    _codeController.text = receivedCode;
    if (receivedCode.length >= 4) {
      _verifyCode(autoSubmitted: true);
    }
  }

  Future<void> _sendCode() async {
    if (_loading) return;
    final phone = toE164Phone(_dialCodeController.text, _phoneController.text);
    if (!looksLikeE164(phone)) {
      Alerts.show(context, 'Phone number required',
          'Enter a valid mobile number including the correct country code.');
      return;
    }

    setState(() => _loading = true);
    try {
      final config = await _service.fetchConfig();
      if (!config.enabled) {
        if (mounted) {
          Alerts.show(context, 'Phone sign-in unavailable',
              'Phone OTP login has not been enabled by the church admin yet.');
        }
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) async {
          await _signInWithCredential(credential, allowWhileLoading: true);
        },
        verificationFailed: (error) {
          if (!mounted) return;
          setState(() => _loading = false);
          Alerts.show(
            context,
            'Verification failed',
            error.message ??
                'Firebase could not send a verification code to this phone.',
          );
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _loading = false;
          });
          _listenForIncomingOtp();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (_) {
      if (mounted) {
        Alerts.show(context, 'Phone sign-in unavailable',
            'Unable to start phone sign-in right now.');
      }
    } finally {
      if (mounted && !_codeSent) setState(() => _loading = false);
    }
  }

  void _listenForIncomingOtp() {
    try {
      cancel();
      listenForCode(smsCodeRegexPattern: r'\d{4,6}');
    } catch (_) {}
  }

  Future<void> _verifyCode({bool autoSubmitted = false}) async {
    if (_loading && !autoSubmitted) return;
    final verificationId = _verificationId;
    final code = _codeController.text.trim();

    if (verificationId == null || verificationId.isEmpty) {
      Alerts.show(context, 'Request a code', 'Request a new SMS code first.');
      return;
    }
    if (code.length < 4) {
      Alerts.show(context, 'Code required', 'Enter the SMS verification code.');
      return;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
    await _signInWithCredential(
      credential,
      allowWhileLoading: autoSubmitted,
      autoSubmitted: autoSubmitted,
    );
  }

  Future<void> _signInWithCredential(
    PhoneAuthCredential credential, {
    bool allowWhileLoading = false,
    bool autoSubmitted = false,
  }) async {
    if (_loading && !allowWhileLoading) return;
    setState(() {
      _loading = true;
      _autoVerifying = autoSubmitted;
    });
    try {
      final firebaseUser =
          (await FirebaseAuth.instance.signInWithCredential(credential)).user;
      final idToken = await firebaseUser?.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          Alerts.show(context, 'Phone sign-in failed',
              'Firebase did not return a secure ID token.');
        }
        return;
      }

      if (!mounted) return;
      final user = await _service.completeBackendLogin(
        context,
        idToken: idToken,
      );
      if (user != null && mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        Alerts.show(context, 'Phone sign-in failed',
            'The code could not be verified. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _autoVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AuthShell(
      title: 'Phone sign in',
      subtitle:
          'Verify your mobile number with Firebase OTP to continue securely.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _dialCodeController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    color: isDark ? Colors.white : MyColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Code',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF071720)
                        : const Color(0xFFF5F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AuthTextField(
                  controller: _phoneController,
                  label: 'Mobile number',
                  icon: Icons.phone_iphone_rounded,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                ),
              ),
            ],
          ),
          if (_codeSent) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (value) {
                if (value.trim().length >= 6) {
                  _verifyCode(autoSubmitted: true);
                }
              },
              style: TextStyle(
                color: isDark ? Colors.white : MyColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
              decoration: InputDecoration(
                labelText:
                    _autoVerifying ? 'Verifying SMS code...' : 'SMS code',
                prefixIcon:
                    const Icon(Icons.sms_outlined, color: Color(0xFFFFB522)),
                helperText:
                    'The app will fill and verify the code automatically when possible.',
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          AuthPrimaryButton(
            label: _loading
                ? 'Please wait...'
                : (_codeSent ? 'Verify code' : 'Send OTP'),
            icon: _codeSent ? Icons.verified_user_outlined : Icons.sms_rounded,
            onPressed: _codeSent ? _verifyCode : _sendCode,
          ),
          if (_codeSent) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : _sendCode,
              child: const Text('Resend code'),
            ),
          ],
        ],
      ),
    );
  }
}
