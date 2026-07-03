enum WalletBiometricAvailability {
  unsupported,
  hardwareUnavailable,
  notEnrolled,
  available,
}

enum WalletSecurityMode {
  unconfigured,
  pinOnly,
  biometricAndPin,
}

enum WalletUnlockResult {
  success,
  cancelled,
  failed,
  lockedOut,
  setupRequired,
  biometricEnrollmentRequired,
}

class WalletSecurityConfig {
  const WalletSecurityConfig({
    required this.mode,
    this.pinHash,
    this.pinSalt,
    this.hashAlgorithm,
    this.hashIterations,
    this.biometricEnabled = false,
    this.createdAt,
    this.updatedAt,
  });

  final WalletSecurityMode mode;
  final String? pinHash;
  final String? pinSalt;
  final String? hashAlgorithm;
  final int? hashIterations;
  final bool biometricEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isConfigured =>
      mode != WalletSecurityMode.unconfigured &&
      pinHash != null &&
      pinSalt != null &&
      hashAlgorithm != null &&
      hashIterations != null;
}

class WalletPinFailureState {
  const WalletPinFailureState({
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  final int failedAttempts;
  final DateTime? lockedUntil;

  bool isLocked(DateTime now) {
    final until = lockedUntil;
    return until != null && now.isBefore(until);
  }
}

class WalletPinVerification {
  const WalletPinVerification({
    required this.result,
    this.failedAttempts = 0,
    this.lockedUntil,
    this.message,
  });

  final WalletUnlockResult result;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final String? message;

  bool get isSuccess => result == WalletUnlockResult.success;
}

class WalletSecurityException implements Exception {
  const WalletSecurityException(this.result, this.message);

  final WalletUnlockResult result;
  final String message;

  @override
  String toString() => message;
}

WalletSecurityMode? walletSecurityModeForAvailability(
  WalletBiometricAvailability availability,
) {
  switch (availability) {
    case WalletBiometricAvailability.available:
      return WalletSecurityMode.biometricAndPin;
    case WalletBiometricAvailability.unsupported:
    case WalletBiometricAvailability.hardwareUnavailable:
      return WalletSecurityMode.pinOnly;
    case WalletBiometricAvailability.notEnrolled:
      return null;
  }
}

WalletSecurityMode walletSecurityModeFromStorage(String? value) {
  switch (value) {
    case 'pinOnly':
      return WalletSecurityMode.pinOnly;
    case 'biometricAndPin':
      return WalletSecurityMode.biometricAndPin;
    default:
      return WalletSecurityMode.unconfigured;
  }
}

String walletSecurityModeToStorage(WalletSecurityMode mode) {
  switch (mode) {
    case WalletSecurityMode.unconfigured:
      return 'unconfigured';
    case WalletSecurityMode.pinOnly:
      return 'pinOnly';
    case WalletSecurityMode.biometricAndPin:
      return 'biometricAndPin';
  }
}
