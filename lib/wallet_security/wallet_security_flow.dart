import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/Userdata.dart';
import '../providers/AppStateManager.dart';
import '../service/GoshenWalletApi.dart';
import '../utils/my_colors.dart';
import 'wallet_pin_policy.dart';
import 'wallet_security_controller.dart';
import 'wallet_security_models.dart';

enum _WalletSecurityStep {
  loading,
  intro,
  createPin,
  confirmPin,
  biometricSetup,
  enrollmentRequired,
  unlock,
}

class WalletSecurityFlowScreen extends StatefulWidget {
  const WalletSecurityFlowScreen({
    super.key,
    this.requireFreshVerification = false,
    this.onCompleted,
    this.onCancelled,
    this.popOnCompleted = true,
  });

  final bool requireFreshVerification;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancelled;
  final bool popOnCompleted;

  @override
  State<WalletSecurityFlowScreen> createState() =>
      _WalletSecurityFlowScreenState();
}

class _WalletSecurityFlowScreenState extends State<WalletSecurityFlowScreen> {
  final _policy = const WalletPinPolicy();
  final _walletApi = GoshenWalletApi();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _unlockPinController = TextEditingController();
  _WalletSecurityStep _step = _WalletSecurityStep.loading;
  WalletSecurityMode _mode = WalletSecurityMode.unconfigured;
  WalletBiometricAvailability? _availability;
  String? _message;
  bool _busy = false;
  bool _serverResetAcknowledgementPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _unlockPinController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final controller =
        Provider.of<WalletSecurityController>(context, listen: false);
    var config = await controller.load();
    config = await _applyApprovedResetIfNeeded(controller, config);
    if (!mounted) return;
    _mode = config.mode;
    if (!config.isConfigured) {
      final availability = await controller.biometricAvailability();
      if (!mounted) return;
      setState(() {
        _availability = availability;
        _step = _WalletSecurityStep.intro;
      });
      return;
    }

    if (widget.requireFreshVerification
        ? controller.hasFreshVerification
        : controller.isWalletUnlocked) {
      _complete();
      return;
    }

    if (config.mode == WalletSecurityMode.biometricAndPin) {
      await _tryBiometricUnlock();
    } else {
      setState(() => _step = _WalletSecurityStep.unlock);
    }
  }

  Future<void> _tryBiometricUnlock() async {
    final controller =
        Provider.of<WalletSecurityController>(context, listen: false);
    setState(() {
      _busy = true;
      _message = null;
      _step = _WalletSecurityStep.unlock;
    });
    final result = await controller.unlockWithBiometrics();
    if (!mounted) return;
    if (result == WalletUnlockResult.success) {
      _complete();
      return;
    }
    setState(() {
      _busy = false;
      _message = _messageForBiometricResult(result);
    });
  }

  void _startPinSetup() {
    setState(() {
      _message = null;
      _step = _WalletSecurityStep.createPin;
    });
  }

  void _continueFromCreatePin() {
    final error = _policy.validate(_pinController.text);
    if (error != null) {
      setState(() => _message = error);
      return;
    }
    setState(() {
      _message = null;
      _step = _WalletSecurityStep.confirmPin;
    });
  }

  Future<void> _continueFromConfirmPin() async {
    final pin = _pinController.text;
    final confirmation = _confirmPinController.text;
    final error = _policy.validateConfirmation(pin, confirmation);
    if (error != null) {
      setState(() => _message = error);
      return;
    }

    final controller =
        Provider.of<WalletSecurityController>(context, listen: false);
    final availability =
        _availability ?? await controller.biometricAvailability();
    if (!mounted) return;
    _availability = availability;
    final mode = walletSecurityModeForAvailability(availability);
    if (mode == null) {
      setState(() {
        _message = null;
        _step = _WalletSecurityStep.enrollmentRequired;
      });
      return;
    }
    if (mode == WalletSecurityMode.biometricAndPin) {
      setState(() {
        _message = null;
        _step = _WalletSecurityStep.biometricSetup;
      });
      return;
    }
    await _finishSetup();
  }

  Future<void> _finishSetup() async {
    final controller =
        Provider.of<WalletSecurityController>(context, listen: false);
    setState(() {
      _busy = true;
      _message = null;
    });
    final result =
        await controller.configureWalletSecurity(_pinController.text);
    if (!mounted) return;
    if (result == WalletUnlockResult.success) {
      final acknowledged = await _acknowledgeServerResetIfNeeded();
      if (!mounted) return;
      if (!acknowledged) {
        setState(() => _busy = false);
        return;
      }
      _complete();
      return;
    }
    setState(() {
      _busy = false;
      _step = result == WalletUnlockResult.biometricEnrollmentRequired
          ? _WalletSecurityStep.enrollmentRequired
          : _WalletSecurityStep.biometricSetup;
      _message = _messageForBiometricResult(result);
    });
  }

  Future<void> _verifyPin() async {
    final pin = _unlockPinController.text;
    final validation = _policy.validate(pin);
    if (validation != null && !RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _message = validation);
      return;
    }
    final controller =
        Provider.of<WalletSecurityController>(context, listen: false);
    setState(() {
      _busy = true;
      _message = null;
    });
    final verification = await controller.verifyPin(pin);
    if (!mounted) return;
    if (verification.isSuccess) {
      _complete();
      return;
    }
    setState(() {
      _busy = false;
      _message = verification.message ?? 'Wallet PIN could not be verified.';
    });
  }

  Future<void> _openSettingsAndRecheck() async {
    final controller =
        Provider.of<WalletSecurityController>(context, listen: false);
    await controller.openBiometricEnrollmentSettings();
    final availability = await controller.biometricAvailability();
    if (!mounted) return;
    setState(() {
      _availability = availability;
      _message = availability == WalletBiometricAvailability.available
          ? null
          : 'Biometrics are still not enrolled on this device.';
      _step = availability == WalletBiometricAvailability.available
          ? _WalletSecurityStep.biometricSetup
          : _WalletSecurityStep.enrollmentRequired;
    });
  }

  void _complete() {
    widget.onCompleted?.call();
    if (widget.popOnCompleted && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    }
  }

  void _cancel() {
    widget.onCancelled?.call();
    if (Navigator.canPop(context)) {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_step) {
      _WalletSecurityStep.loading => _LoadingWalletSecurityScreen(),
      _WalletSecurityStep.intro => WalletSecuritySetupScreen(
          onContinue: _startPinSetup,
          onCancel: _cancel,
          message: _message,
        ),
      _WalletSecurityStep.createPin => CreateWalletPinScreen(
          controller: _pinController,
          message: _message,
          onBack: () => setState(() => _step = _WalletSecurityStep.intro),
          onContinue: _continueFromCreatePin,
        ),
      _WalletSecurityStep.confirmPin => ConfirmWalletPinScreen(
          controller: _confirmPinController,
          message: _message,
          busy: _busy,
          onBack: () => setState(() => _step = _WalletSecurityStep.createPin),
          onContinue: _continueFromConfirmPin,
        ),
      _WalletSecurityStep.biometricSetup => WalletBiometricSetupScreen(
          message: _message,
          busy: _busy,
          onEnable: _finishSetup,
          onBack: () => setState(() => _step = _WalletSecurityStep.confirmPin),
        ),
      _WalletSecurityStep.enrollmentRequired =>
        WalletBiometricEnrollmentRequiredScreen(
          message: _message,
          onOpenSettings: _openSettingsAndRecheck,
          onRecheck: _continueFromConfirmPin,
          onCancel: _cancel,
        ),
      _WalletSecurityStep.unlock => WalletUnlockScreen(
          mode: _mode,
          controller: _unlockPinController,
          message: _message,
          busy: _busy,
          onUseBiometric: _mode == WalletSecurityMode.biometricAndPin
              ? _tryBiometricUnlock
              : null,
          onVerifyPin: _verifyPin,
          onCancel: _cancel,
        ),
    };

    return PopScope(
      canPop: _step != _WalletSecurityStep.loading,
      child: content,
    );
  }

  String _messageForBiometricResult(WalletUnlockResult result) {
    switch (result) {
      case WalletUnlockResult.cancelled:
        return 'Biometric verification was cancelled. Use your wallet PIN if needed.';
      case WalletUnlockResult.failed:
        return 'Biometric verification is unavailable right now. Use your wallet PIN.';
      case WalletUnlockResult.lockedOut:
        return 'Biometrics are temporarily locked. Use your wallet PIN.';
      case WalletUnlockResult.biometricEnrollmentRequired:
        return 'Set up biometrics in your device settings before enabling wallet biometrics.';
      case WalletUnlockResult.setupRequired:
        return 'Set up wallet security first.';
      case WalletUnlockResult.success:
        return '';
    }
  }

  Future<WalletSecurityConfig> _applyApprovedResetIfNeeded(
    WalletSecurityController controller,
    WalletSecurityConfig config,
  ) async {
    final user = await _currentUser();
    final token = (user?.apiToken ?? '').trim();
    if (user == null || token.isEmpty) {
      return config;
    }

    try {
      final status = await _walletApi.walletSecurityResetStatus(user);
      if (!status.resetRequired) {
        return config;
      }

      await controller.resetWalletSecurity();
      _serverResetAcknowledgementPending = true;

      if (mounted) {
        setState(() {
          _message = status.message ??
              'Support approved your wallet security reset. Create a new wallet PIN to continue.';
        });
      }

      return controller.load();
    } catch (_) {
      return config;
    }
  }

  Future<bool> _acknowledgeServerResetIfNeeded() async {
    if (!_serverResetAcknowledgementPending) {
      return true;
    }

    final user = await _currentUser();
    final token = (user?.apiToken ?? '').trim();
    if (user == null || token.isEmpty) {
      if (!mounted) return false;
      setState(() {
        _message =
            'Wallet PIN was saved locally, but please sign in again so support reset can finish on the server.';
      });
      return false;
    }

    try {
      await _walletApi.acknowledgeWalletSecurityReset(user);
      _serverResetAcknowledgementPending = false;
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _message =
            'Wallet PIN was saved locally, but the server reset acknowledgement did not complete. Check your connection and try again.';
      });
      return false;
    }
  }

  Future<Userdata?> _currentUser() async {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    return appState.userdata ?? await appState.ensureUserDataLoaded();
  }
}

class WalletSecuritySetupScreen extends StatelessWidget {
  const WalletSecuritySetupScreen({
    super.key,
    required this.onContinue,
    required this.onCancel,
    this.message,
  });

  final VoidCallback onContinue;
  final VoidCallback onCancel;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return _WalletSecurityScaffold(
      title: 'Secure your wallet',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wallet security protects only your Goshen wallet balance, transfers, payment history, top-ups, and wallet settings. The rest of the app stays available as usual.',
            style: TextStyle(height: 1.45, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          _SecurityBullet(
            icon: Icons.pin_outlined,
            text: 'Create a 6-digit wallet PIN.',
          ),
          _SecurityBullet(
            icon: Icons.fingerprint_rounded,
            text:
                'If biometrics are enrolled on this device, you will also activate biometric unlock.',
          ),
          _SecurityBullet(
            icon: Icons.timer_outlined,
            text: 'Wallet unlock is local and expires after a short timeout.',
          ),
          _SecurityError(message: message),
          const SizedBox(height: 22),
          _SecurityPrimaryButton(
            label: 'Create wallet PIN',
            icon: Icons.lock_outline_rounded,
            onPressed: onContinue,
          ),
          TextButton(
            onPressed: onCancel,
            child: const Text('Not now'),
          ),
        ],
      ),
    );
  }
}

class CreateWalletPinScreen extends StatelessWidget {
  const CreateWalletPinScreen({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onContinue,
    this.message,
  });

  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return _WalletSecurityScaffold(
      title: 'Create wallet PIN',
      icon: Icons.pin_outlined,
      leading: BackButton(onPressed: onBack),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Use 6 digits that are not repeated or sequential.',
            style: TextStyle(height: 1.45, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          _PinField(controller: controller, label: 'Wallet PIN'),
          _SecurityError(message: message),
          const SizedBox(height: 16),
          _SecurityPrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class ConfirmWalletPinScreen extends StatelessWidget {
  const ConfirmWalletPinScreen({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onContinue,
    this.message,
    this.busy = false,
  });

  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final String? message;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return _WalletSecurityScaffold(
      title: 'Confirm wallet PIN',
      icon: Icons.verified_user_outlined,
      leading: BackButton(onPressed: busy ? null : onBack),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Re-enter your wallet PIN to confirm it.',
            style: TextStyle(height: 1.45, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          _PinField(controller: controller, label: 'Confirm PIN'),
          _SecurityError(message: message),
          const SizedBox(height: 16),
          _SecurityPrimaryButton(
            label: busy ? 'Saving...' : 'Continue',
            icon: Icons.check_rounded,
            onPressed: busy ? null : onContinue,
          ),
        ],
      ),
    );
  }
}

class WalletBiometricSetupScreen extends StatelessWidget {
  const WalletBiometricSetupScreen({
    super.key,
    required this.onEnable,
    required this.onBack,
    this.message,
    this.busy = false,
  });

  final VoidCallback onEnable;
  final VoidCallback onBack;
  final String? message;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return _WalletSecurityScaffold(
      title: 'Activate biometrics',
      icon: Icons.fingerprint_rounded,
      leading: BackButton(onPressed: busy ? null : onBack),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This device has enrolled biometrics, so biometric unlock is required for your wallet. Your wallet PIN remains available as fallback.',
            style: TextStyle(height: 1.45, fontWeight: FontWeight.w700),
          ),
          _SecurityError(message: message),
          const SizedBox(height: 18),
          _SecurityPrimaryButton(
            label: busy ? 'Opening biometric prompt...' : 'Enable biometrics',
            icon: Icons.fingerprint_rounded,
            onPressed: busy ? null : onEnable,
          ),
        ],
      ),
    );
  }
}

class WalletBiometricEnrollmentRequiredScreen extends StatelessWidget {
  const WalletBiometricEnrollmentRequiredScreen({
    super.key,
    required this.onOpenSettings,
    required this.onRecheck,
    required this.onCancel,
    this.message,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onRecheck;
  final VoidCallback onCancel;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return _WalletSecurityScaffold(
      title: 'Biometric enrollment required',
      icon: Icons.fingerprint_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your device reports biometric hardware, but no fingerprint or face unlock is enrolled. Enroll biometrics in device settings, then return here to finish wallet security.',
            style: TextStyle(height: 1.45, fontWeight: FontWeight.w700),
          ),
          _SecurityError(message: message),
          const SizedBox(height: 18),
          _SecurityPrimaryButton(
            label: 'Open device settings',
            icon: Icons.settings_outlined,
            onPressed: onOpenSettings,
          ),
          TextButton.icon(
            onPressed: onRecheck,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('I have enrolled biometrics'),
          ),
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class WalletUnlockScreen extends StatelessWidget {
  const WalletUnlockScreen({
    super.key,
    required this.mode,
    required this.controller,
    required this.onVerifyPin,
    required this.onCancel,
    this.onUseBiometric,
    this.message,
    this.busy = false,
  });

  final WalletSecurityMode mode;
  final TextEditingController controller;
  final VoidCallback onVerifyPin;
  final VoidCallback onCancel;
  final VoidCallback? onUseBiometric;
  final String? message;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final biometricEnabled = mode == WalletSecurityMode.biometricAndPin;
    return _WalletSecurityScaffold(
      title: 'Unlock wallet',
      icon: biometricEnabled ? Icons.fingerprint_rounded : Icons.lock_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            biometricEnabled
                ? 'Use biometrics or your wallet PIN to continue.'
                : 'Enter your wallet PIN to continue.',
            style: const TextStyle(height: 1.45, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          if (biometricEnabled)
            OutlinedButton.icon(
              onPressed: busy ? null : onUseBiometric,
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Use biometrics'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          if (biometricEnabled) const SizedBox(height: 12),
          _PinField(controller: controller, label: 'Wallet PIN'),
          _SecurityError(message: message),
          const SizedBox(height: 16),
          _SecurityPrimaryButton(
            label: busy ? 'Verifying...' : 'Unlock with PIN',
            icon: Icons.lock_open_rounded,
            onPressed: busy ? null : onVerifyPin,
          ),
          TextButton(
            onPressed: busy ? null : onCancel,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: busy ? null : () => _showForgotPinInfo(context),
            child: const Text('Forgot wallet PIN?'),
          ),
        ],
      ),
    );
  }

  void _showForgotPinInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Wallet PIN reset'),
        content: const Text(
          'For your protection, wallet PIN reset requires support verification. Please contact support. After your account is verified, sign in again and open My Wallet to create a new wallet PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _LoadingWalletSecurityScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const _WalletSecurityScaffold(
      title: 'Checking wallet security',
      icon: Icons.lock_outline,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _WalletSecurityScaffold extends StatelessWidget {
  const _WalletSecurityScaffold({
    required this.title,
    required this.icon,
    required this.child,
    this.leading,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA);
    final card = isDark ? const Color(0xFF102532) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF102532);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        leading: leading,
        title: const Text('Wallet security'),
        backgroundColor: const Color(0xFF0C2230),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: DefaultTextStyle(
                  style: TextStyle(color: text, fontSize: 15),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFFC857).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(icon, color: const Color(0xFFFFB522)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: TextStyle(
                          color: text,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: WalletPinPolicy.pinLength,
      autofillHints: const [],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(WalletPinPolicy.pinLength),
      ],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _SecurityPrimaryButton extends StatelessWidget {
  const _SecurityPrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFFB522),
          foregroundColor: MyColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _SecurityBullet extends StatelessWidget {
  const _SecurityBullet({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: const Color(0xFFFFB522)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.35, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityError extends StatelessWidget {
  const _SecurityError({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE53935),
          height: 1.35,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
