import 'dart:convert';

dynamic decodeApiResponse(dynamic value) {
  if (value is String) {
    final trimmed = value.trimLeft();
    if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
      throw const FormatException(
        'The server returned a web page instead of app data. Please refresh and try again.',
      );
    }

    return jsonDecode(value);
  }

  return value;
}
