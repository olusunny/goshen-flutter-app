import 'package:churchapp_flutter/wallet_security/wallet_biometric_authenticator.dart';
import 'package:churchapp_flutter/wallet_security/wallet_pin_hasher.dart';
import 'package:churchapp_flutter/wallet_security/wallet_pin_policy.dart';
import 'package:churchapp_flutter/wallet_security/wallet_security_controller.dart';
import 'package:churchapp_flutter/wallet_security/wallet_security_guard.dart';
import 'package:churchapp_flutter/wallet_security/wallet_security_models.dart';
import 'package:churchapp_flutter/wallet_security/wallet_security_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletPinPolicy', () {
    const policy = WalletPinPolicy();

    test('accepts valid PIN and matching confirmation', () {
      expect(policy.validate('583920'), isNull);
      expect(policy.validateConfirmation('583920', '583920'), isNull);
    });

    test('rejects short, non-numeric, repeated, and sequential PINs', () {
      expect(policy.validate('12345'), isNotNull);
      expect(policy.validate('12a456'), isNotNull);
      expect(policy.validate('111111'), isNotNull);
      expect(policy.validate('123456'), isNotNull);
      expect(policy.validate('654321'), isNotNull);
    });

    test('rejects mismatched confirmation', () {
      expect(policy.validateConfirmation('583920', '583921'), isNotNull);
    });
  });

  group('WalletPinHasher', () {
    test('stores no raw PIN and verifies only the correct PIN', () {
      final hasher = WalletPinHasher(
        saltGenerator: (length) => List<int>.generate(length, (index) => index),
        iterations: 10,
      );

      final record = hasher.hashPin('583920');

      expect(record.hash, isNot(contains('583920')));
      expect(record.salt, isNot(contains('583920')));
      expect(
        hasher.verifyPin(
          pin: '583920',
          expectedHash: record.hash,
          salt: record.salt,
          iterations: record.iterations,
        ),
        isTrue,
      );
      expect(
        hasher.verifyPin(
          pin: '583921',
          expectedHash: record.hash,
          salt: record.salt,
          iterations: record.iterations,
        ),
        isFalse,
      );
    });

    test('uses a new salt for each hash', () {
      var counter = 0;
      final hasher = WalletPinHasher(
        saltGenerator: (length) => List<int>.filled(length, counter++),
        iterations: 10,
      );

      final first = hasher.hashPin('583920');
      final second = hasher.hashPin('583920');

      expect(first.salt, isNot(second.salt));
      expect(first.hash, isNot(second.hash));
    });

    test('constant-time comparison helper compares all bytes', () {
      expect(WalletPinHasher.constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(WalletPinHasher.constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
      expect(WalletPinHasher.constantTimeEquals([1, 2, 3], [1, 2]), isFalse);
    });
  });

  group('Wallet security policy', () {
    test('maps unsupported biometrics to PIN-only mode', () {
      expect(
        walletSecurityModeForAvailability(
            WalletBiometricAvailability.unsupported),
        WalletSecurityMode.pinOnly,
      );
    });

    test('maps enrolled biometrics to biometric-and-PIN mode', () {
      expect(
        walletSecurityModeForAvailability(
            WalletBiometricAvailability.available),
        WalletSecurityMode.biometricAndPin,
      );
    });

    test('requires enrollment when hardware exists without enrolled biometrics',
        () {
      expect(
        walletSecurityModeForAvailability(
            WalletBiometricAvailability.notEnrolled),
        isNull,
      );
    });
  });

  group('WalletSecurityController', () {
    test('configures PIN-only mode when biometrics are unsupported', () async {
      final repo = _MemoryWalletSecurityRepository();
      final controller = _testController(
        repo: repo,
        authenticator: _FakeBiometricAuthenticator(
          availability: WalletBiometricAvailability.unsupported,
        ),
      );

      final result = await controller.configureWalletSecurity('583920');
      final config = await repo.readConfig();

      expect(result, WalletUnlockResult.success);
      expect(config.mode, WalletSecurityMode.pinOnly);
      expect(controller.isWalletUnlocked, isTrue);
    });

    test('requires biometric activation when enrolled biometrics exist',
        () async {
      final repo = _MemoryWalletSecurityRepository();
      final auth = _FakeBiometricAuthenticator(
        availability: WalletBiometricAvailability.available,
        authResult: WalletUnlockResult.success,
      );
      final controller = _testController(repo: repo, authenticator: auth);

      final result = await controller.configureWalletSecurity('583920');
      final config = await repo.readConfig();

      expect(result, WalletUnlockResult.success);
      expect(config.mode, WalletSecurityMode.biometricAndPin);
      expect(config.biometricEnabled, isTrue);
      expect(auth.authenticateCalls, 1);
    });

    test('does not configure wallet when biometric enrollment is required',
        () async {
      final repo = _MemoryWalletSecurityRepository();
      final controller = _testController(
        repo: repo,
        authenticator: _FakeBiometricAuthenticator(
          availability: WalletBiometricAvailability.notEnrolled,
        ),
      );

      final result = await controller.configureWalletSecurity('583920');
      final config = await repo.readConfig();

      expect(result, WalletUnlockResult.biometricEnrollmentRequired);
      expect(config.mode, WalletSecurityMode.unconfigured);
    });

    test('verifies correct PIN, rejects incorrect PIN, and persists cooldown',
        () async {
      final repo = _MemoryWalletSecurityRepository();
      final clock = _MutableClock(DateTime(2026, 6, 29, 12));
      final controller = _testController(repo: repo, now: clock.now);
      await controller.configureWalletSecurity('583920');
      controller.lock();

      for (var index = 0; index < 4; index++) {
        final result = await controller.verifyPin('583921');
        expect(result.result, WalletUnlockResult.failed);
      }
      final locked = await controller.verifyPin('583921');
      expect(locked.result, WalletUnlockResult.lockedOut);

      final restartedController = _testController(repo: repo, now: clock.now);
      final stillLocked = await restartedController.verifyPin('583920');
      expect(stillLocked.result, WalletUnlockResult.lockedOut);

      clock.advance(const Duration(seconds: 31));
      final success = await restartedController.verifyPin('583920');
      expect(success.result, WalletUnlockResult.success);
    });

    test('locks after background timeout but not during normal navigation',
        () async {
      final repo = _MemoryWalletSecurityRepository();
      final clock = _MutableClock(DateTime(2026, 6, 29, 12));
      final controller = _testController(repo: repo, now: clock.now);
      await controller.configureWalletSecurity('583920');

      controller.handleLifecycleState(AppLifecycleState.paused);
      clock.advance(const Duration(minutes: 1));
      controller.handleLifecycleState(AppLifecycleState.resumed);
      expect(controller.isWalletUnlocked, isTrue);

      controller.handleLifecycleState(AppLifecycleState.paused);
      clock.advance(const Duration(minutes: 4));
      controller.handleLifecycleState(AppLifecycleState.resumed);
      expect(controller.isWalletUnlocked, isFalse);
    });

    test('fresh verification expires for transaction protection', () async {
      final repo = _MemoryWalletSecurityRepository();
      final clock = _MutableClock(DateTime(2026, 6, 29, 12));
      final controller = _testController(repo: repo, now: clock.now);
      await controller.configureWalletSecurity('583920');

      expect(controller.hasFreshVerification, isTrue);
      clock.advance(const Duration(seconds: 61));
      expect(controller.isWalletUnlocked, isTrue);
      expect(controller.hasFreshVerification, isFalse);

      final failed = await controller.verifyPin('583921');
      expect(failed.result, WalletUnlockResult.failed);
      expect(controller.hasFreshVerification, isFalse);

      final success = await controller.verifyPin('583920');
      expect(success.result, WalletUnlockResult.success);
      expect(controller.hasFreshVerification, isTrue);
    });

    test('admin-approved reset clears local wallet security config', () async {
      final repo = _MemoryWalletSecurityRepository();
      final controller = _testController(repo: repo);
      await controller.configureWalletSecurity('583920');

      await controller.resetWalletSecurity();
      final config = await repo.readConfig();

      expect(config.mode, WalletSecurityMode.unconfigured);
      expect(config.pinHash, isNull);
      expect(controller.isWalletUnlocked, isFalse);
    });
  });

  group('Wallet route guard', () {
    test('does not gate non-wallet routes', () {
      expect(WalletSecurityGuard.isWalletRoute('/home'), isFalse);
    });

    test('identifies wallet routes', () {
      expect(WalletSecurityGuard.isWalletRoute('/goshen-wallet'), isTrue);
      expect(
        WalletSecurityGuard.isWalletRoute('/goshen-wallet-transfer'),
        isTrue,
      );
    });
  });
}

WalletSecurityController _testController({
  required _MemoryWalletSecurityRepository repo,
  _FakeBiometricAuthenticator? authenticator,
  DateTime Function()? now,
}) {
  return WalletSecurityController(
    repository: repo,
    biometricAuthenticator: authenticator ?? _FakeBiometricAuthenticator(),
    pinHasher: WalletPinHasher(
      saltGenerator: (length) => List<int>.generate(length, (index) => index),
      iterations: 10,
    ),
    now: now,
    listenForLogout: false,
  );
}

class _MemoryWalletSecurityRepository implements WalletSecurityRepository {
  WalletSecurityConfig _config =
      const WalletSecurityConfig(mode: WalletSecurityMode.unconfigured);
  WalletPinFailureState _failureState = const WalletPinFailureState();

  @override
  Future<void> clearFailureState() async {
    _failureState = const WalletPinFailureState();
  }

  @override
  Future<void> clearConfig() async {
    _config = const WalletSecurityConfig(mode: WalletSecurityMode.unconfigured);
    await clearFailureState();
  }

  @override
  Future<WalletSecurityConfig> readConfig() async => _config;

  @override
  Future<WalletPinFailureState> readFailureState() async => _failureState;

  @override
  Future<void> saveConfig({
    required WalletSecurityMode mode,
    required WalletPinHashRecord pinRecord,
    required bool biometricEnabled,
    required DateTime now,
  }) async {
    _config = WalletSecurityConfig(
      mode: mode,
      pinHash: pinRecord.hash,
      pinSalt: pinRecord.salt,
      hashAlgorithm: pinRecord.algorithm,
      hashIterations: pinRecord.iterations,
      biometricEnabled: biometricEnabled,
      createdAt: now,
      updatedAt: now,
    );
    await clearFailureState();
  }

  @override
  Future<void> saveFailureState(WalletPinFailureState state) async {
    _failureState = state;
  }
}

class _FakeBiometricAuthenticator implements WalletBiometricAuthenticator {
  _FakeBiometricAuthenticator({
    this.availability = WalletBiometricAvailability.unsupported,
    this.authResult = WalletUnlockResult.success,
  });

  WalletBiometricAvailability availability;
  WalletUnlockResult authResult;
  int authenticateCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<WalletUnlockResult> authenticate({required String reason}) async {
    authenticateCalls++;
    return authResult;
  }

  @override
  Future<WalletBiometricAvailability> checkAvailability() async => availability;

  @override
  Future<void> openEnrollmentSettings() async {
    openSettingsCalls++;
  }
}

class _MutableClock {
  _MutableClock(this.value);

  DateTime value;

  DateTime now() => value;

  void advance(Duration duration) {
    value = value.add(duration);
  }
}
