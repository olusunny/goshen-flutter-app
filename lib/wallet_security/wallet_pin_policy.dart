class WalletPinPolicy {
  static const int pinLength = 6;

  const WalletPinPolicy();

  String? validate(String pin) {
    if (pin.length != pinLength) {
      return 'Use a 6-digit wallet PIN.';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      return 'Wallet PIN must contain digits only.';
    }
    if (_allSameDigit(pin)) {
      return 'Choose a less predictable wallet PIN.';
    }
    if (_isSimpleSequence(pin)) {
      return 'Sequential PINs are too easy to guess.';
    }
    if (const {'000000', '111111', '123456', '654321'}.contains(pin)) {
      return 'Choose a less predictable wallet PIN.';
    }
    return null;
  }

  String? validateConfirmation(String pin, String confirmation) {
    final error = validate(pin);
    if (error != null) return error;
    if (pin != confirmation) {
      return 'Wallet PIN confirmation does not match.';
    }
    return null;
  }

  bool _allSameDigit(String pin) {
    return pin.split('').toSet().length == 1;
  }

  bool _isSimpleSequence(String pin) {
    final digits = pin.split('').map(int.parse).toList();
    final delta = digits[1] - digits[0];
    if (delta != 1 && delta != -1) return false;
    for (var index = 2; index < digits.length; index++) {
      if (digits[index] - digits[index - 1] != delta) return false;
    }
    return true;
  }
}
