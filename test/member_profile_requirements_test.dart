import 'package:flutter_test/flutter_test.dart';
import 'package:churchapp_flutter/utils/member_profile_requirements.dart';

void main() {
  test('visitor membership is recognized without case sensitivity', () {
    expect(isVisitorMemberType(' visitor '), isTrue);
    expect(isVisitorMemberType('church_member'), isFalse);
  });

  test(
      'visitor Goshen registration needs contact details but not member profile fields',
      () {
    expect(
      missingGoshenProfileFields(
        memberType: 'visitor',
        title: '',
        name: 'Guest Visitor',
        email: 'guest@example.test',
        phone: '+2348000000000',
        gender: 'Female',
        maritalStatus: '',
        countryOfResidence: '',
        stateCountyProvince: '',
        address: '',
      ),
      isEmpty,
    );
  });

  test('church members still need the complete member profile for Goshen', () {
    expect(
      missingGoshenProfileFields(
        memberType: 'church_member',
        title: '',
        name: 'Church Member',
        email: 'member@example.test',
        phone: '+2348000000000',
        gender: 'Male',
        maritalStatus: '',
        countryOfResidence: '',
        stateCountyProvince: '',
        address: '',
      ),
      containsAll(<String>[
        'title',
        'marital status',
        'country of residence',
        'state/county/province',
        'address',
      ]),
    );
  });
}
