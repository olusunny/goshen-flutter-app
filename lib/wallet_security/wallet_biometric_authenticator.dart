import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import 'wallet_security_models.dart';

abstract class WalletBiometricAuthenticator {
  Future<WalletBiometricAvailability> checkAvailability();

  Future<WalletUnlockResult> authenticate({
    required String reason,
  });

  Future<void> openEnrollmentSettings();
}

class LocalAuthWalletBiometricAuthenticator
    implements WalletBiometricAuthenticator {
  LocalAuthWalletBiometricAuthenticator({
    LocalAuthentication? localAuthentication,
  }) : _localAuth = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<WalletBiometricAvailability> checkAvailability() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final enrolled = await _localAuth.getAvailableBiometrics();
      if (enrolled.isNotEmpty) return WalletBiometricAvailability.available;
      if (supported || canCheck) return WalletBiometricAvailability.notEnrolled;
      return WalletBiometricAvailability.unsupported;
    } on PlatformException catch (error) {
      if (error.code == auth_error.notEnrolled) {
        return WalletBiometricAvailability.notEnrolled;
      }
      if (error.code == auth_error.notAvailable) {
        return WalletBiometricAvailability.hardwareUnavailable;
      }
      return WalletBiometricAvailability.hardwareUnavailable;
    }
  }

  @override
  Future<WalletUnlockResult> authenticate({
    required String reason,
  }) async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: false,
        ),
      );
      return didAuthenticate
          ? WalletUnlockResult.success
          : WalletUnlockResult.cancelled;
    } on PlatformException catch (error) {
      if (error.code == auth_error.notEnrolled) {
        return WalletUnlockResult.biometricEnrollmentRequired;
      }
      if (error.code == auth_error.lockedOut ||
          error.code == auth_error.permanentlyLockedOut) {
        return WalletUnlockResult.lockedOut;
      }
      if (error.code == auth_error.notAvailable ||
          error.code == auth_error.passcodeNotSet) {
        return WalletUnlockResult.failed;
      }
      return WalletUnlockResult.cancelled;
    }
  }

  @override
  Future<void> openEnrollmentSettings() async {
    await openAppSettings();
  }
}
