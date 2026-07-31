import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'profile saves authenticate multipart updates and explain expired sessions',
      () async {
    final source =
        await File('lib/socials/UpdateUserProfile.dart').readAsString();

    expect(source, contains('"api_token": apiToken'));
    expect(source, contains("'Authorization': 'Bearer \$apiToken'"));
    expect(source, contains('response.statusCode == 401'));
    expect(source, contains('Your session has expired. Please sign in again'));
  });
}
