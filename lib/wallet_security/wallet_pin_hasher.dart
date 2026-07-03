import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class WalletPinHashRecord {
  const WalletPinHashRecord({
    required this.hash,
    required this.salt,
    required this.algorithm,
    required this.iterations,
  });

  final String hash;
  final String salt;
  final String algorithm;
  final int iterations;
}

typedef SecureSaltGenerator = List<int> Function(int length);

class WalletPinHasher {
  WalletPinHasher({
    SecureSaltGenerator? saltGenerator,
    this.iterations = defaultIterations,
    this.keyLength = 32,
  }) : _saltGenerator = saltGenerator ?? _secureSalt;

  static const int defaultIterations = 150000;
  static const String algorithm = 'PBKDF2-HMAC-SHA256';

  final SecureSaltGenerator _saltGenerator;
  final int iterations;
  final int keyLength;

  WalletPinHashRecord hashPin(String pin) {
    final salt = _saltGenerator(16);
    final hash = _pbkdf2(
      password: utf8.encode(pin),
      salt: salt,
      iterations: iterations,
      keyLength: keyLength,
    );
    return WalletPinHashRecord(
      hash: base64Encode(hash),
      salt: base64Encode(salt),
      algorithm: algorithm,
      iterations: iterations,
    );
  }

  bool verifyPin({
    required String pin,
    required String expectedHash,
    required String salt,
    required int iterations,
  }) {
    final computed = _pbkdf2(
      password: utf8.encode(pin),
      salt: base64Decode(salt),
      iterations: iterations,
      keyLength: base64Decode(expectedHash).length,
    );
    return constantTimeEquals(computed, base64Decode(expectedHash));
  }

  static bool constantTimeEquals(List<int> left, List<int> right) {
    final maxLength = max(left.length, right.length);
    var diff = left.length ^ right.length;
    for (var index = 0; index < maxLength; index++) {
      final leftByte = index < left.length ? left[index] : 0;
      final rightByte = index < right.length ? right[index] : 0;
      diff |= leftByte ^ rightByte;
    }
    return diff == 0;
  }

  static List<int> _secureSalt(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static List<int> _pbkdf2({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, password);
    final blockCount =
        (keyLength / sha256.convert(const []).bytes.length).ceil();
    final derived = BytesBuilder(copy: false);

    for (var block = 1; block <= blockCount; block++) {
      var u = hmac.convert([...salt, ..._int32BigEndian(block)]).bytes;
      final output = Uint8List.fromList(u);
      for (var round = 1; round < iterations; round++) {
        u = hmac.convert(u).bytes;
        for (var index = 0; index < output.length; index++) {
          output[index] ^= u[index];
        }
      }
      derived.add(output);
    }

    return derived.takeBytes().take(keyLength).toList(growable: false);
  }

  static List<int> _int32BigEndian(int value) {
    return [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }
}
