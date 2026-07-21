bool isVisitorMemberType(String? memberType) {
  return memberType?.trim().toLowerCase() == 'visitor';
}

List<String> missingGoshenProfileFields({
  required String? memberType,
  required String? title,
  required String? name,
  required String? email,
  required String? phone,
  required String? gender,
  required String? maritalStatus,
  required String? countryOfResidence,
  required String? stateCountyProvince,
  required String? address,
}) {
  final checks = <String, String?>{
    'full name': name,
    'email address': email,
    'phone number': phone,
    'gender': gender,
    'church member or visitor status': memberType,
  };

  if (!isVisitorMemberType(memberType)) {
    checks.addAll({
      'title': title,
      'marital status': maritalStatus,
      'country of residence': countryOfResidence,
      'state/county/province': stateCountyProvince,
      'address': address,
    });
  }

  return checks.entries
      .where((entry) => (entry.value ?? '').trim().isEmpty)
      .map((entry) => entry.key)
      .toList();
}
