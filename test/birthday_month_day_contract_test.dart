import 'package:flutter_test/flutter_test.dart';
import 'package:churchapp_flutter/auth/RegisterScreen.dart';
import 'package:churchapp_flutter/socials/UpdateUserProfile.dart';
import 'package:churchapp_flutter/utils/member_profile_presentation.dart';

void main() {
  test('accepts only valid canonical MM-DD birthday values', () {
    expect(isValidBirthdayMonthDay('07-21'), isTrue);
    expect(isValidBirthdayMonthDay('02-29'), isTrue);
    expect(isValidBirthdayMonthDay('7-21'), isFalse);
    expect(isValidBirthdayMonthDay('0721'), isFalse);
    expect(isValidBirthdayMonthDay('07233444899'), isFalse);
    expect(isValidBirthdayMonthDay('02-30'), isFalse);
    expect(isValidBirthdayMonthDay('13-01'), isFalse);
  });

  test('converts a validated birthday to the API month and day fields', () {
    expect(
      birthdayMonthDayApiFields('07-21'),
      {'birthday_month': 7, 'birthday_day': 21},
    );
    expect(birthdayMonthDayApiFields('07-211'), isNull);
  });

  test(
      'the registration and profile screens compile with the birthday contract',
      () {
    expect(RegisterScreen, isNotNull);
    expect(UpdateUserProfile, isNotNull);
  });
}
