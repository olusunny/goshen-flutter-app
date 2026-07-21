import 'package:churchapp_flutter/utils/member_profile_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visitor Triumphant ID status explains why no ID is shown', () {
    expect(
      triumphantIdStatusMessage(memberType: 'visitor', triumphantId: ''),
      'You are registered as a visitor',
    );
    expect(
      triumphantIdStatusDetail(memberType: 'visitor', triumphantId: ''),
      contains('Visitors do not receive a Triumphant ID'),
    );
  });

  test('membership status uses the supplied server cooldown', () {
    final now = DateTime(2026, 7, 21, 10);
    expect(
      isMembershipStatusLocked('2026-08-01T10:00:00Z', now: now),
      isTrue,
    );
    expect(
      membershipStatusLockMessage('2026-08-01T10:00:00Z', now: now),
      contains('01 August'),
    );
  });

  test('birthday keeps only a valid date and month', () {
    expect(normalizeBirthdayMonthDay('1994-07-21'), '07-21');
    expect(normalizeBirthdayMonthDay('02-29'), '02-29');
    expect(normalizeBirthdayMonthDay('02-30'), isEmpty);
    expect(formatBirthdayMonthDay('07-21'), '21 July');
  });
}
