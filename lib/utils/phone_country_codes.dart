import 'dart:ui' as ui;

const Map<String, String> _countryDialCodes = {
  'GB': '+44',
  'NG': '+234',
  'US': '+1',
  'CA': '+1',
  'IE': '+353',
  'GH': '+233',
  'ZA': '+27',
  'KE': '+254',
  'UG': '+256',
  'TZ': '+255',
  'RW': '+250',
  'ZM': '+260',
  'ZW': '+263',
  'FR': '+33',
  'DE': '+49',
  'IT': '+39',
  'ES': '+34',
  'NL': '+31',
  'BE': '+32',
  'SE': '+46',
  'NO': '+47',
  'DK': '+45',
  'FI': '+358',
  'AU': '+61',
  'NZ': '+64',
};

String defaultDialCode() {
  final countryCode =
      ui.PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
  if (countryCode != null && _countryDialCodes.containsKey(countryCode)) {
    return _countryDialCodes[countryCode]!;
  }

  return '+44';
}

String normalizeDialCode(String value) {
  final digits = value.replaceAll(RegExp(r'\D+'), '');
  if (digits.isEmpty) return defaultDialCode();
  return '+$digits';
}

String toE164Phone(String dialCode, String phone) {
  final normalizedDialCode = normalizeDialCode(dialCode);
  var digits = phone.replaceAll(RegExp(r'\D+'), '');

  if (digits.startsWith('00')) {
    digits = digits.substring(2);
    return '+$digits';
  }

  if (phone.trim().startsWith('+')) {
    return '+$digits';
  }

  while (digits.startsWith('0')) {
    digits = digits.substring(1);
  }

  return '$normalizedDialCode$digits';
}

bool looksLikeE164(String value) {
  return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value.trim());
}
