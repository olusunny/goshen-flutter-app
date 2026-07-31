import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile uses a free-text state, county, or province field', () async {
    final source =
        await File('lib/socials/UpdateUserProfile.dart').readAsString();

    expect(source, contains('stateCountyProvinceController'));
    expect(source, contains("label: 'State / county / province'"));
    expect(source, contains('stateCountyProvinceController.text.trim()'));
    expect(source, contains('"state_county_province": stateCountyProvince'));
    expect(source, isNot(contains('StateProvinceSelector(')));
  });
}
