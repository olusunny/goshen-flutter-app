import 'package:churchapp_flutter/models/Userdata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps and persists every supported member profile field', () {
    final user = Userdata.fromJson({
      'activated': 0,
      'api_token': 'token',
      'title': 'Mrs.',
      'first_name': 'Grace',
      'middle_name': 'A.',
      'last_name': 'Member',
      'email': 'grace@example.test',
      'avatar': 'https://example.test/avatar.jpg',
      'cover_photo': 'https://example.test/cover.jpg',
      'gender': 'Female',
      'marital_status': 'Married',
      'group_id': 4,
      'group_name': 'Choir',
      'member_type': 'church_member',
      'country_of_residence': 'United Kingdom',
      'state_county_province': 'London',
      'address': '1 Goshen Way',
      'date_of_birth': '07-31',
      'phone': '+447700900000',
      'about_me': 'Serving with joy.',
      'is_adult_confirmed': true,
    });

    expect(user.profileTitle, 'Mrs.');
    expect(user.birthdayMonthDay, '07-31');
    expect(user.groupName, 'Choir');
    expect(user.isAdultConfirmed, isTrue);

    final restored = Userdata.fromMap(user.toMap());
    expect(restored.address, '1 Goshen Way');
    expect(restored.isAdultConfirmed, isTrue);
  });
}
