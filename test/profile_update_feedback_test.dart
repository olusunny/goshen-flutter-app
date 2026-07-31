import 'package:churchapp_flutter/utils/profile_update_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the first field validation error from the profile API', () {
    expect(
      profileUpdateErrorMessage({
        'errors': {
          'birthday': ['Choose your birthday month and day before saving.'],
        },
      }, statusCode: 422),
      'Choose your birthday month and day before saving.',
    );
  });

  test('explains an expired profile session', () {
    expect(
      profileUpdateErrorMessage({}, statusCode: 401),
      contains('session has expired'),
    );
  });
}
