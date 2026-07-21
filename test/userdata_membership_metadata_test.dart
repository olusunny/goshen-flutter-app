import 'package:churchapp_flutter/models/Userdata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('membership metadata round-trips through API and local storage maps',
      () {
    final user = Userdata.fromJson({
      'activated': 0,
      'member_type': 'visitor',
      'birthday_month_day': '07-21',
      'member_type_editable_at': '2026-08-20T09:30:00Z',
    });

    expect(user.birthdayMonthDay, '07-21');
    expect(user.memberTypeEditableAt, '2026-08-20T09:30:00Z');

    final restored = Userdata.fromMap(user.toMap());
    expect(restored.birthdayMonthDay, '07-21');
    expect(restored.memberTypeEditableAt, '2026-08-20T09:30:00Z');
  });
}
