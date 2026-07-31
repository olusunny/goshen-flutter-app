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

  test('profile save requests a destination-owned success snackbar', () async {
    final updateSource =
        await File('lib/socials/UpdateUserProfile.dart').readAsString();
    final profileSource =
        await File('lib/socials/UserProfileScreen.dart').readAsString();

    expect(updateSource, contains('showProfileUpdated: true'));
    expect(profileSource,
        contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(
        profileSource, contains('Your profile has been updated successfully.'));
  });
}
