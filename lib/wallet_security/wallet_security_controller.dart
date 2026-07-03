import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../providers/events.dart';
import 'wallet_biometric_authenticator.dart';
import 'wallet_pin_hasher.dart';
import 'wallet_pin_policy.dart';
import 'wallet_security_models.dart';
import 'wallet_security_repository.dart';

class WalletSecurityController extends ChangeNotifier {
  WalletSecurityController({
    WalletSecurityRepository? repository,
    WalletBiometricAuthenticator? biometricAuthenticator,
    WalletPinHasher? pinHasher,
    DateTime Function()? now,
    this.sessionTimeout = const Duration(minutes: 3),
    this.freshVerificationTimeout = const Duration(seconds: 60),
    bool listenForLogout = true,
  })  : _repository = repository ?? FlutterSecureWalletSecurityRepository(),
        _biometricAuthenticator =
            biometricAuthenticator ?? LocalAuthWalletBiometricAuthenticator(),
        _pinHasher = pinHasher ?? WalletPinHasher(),
        _now = now ?? DateTime.now {
    if (listenForLogout) {
      _eventSubscription = eventBus.on().listen((event) {
        if (event == AppEvents.LOGOUT) {
          lock();
        }
      });
    }
  }

  final WalletSecurityRepository _repository;
  final WalletBiometricAuthenticator _biometricAuthenticator;
  final WalletPinHasher _pinHasher;
  final DateTime Function() _now;
  final Duration sessionTimeout;
  final Duration freshVerificationTimeout;

  StreamSubscription<dynamic>? _eventSubscription;
  WalletSecurityConfig _config =
      const WalletSecurityConfig(mode: WalletSecurityMode.unconfigured);
  bool _loaded = false;
  DateTime? _unlockedAt;
  DateTime? _lastFreshVerificationAt;
  DateTime? _backgroundedAt;

  WalletSecurityMode get mode => _config.mode;

  bool get isLoaded => _loaded;

  bool get isWalletUnlocked {
    final unlockedAt = _unlockedAt;
    return unlockedAt != null &&
        _now().difference(unlockedAt) <= sessionTimeout;
  }

  bool get hasFreshVerification {
    final verifiedAt = _lastFreshVerificationAt;
    return isWalletUnlocked &&
        verifiedAt != null &&
        _now().difference(verifiedAt) <= freshVerificationTimeout;
  }

  Future<WalletSecurityConfig> load() async {
    _config = await _repository.readConfig();
    if (!_config.isConfigured) {
      _config = const WalletSecurityConfig(
        mode: WalletSecurityMode.unconfigured,
      );
    }
    _loaded = true;
    notifyListeners();
    return _config;
  }

  Future<WalletBiometricAvailability> biometricAvailability() {
    return _biometricAuthenticator.checkAvailability();
  }

  Future<WalletUnlockResult> configureWalletSecurity(String pin) async {
    if (const WalletPinPolicy().validate(pin) != null) {
      return WalletUnlockResult.failed;
    }
    final availability = await _biometricAuthenticator.checkAvailability();
    final selectedMode = walletSecurityModeForAvailability(availability);
    if (selectedMode == null) {
      return WalletUnlockResult.biometricEnrollmentRequired;
    }

    if (selectedMode == WalletSecurityMode.biometricAndPin) {
      final biometricResult = await _biometricAuthenticator.authenticate(
        reason: 'Use biometrics to activate secure wallet access.',
      );
      if (biometricResult != WalletUnlockResult.success) {
        return biometricResult;
      }
    }

    final now = _now();
    final pinRecord = _pinHasher.hashPin(pin);
    await _repository.saveConfig(
      mode: selectedMode,
      pinRecord: pinRecord,
      biometricEnabled: selectedMode == WalletSecurityMode.biometricAndPin,
      now: now,
    );
    _config = await _repository.readConfig();
    _createSession(now);
    _loaded = true;
    notifyListeners();
    return WalletUnlockResult.success;
  }

  Future<void> resetWalletSecurity() async {
    await _repository.clearConfig();
    _config = const WalletSecurityConfig(mode: WalletSecurityMode.unconfigured);
    _loaded = true;
    _unlockedAt = null;
    _lastFreshVerificationAt = null;
    notifyListeners();
  }

  Future<WalletUnlockResult> unlockWithBiometrics() async {
    await _ensureLoaded();
    if (_config.mode == WalletSecurityMode.unconfigured) {
      return WalletUnlockResult.setupRequired;
    }
    if (_config.mode != WalletSecurityMode.biometricAndPin) {
      return WalletUnlockResult.failed;
    }

    final result = await _biometricAuthenticator.authenticate(
      reason: 'Use biometrics to unlock your wallet.',
    );
    if (result == WalletUnlockResult.success) {
      _createSession(_now());
      notifyListeners();
    }
    return result;
  }

  Future<WalletPinVerification> verifyPin(String pin) async {
    await _ensureLoaded();
    if (_config.mode == WalletSecurityMode.unconfigured) {
      return const WalletPinVerification(
        result: WalletUnlockResult.setupRequired,
        message: 'Set up wallet security first.',
      );
    }

    final now = _now();
    final failureState = await _repository.readFailureState();
    if (failureState.isLocked(now)) {
      return WalletPinVerification(
        result: WalletUnlockResult.lockedOut,
        failedAttempts: failureState.failedAttempts,
        lockedUntil: failureState.lockedUntil,
        message: 'Wallet PIN is temporarily locked. Try again shortly.',
      );
    }

    final hash = _config.pinHash;
    final salt = _config.pinSalt;
    final iterations = _config.hashIterations;
    if (hash == null ||
        salt == null ||
        iterations == null ||
        _config.hashAlgorithm != WalletPinHasher.algorithm) {
      lock();
      return const WalletPinVerification(
        result: WalletUnlockResult.setupRequired,
        message: 'Wallet security needs to be set up again.',
      );
    }

    final verified = _pinHasher.verifyPin(
      pin: pin,
      expectedHash: hash,
      salt: salt,
      iterations: iterations,
    );
    if (verified) {
      await _repository.clearFailureState();
      _createSession(now);
      notifyListeners();
      return const WalletPinVerification(result: WalletUnlockResult.success);
    }

    final nextFailures = failureState.failedAttempts + 1;
    final lockedUntil =
        nextFailures >= 5 ? now.add(_cooldownForFailures(nextFailures)) : null;
    final updatedState = WalletPinFailureState(
      failedAttempts: nextFailures,
      lockedUntil: lockedUntil,
    );
    await _repository.saveFailureState(updatedState);
    return WalletPinVerification(
      result: lockedUntil == null
          ? WalletUnlockResult.failed
          : WalletUnlockResult.lockedOut,
      failedAttempts: nextFailures,
      lockedUntil: lockedUntil,
      message: lockedUntil == null
          ? 'Incorrect wallet PIN.'
          : 'Too many incorrect PIN attempts. Try again shortly.',
    );
  }

  void lock() {
    _unlockedAt = null;
    _lastFreshVerificationAt = null;
    notifyListeners();
  }

  void handleLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= _now();
        break;
      case AppLifecycleState.detached:
        lock();
        break;
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt != null &&
            _now().difference(backgroundedAt) > sessionTimeout) {
          lock();
        }
        break;
    }
  }

  Future<void> openBiometricEnrollmentSettings() {
    return _biometricAuthenticator.openEnrollmentSettings();
  }

  Future<void> _ensureLoaded() async {
    if (!_loaded) await load();
  }

  void _createSession(DateTime now) {
    _unlockedAt = now;
    _lastFreshVerificationAt = now;
  }

  Duration _cooldownForFailures(int failedAttempts) {
    final exponent = max(0, failedAttempts - 5);
    final seconds = min(300, 30 * pow(2, exponent).toInt());
    return Duration(seconds: seconds);
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
