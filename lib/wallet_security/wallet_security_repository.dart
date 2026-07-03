import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'wallet_pin_hasher.dart';
import 'wallet_security_models.dart';

abstract class WalletSecurityRepository {
  Future<WalletSecurityConfig> readConfig();

  Future<void> saveConfig({
    required WalletSecurityMode mode,
    required WalletPinHashRecord pinRecord,
    required bool biometricEnabled,
    required DateTime now,
  });

  Future<void> clearConfig();

  Future<WalletPinFailureState> readFailureState();

  Future<void> saveFailureState(WalletPinFailureState state);

  Future<void> clearFailureState();
}

class FlutterSecureWalletSecurityRepository
    implements WalletSecurityRepository {
  FlutterSecureWalletSecurityRepository({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _modeKey = 'wallet_security_mode_v1';
  static const _pinHashKey = 'wallet_pin_hash_v1';
  static const _pinSaltKey = 'wallet_pin_salt_v1';
  static const _pinAlgorithmKey = 'wallet_pin_hash_algorithm_v1';
  static const _pinIterationsKey = 'wallet_pin_hash_iterations_v1';
  static const _biometricEnabledKey = 'wallet_biometric_enabled_v1';
  static const _failedAttemptsKey = 'wallet_pin_failed_attempts_v1';
  static const _lockedUntilKey = 'wallet_pin_locked_until_v1';
  static const _createdAtKey = 'wallet_security_created_at_v1';
  static const _updatedAtKey = 'wallet_security_updated_at_v1';

  @override
  Future<WalletSecurityConfig> readConfig() async {
    final mode =
        walletSecurityModeFromStorage(await _storage.read(key: _modeKey));
    final iterations = int.tryParse(
      await _storage.read(key: _pinIterationsKey) ?? '',
    );
    return WalletSecurityConfig(
      mode: mode,
      pinHash: await _storage.read(key: _pinHashKey),
      pinSalt: await _storage.read(key: _pinSaltKey),
      hashAlgorithm: await _storage.read(key: _pinAlgorithmKey),
      hashIterations: iterations,
      biometricEnabled:
          (await _storage.read(key: _biometricEnabledKey)) == 'true',
      createdAt:
          DateTime.tryParse(await _storage.read(key: _createdAtKey) ?? ''),
      updatedAt:
          DateTime.tryParse(await _storage.read(key: _updatedAtKey) ?? ''),
    );
  }

  @override
  Future<void> saveConfig({
    required WalletSecurityMode mode,
    required WalletPinHashRecord pinRecord,
    required bool biometricEnabled,
    required DateTime now,
  }) async {
    final existingCreatedAt = await _storage.read(key: _createdAtKey);
    await _storage.write(
      key: _modeKey,
      value: walletSecurityModeToStorage(mode),
    );
    await _storage.write(key: _pinHashKey, value: pinRecord.hash);
    await _storage.write(key: _pinSaltKey, value: pinRecord.salt);
    await _storage.write(key: _pinAlgorithmKey, value: pinRecord.algorithm);
    await _storage.write(
      key: _pinIterationsKey,
      value: pinRecord.iterations.toString(),
    );
    await _storage.write(
      key: _biometricEnabledKey,
      value: biometricEnabled.toString(),
    );
    await _storage.write(
      key: _createdAtKey,
      value: existingCreatedAt ?? now.toIso8601String(),
    );
    await _storage.write(key: _updatedAtKey, value: now.toIso8601String());
    await clearFailureState();
  }

  @override
  Future<void> clearConfig() async {
    await _storage.delete(key: _modeKey);
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _pinAlgorithmKey);
    await _storage.delete(key: _pinIterationsKey);
    await _storage.delete(key: _biometricEnabledKey);
    await _storage.delete(key: _createdAtKey);
    await _storage.delete(key: _updatedAtKey);
    await clearFailureState();
  }

  @override
  Future<WalletPinFailureState> readFailureState() async {
    return WalletPinFailureState(
      failedAttempts:
          int.tryParse(await _storage.read(key: _failedAttemptsKey) ?? '') ?? 0,
      lockedUntil: DateTime.tryParse(
        await _storage.read(key: _lockedUntilKey) ?? '',
      ),
    );
  }

  @override
  Future<void> saveFailureState(WalletPinFailureState state) async {
    await _storage.write(
      key: _failedAttemptsKey,
      value: state.failedAttempts.toString(),
    );
    final lockedUntil = state.lockedUntil;
    if (lockedUntil == null) {
      await _storage.delete(key: _lockedUntilKey);
    } else {
      await _storage.write(
        key: _lockedUntilKey,
        value: lockedUntil.toIso8601String(),
      );
    }
  }

  @override
  Future<void> clearFailureState() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockedUntilKey);
  }
}
