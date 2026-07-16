class Userdata {
  String? profileTitle = "", maritalStatus = "";
  String? firstName = "", middleName = "", lastName = "";
  String? email = "";
  String? name = "";
  String? triumphantId = "";
  String? avatar = "", coverPhoto = "", gender = "";
  String? dateOfBirth = "",
      phone = "",
      countryOfResidence = "",
      stateCountyProvince = "",
      memberType = "",
      address = "",
      addressLatitude = "",
      addressLongitude = "",
      aboutMe = "",
      location = "",
      qualification = "",
      facebook = "",
      twitter = "",
      linkdln = "";
  String? role = "";
  int? groupId;
  String? groupName = "";
  int? activated = 1;
  String? apiToken = "";
  List<String> roles = [];
  bool isGo = false;
  bool canManageGroups = false;
  bool canManageGoshenRegistration = false;
  bool canManageGoshenVouchers = false;
  bool canManageQuiz = false;
  bool canManageFundraising = false;
  bool canManageWalletWithdrawals = false;
  bool canManageDynamicForms = false;
  bool canManageChurchEvents = false;
  bool canManageVerseOfDay = false;
  bool canManageCounseling = false;
  bool hasPropheticDecreePermission = false;
  bool canSendAdminMessages = false;
  bool following = false;

  static const String TABLE = "userdata";
  static final columns = [
    "firstName",
    "profileTitle",
    "maritalStatus",
    "middleName",
    "lastName",
    "email",
    "name",
    "triumphantId",
    "coverPhoto",
    "avatar",
    "gender",
    "groupId",
    "groupName",
    "dateOfBirth",
    "phone",
    "countryOfResidence",
    "stateCountyProvince",
    "memberType",
    "address",
    "addressLatitude",
    "addressLongitude",
    "aboutMe",
    "location",
    "qualification",
    "facebook",
    "twitter",
    "linkdln",
    "role",
    "apiToken",
    "roles",
    "isGo",
    "canManageGroups",
    "canManageGoshenRegistration",
    "canManageGoshenVouchers",
    "canManageQuiz",
    "canManageFundraising",
    "canManageWalletWithdrawals",
    "canManageDynamicForms",
    "canManageChurchEvents",
    "canManageVerseOfDay",
    "canManageCounseling",
    "canManagePropheticDecree",
    "canSendAdminMessages",
    "activated"
  ];

  Userdata({
    this.firstName,
    this.profileTitle,
    this.maritalStatus,
    this.middleName,
    this.lastName,
    this.email,
    this.name,
    this.triumphantId,
    this.coverPhoto,
    this.avatar,
    this.gender,
    this.dateOfBirth,
    this.phone,
    this.countryOfResidence,
    this.stateCountyProvince,
    this.memberType,
    this.address,
    this.addressLatitude,
    this.addressLongitude,
    this.aboutMe,
    this.location,
    this.qualification,
    this.facebook,
    this.twitter,
    this.linkdln,
    this.role,
    this.groupId,
    this.groupName,
    this.activated,
    this.apiToken,
    List<String>? roles,
    this.isGo = false,
    this.canManageGroups = false,
    this.canManageGoshenRegistration = false,
    this.canManageGoshenVouchers = false,
    this.canManageQuiz = false,
    this.canManageFundraising = false,
    this.canManageWalletWithdrawals = false,
    this.canManageDynamicForms = false,
    this.canManageChurchEvents = false,
    this.canManageVerseOfDay = false,
    this.canManageCounseling = false,
    this.hasPropheticDecreePermission = false,
    this.canSendAdminMessages = false,
    this.following = false,
  }) : roles = roles ?? [];

  factory Userdata.fromJson(Map<String, dynamic> json) {
    print(json['avatar'].toString());
    final activated = _readActivationState(json['activated']);
    //print(json);
    return Userdata(
        firstName: json['first_name'] as String?,
        profileTitle: _readString(json,
            const ['profile_title', 'profileTitle', 'salutation', 'title']),
        maritalStatus:
            _readString(json, const ['marital_status', 'maritalStatus']),
        middleName: json['middle_name'] as String?,
        lastName: json['last_name'] as String?,
        name: json['name'] as String?,
        email: json['email'] as String?,
        triumphantId:
            _readString(json, const ['triumphant_id', 'triumphantId']),
        avatar: activated == 1 ? "" : json['avatar'] as String?,
        coverPhoto: activated == 1 ? "" : json['cover_photo'] as String?,
        gender: activated == 1 ? "" : json['gender'] as String?,
        groupId: activated == 1 ? null : _readInt(json['group_id']),
        groupName: activated == 1 ? "" : json['group_name'] as String?,
        dateOfBirth: activated == 1 ? "" : json['date_of_birth'] as String?,
        phone: activated == 1 ? "" : json['phone'] as String?,
        countryOfResidence:
            activated == 1 ? "" : json['country_of_residence'] as String?,
        stateCountyProvince:
            activated == 1 ? "" : json['state_county_province'] as String?,
        memberType: activated == 1 ? "" : json['member_type'] as String?,
        address: activated == 1 ? "" : json['address'] as String?,
        addressLatitude:
            activated == 1 ? "" : json['address_latitude']?.toString(),
        addressLongitude:
            activated == 1 ? "" : json['address_longitude']?.toString(),
        aboutMe: activated == 1 ? "" : json['about_me'] as String?,
        location: activated == 1 ? "" : json['location'] as String?,
        qualification: activated == 1 ? "" : json['qualification'] as String?,
        facebook: activated == 1 ? "" : json['facebook'] as String?,
        twitter: activated == 1 ? "" : json['twitter'] as String?,
        linkdln: activated == 1 ? "" : json['linkdln'] as String?,
        role: _readRole(json),
        apiToken: json['api_token'] as String?,
        roles: _readRoles(json),
        isGo: _readBool(json['is_go']),
        canManageGroups: _readBool(json['can_manage_groups']),
        canManageGoshenRegistration: _readBool(
          json['can_manage_goshen_registration'] ??
              json['canManageGoshenRegistration'],
        ),
        canManageGoshenVouchers: _readBool(
          json['can_manage_goshen_vouchers'] ?? json['canManageGoshenVouchers'],
        ),
        canManageQuiz: _readBool(
          json['can_manage_goshen_quiz'] ?? json['canManageQuiz'],
        ),
        canManageFundraising: _readBool(
          json['can_manage_fundraising'] ?? json['canManageFundraising'],
        ),
        canManageWalletWithdrawals: _readBool(
          json['can_manage_wallet_withdrawals'] ??
              json['canManageWalletWithdrawals'],
        ),
        canManageDynamicForms: _readBool(
          json['can_manage_dynamic_forms'] ?? json['canManageDynamicForms'],
        ),
        canManageChurchEvents: _readBool(
          json['can_manage_church_events'] ?? json['canManageChurchEvents'],
        ),
        canManageVerseOfDay: _readBool(
          json['can_manage_verse_of_day'] ?? json['canManageVerseOfDay'],
        ),
        canManageCounseling: _readBool(
          json['can_manage_counseling'] ?? json['canManageCounseling'],
        ),
        hasPropheticDecreePermission: _readBool(
          json['can_manage_prophetic_decree'] ??
              json['canManagePropheticDecree'],
        ),
        canSendAdminMessages: _readBool(
          json['can_send_admin_messages'] ?? json['canSendAdminMessages'],
        ),
        activated: activated);
  }

  factory Userdata.fromFCMJson(Map<String, dynamic> json) {
    print(json['avatar'].toString());
    //print(json);
    return Userdata(
      firstName: json['first_name'] as String?,
      profileTitle: _readString(
          json, const ['profile_title', 'profileTitle', 'salutation', 'title']),
      maritalStatus:
          _readString(json, const ['marital_status', 'maritalStatus']),
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      triumphantId: _readString(json, const ['triumphant_id', 'triumphantId']),
      avatar: json['avatar'] as String?,
      coverPhoto: json['cover_photo'] as String?,
      gender: "",
      groupId: _readInt(json['group_id']),
      groupName: json['group_name'] as String?,
      dateOfBirth: "",
      phone: "",
      countryOfResidence: json['country_of_residence'] as String? ?? "",
      stateCountyProvince: json['state_county_province'] as String? ?? "",
      memberType: json['member_type'] as String? ?? "",
      address: json['address'] as String? ?? "",
      addressLatitude: json['address_latitude']?.toString() ?? "",
      addressLongitude: json['address_longitude']?.toString() ?? "",
      aboutMe: "",
      location: "",
      qualification: "",
      facebook: "",
      twitter: "",
      linkdln: "",
      role: _readRole(json),
      apiToken: json['api_token'] as String?,
      roles: _readRoles(json),
      isGo: _readBool(json['is_go']),
      canManageGroups: _readBool(json['can_manage_groups']),
      canManageGoshenRegistration: _readBool(
        json['can_manage_goshen_registration'] ??
            json['canManageGoshenRegistration'],
      ),
      canManageGoshenVouchers: _readBool(
        json['can_manage_goshen_vouchers'] ?? json['canManageGoshenVouchers'],
      ),
      canManageQuiz: _readBool(
        json['can_manage_goshen_quiz'] ?? json['canManageQuiz'],
      ),
      canManageFundraising: _readBool(
        json['can_manage_fundraising'] ?? json['canManageFundraising'],
      ),
      canManageWalletWithdrawals: _readBool(
        json['can_manage_wallet_withdrawals'] ??
            json['canManageWalletWithdrawals'],
      ),
      canManageDynamicForms: _readBool(
        json['can_manage_dynamic_forms'] ?? json['canManageDynamicForms'],
      ),
      canManageChurchEvents: _readBool(
        json['can_manage_church_events'] ?? json['canManageChurchEvents'],
      ),
      canManageVerseOfDay: _readBool(
        json['can_manage_verse_of_day'] ?? json['canManageVerseOfDay'],
      ),
      canManageCounseling: _readBool(
        json['can_manage_counseling'] ?? json['canManageCounseling'],
      ),
      hasPropheticDecreePermission: _readBool(
        json['can_manage_prophetic_decree'] ?? json['canManagePropheticDecree'],
      ),
      canSendAdminMessages: _readBool(
        json['can_send_admin_messages'] ?? json['canSendAdminMessages'],
      ),
      activated: 0,
    );
  }

  factory Userdata.fromJsonActivated(Map<String, dynamic> json) {
    //print(json);
    return Userdata(
        firstName: json['first_name'] as String?,
        profileTitle: _readString(json,
            const ['profile_title', 'profileTitle', 'salutation', 'title']),
        maritalStatus:
            _readString(json, const ['marital_status', 'maritalStatus']),
        middleName: json['middle_name'] as String?,
        lastName: json['last_name'] as String?,
        name: json['name'] as String?,
        email: json['email'] as String?,
        triumphantId:
            _readString(json, const ['triumphant_id', 'triumphantId']),
        avatar: json['avatar'] as String?,
        coverPhoto: json['cover_photo'] as String?,
        gender: json['gender'] as String?,
        groupId: _readInt(json['group_id']),
        groupName: json['group_name'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        phone: json['phone'] as String?,
        countryOfResidence: json['country_of_residence'] as String?,
        stateCountyProvince: json['state_county_province'] as String?,
        memberType: json['member_type'] as String?,
        address: json['address'] as String?,
        addressLatitude: json['address_latitude']?.toString(),
        addressLongitude: json['address_longitude']?.toString(),
        aboutMe: json['about_me'] as String?,
        location: json['location'] as String?,
        qualification: json['qualification'] as String?,
        facebook: json['facebook'] as String?,
        twitter: json['twitter'] as String?,
        linkdln: json['linkdln'] as String?,
        role: _readRole(json),
        apiToken: json['api_token'] as String?,
        roles: _readRoles(json),
        isGo: _readBool(json['is_go']),
        canManageGroups: _readBool(json['can_manage_groups']),
        canManageGoshenRegistration: _readBool(
          json['can_manage_goshen_registration'] ??
              json['canManageGoshenRegistration'],
        ),
        canManageGoshenVouchers: _readBool(
          json['can_manage_goshen_vouchers'] ?? json['canManageGoshenVouchers'],
        ),
        canManageQuiz: _readBool(
          json['can_manage_goshen_quiz'] ?? json['canManageQuiz'],
        ),
        canManageFundraising: _readBool(
          json['can_manage_fundraising'] ?? json['canManageFundraising'],
        ),
        canManageWalletWithdrawals: _readBool(
          json['can_manage_wallet_withdrawals'] ??
              json['canManageWalletWithdrawals'],
        ),
        canManageDynamicForms: _readBool(
          json['can_manage_dynamic_forms'] ?? json['canManageDynamicForms'],
        ),
        canManageChurchEvents: _readBool(
          json['can_manage_church_events'] ?? json['canManageChurchEvents'],
        ),
        canManageVerseOfDay: _readBool(
          json['can_manage_verse_of_day'] ?? json['canManageVerseOfDay'],
        ),
        canManageCounseling: _readBool(
          json['can_manage_counseling'] ?? json['canManageCounseling'],
        ),
        hasPropheticDecreePermission: _readBool(
          json['can_manage_prophetic_decree'] ??
              json['canManagePropheticDecree'],
        ),
        canSendAdminMessages: _readBool(
          json['can_send_admin_messages'] ?? json['canSendAdminMessages'],
        ),
        activated: 0);
  }

  factory Userdata.fromJson2(Map<String, dynamic> json) {
    int following = int.parse(json['following'].toString());
    return Userdata(
      firstName: json['first_name'] as String?,
      profileTitle: _readString(
          json, const ['profile_title', 'profileTitle', 'salutation', 'title']),
      maritalStatus:
          _readString(json, const ['marital_status', 'maritalStatus']),
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      triumphantId: _readString(json, const ['triumphant_id', 'triumphantId']),
      avatar: json['avatar'] as String?,
      coverPhoto: json['cover_photo'] as String?,
      gender: json['gender'] as String?,
      groupId: _readInt(json['group_id']),
      groupName: json['group_name'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      phone: json['phone'] as String?,
      countryOfResidence: json['country_of_residence'] as String?,
      stateCountyProvince: json['state_county_province'] as String?,
      memberType: json['member_type'] as String?,
      address: json['address'] as String?,
      addressLatitude: json['address_latitude']?.toString(),
      addressLongitude: json['address_longitude']?.toString(),
      aboutMe: json['about_me'] as String?,
      location: json['location'] as String?,
      qualification: json['qualification'] as String?,
      facebook: json['facebook'] as String?,
      twitter: json['twitter'] as String?,
      linkdln: json['linkdln'] as String?,
      role: _readRole(json),
      apiToken: json['api_token'] as String?,
      roles: _readRoles(json),
      isGo: _readBool(json['is_go']),
      canManageGroups: _readBool(json['can_manage_groups']),
      canManageGoshenRegistration: _readBool(
        json['can_manage_goshen_registration'] ??
            json['canManageGoshenRegistration'],
      ),
      canManageGoshenVouchers: _readBool(
        json['can_manage_goshen_vouchers'] ?? json['canManageGoshenVouchers'],
      ),
      canManageQuiz: _readBool(
        json['can_manage_goshen_quiz'] ?? json['canManageQuiz'],
      ),
      canManageFundraising: _readBool(
        json['can_manage_fundraising'] ?? json['canManageFundraising'],
      ),
      canManageWalletWithdrawals: _readBool(
        json['can_manage_wallet_withdrawals'] ??
            json['canManageWalletWithdrawals'],
      ),
      canManageDynamicForms: _readBool(
        json['can_manage_dynamic_forms'] ?? json['canManageDynamicForms'],
      ),
      canManageChurchEvents: _readBool(
        json['can_manage_church_events'] ?? json['canManageChurchEvents'],
      ),
      canManageVerseOfDay: _readBool(
        json['can_manage_verse_of_day'] ?? json['canManageVerseOfDay'],
      ),
      canManageCounseling: _readBool(
        json['can_manage_counseling'] ?? json['canManageCounseling'],
      ),
      hasPropheticDecreePermission: _readBool(
        json['can_manage_prophetic_decree'] ?? json['canManagePropheticDecree'],
      ),
      canSendAdminMessages: _readBool(
        json['can_send_admin_messages'] ?? json['canSendAdminMessages'],
      ),
      activated: 0,
      following: following == 0,
    );
  }

  factory Userdata.fromMap(Map<String, dynamic> data) {
    return Userdata(
      firstName: data['firstName'],
      profileTitle: data['profileTitle'],
      maritalStatus: data['maritalStatus'],
      middleName: data['middleName'],
      lastName: data['lastName'],
      name: data['name'],
      email: data['email'],
      triumphantId: data['triumphantId'],
      avatar: data['avatar'],
      coverPhoto: data['coverPhoto'],
      gender: data['gender'],
      groupId: _readInt(data['groupId']),
      groupName: data['groupName'],
      dateOfBirth: data['dateOfBirth'],
      phone: data['phone'],
      countryOfResidence: data['countryOfResidence'],
      stateCountyProvince: data['stateCountyProvince'],
      memberType: data['memberType'],
      address: data['address'],
      addressLatitude: data['addressLatitude'],
      addressLongitude: data['addressLongitude'],
      aboutMe: data['aboutMe'],
      location: data['location'],
      qualification: data['qualification'],
      facebook: data['facebook'],
      twitter: data['twitter'],
      linkdln: data['linkdln'],
      role: data['role'] ?? data['user_role'] ?? data['account_type'],
      apiToken: data['apiToken'],
      roles: _parseRolesValue(data['roles']),
      isGo: _readBool(data['isGo']),
      canManageGroups: _readBool(data['canManageGroups']),
      canManageGoshenRegistration:
          _readBool(data['canManageGoshenRegistration']),
      canManageGoshenVouchers: _readBool(data['canManageGoshenVouchers']),
      canManageQuiz: _readBool(data['canManageQuiz']),
      canManageFundraising: _readBool(data['canManageFundraising']),
      canManageWalletWithdrawals: _readBool(data['canManageWalletWithdrawals']),
      canManageDynamicForms: _readBool(data['canManageDynamicForms']),
      canManageChurchEvents: _readBool(data['canManageChurchEvents']),
      canManageVerseOfDay: _readBool(data['canManageVerseOfDay']),
      canManageCounseling: _readBool(data['canManageCounseling']),
      hasPropheticDecreePermission: _readBool(data['canManagePropheticDecree']),
      canSendAdminMessages: _readBool(data['canSendAdminMessages']),
      activated: _readActivationState(data['activated']),
    );
  }

  Map<String, dynamic> toMap() => {
        "firstName": firstName,
        "profileTitle": profileTitle,
        "maritalStatus": maritalStatus,
        "middleName": middleName,
        "lastName": lastName,
        "name": name,
        "email": email,
        "triumphantId": triumphantId,
        "avatar": avatar,
        "coverPhoto": coverPhoto,
        "gender": gender,
        "groupId": groupId,
        "groupName": groupName,
        "dateOfBirth": dateOfBirth,
        "phone": phone,
        "countryOfResidence": countryOfResidence,
        "stateCountyProvince": stateCountyProvince,
        "memberType": memberType,
        "address": address,
        "addressLatitude": addressLatitude,
        "addressLongitude": addressLongitude,
        "aboutMe": aboutMe,
        "location": location,
        "qualification": qualification,
        "facebook": facebook,
        "twitter": twitter,
        "linkdln": linkdln,
        "role": role,
        "apiToken": apiToken,
        "roles": roles.join(','),
        "isGo": isGo ? 1 : 0,
        "canManageGroups": canManageGroups ? 1 : 0,
        "canManageGoshenRegistration": canManageGoshenRegistration ? 1 : 0,
        "canManageGoshenVouchers": canManageGoshenVouchers ? 1 : 0,
        "canManageQuiz": canManageQuiz ? 1 : 0,
        "canManageFundraising": canManageFundraising ? 1 : 0,
        "canManageWalletWithdrawals": canManageWalletWithdrawals ? 1 : 0,
        "canManageDynamicForms": canManageDynamicForms ? 1 : 0,
        "canManageChurchEvents": canManageChurchEvents ? 1 : 0,
        "canManageVerseOfDay": canManageVerseOfDay ? 1 : 0,
        "canManageCounseling": canManageCounseling ? 1 : 0,
        "canManagePropheticDecree": hasPropheticDecreePermission ? 1 : 0,
        "canSendAdminMessages": canSendAdminMessages ? 1 : 0,
        "activated": activated,
      };

  bool get isVerified => activated == 0;

  bool get isGeneralOverseer {
    if (isGo) return true;
    final normalizedRoles = roles
        .map((item) => item.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''));
    if (normalizedRoles.any(_isGoRoleName)) {
      return true;
    }
    final normalized =
        (role ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return _isGoRoleName(normalized);
  }

  bool get canManagePropheticDecree {
    if (hasPropheticDecreePermission) return true;
    if (isGeneralOverseer) return true;
    return _hasRole(_isPropheticDecreeManagerRoleName);
  }

  bool get canManageChurchGroups {
    return canManageGroups;
  }

  bool get canViewGoshenExperienceStats {
    final normalizedRoles = roles
        .map((item) => item.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''));
    final normalized =
        (role ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return normalizedRoles.any(_isEventManagerRoleName) ||
        _isEventManagerRoleName(normalized);
  }

  bool get canManageGoshenRegistrationTools {
    if (canManageGoshenRegistration) return true;
    final normalizedRoles = roles
        .map((item) => item.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''));
    final normalized =
        (role ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return normalizedRoles.any(_isEventManagerRoleName) ||
        _isEventManagerRoleName(normalized);
  }

  bool get canManageGoshenVoucherTools {
    if (canManageGoshenVouchers) return true;
    return canManageGoshenRegistrationTools ||
        _hasRole(_isVoucherManagerRoleName);
  }

  bool get canManageFundraisingTools {
    if (canManageFundraising) return true;
    final normalizedRoles = roles
        .map((item) => item.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''));
    final normalized =
        (role ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return normalizedRoles.any(_isFundraisingManagerRoleName) ||
        _isFundraisingManagerRoleName(normalized);
  }

  bool get canManageQuizTools {
    if (canManageQuiz) return true;
    return _hasRole(_isQuizManagerRoleName);
  }

  bool get canManageWalletWithdrawalTools {
    if (canManageWalletWithdrawals) return true;
    return _hasRole(_isWalletWithdrawalManagerRoleName);
  }

  bool get canManageDynamicFormTools {
    if (canManageDynamicForms) return true;
    return _hasRole(_isDynamicFormsManagerRoleName);
  }

  bool get canManageChurchEventTools {
    if (canManageChurchEvents) return true;
    return _hasRole(_isChurchEventManagerRoleName);
  }

  bool get canManageVerseOfDayTools {
    if (canManageVerseOfDay) return true;
    return _hasRole(_isVerseOfDayManagerRoleName);
  }

  bool get canManageCounselingTools {
    if (canManageCounseling) return true;
    return _hasRole(_isCounselingManagerRoleName);
  }

  bool get canSendAdminMessageTools {
    if (canSendAdminMessages) return true;
    return _hasRole(_isMessageManagerRoleName);
  }

  bool _hasRole(bool Function(String normalized) matcher) {
    final normalizedRoles = roles
        .map((item) => item.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''));
    final normalized =
        (role ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return normalizedRoles.any(matcher) || matcher(normalized);
  }
}

bool _isGoRoleName(String normalized) {
  return normalized == 'go' ||
      normalized == 'gorole' ||
      normalized == 'generaloverseer' ||
      normalized == 'generaloverseerrole' ||
      normalized == 'propheticdecreego' ||
      normalized == 'propheticdecreegorole';
}

bool _isPropheticDecreeManagerRoleName(String normalized) {
  return _isGoRoleName(normalized) || normalized == 'triumphantmainpastor';
}

bool _isEventManagerRoleName(String normalized) {
  return normalized == 'eventmanager' ||
      normalized == 'goshenmanager' ||
      normalized == 'retreatmanager' ||
      normalized == 'admin' ||
      normalized == 'superadmin';
}

bool _isFundraisingManagerRoleName(String normalized) {
  return normalized == 'fundraisingmanager' ||
      normalized == 'eventmanager' ||
      normalized == 'goshenmanager' ||
      normalized == 'retreatmanager' ||
      normalized == 'admin' ||
      normalized == 'superadmin';
}

bool _isVoucherManagerRoleName(String normalized) {
  return normalized == 'vouchermanager' ||
      normalized == 'goshenvouchermanager' ||
      _isEventManagerRoleName(normalized);
}

bool _isQuizManagerRoleName(String normalized) {
  return normalized == 'quizmanager' ||
      normalized == 'goshenquizmanager' ||
      normalized == 'eventmanager' ||
      normalized == 'admin' ||
      normalized == 'superadmin';
}

bool _isWalletWithdrawalManagerRoleName(String normalized) {
  return normalized == 'walletmanager' ||
      normalized == 'goshenwalletmanager' ||
      _isEventManagerRoleName(normalized);
}

bool _isDynamicFormsManagerRoleName(String normalized) {
  return normalized == 'formsmanager' ||
      normalized == 'dynamicformsmanager' ||
      normalized == 'ondemandformsmanager' ||
      _isEventManagerRoleName(normalized);
}

bool _isChurchEventManagerRoleName(String normalized) {
  return normalized == 'eventsmanager' ||
      normalized == 'churcheventmanager' ||
      normalized == 'contentmanager' ||
      _isEventManagerRoleName(normalized);
}

bool _isVerseOfDayManagerRoleName(String normalized) {
  return normalized == 'devotionalmanager' ||
      normalized == 'verseofdaymanager' ||
      normalized == 'versemanager' ||
      normalized == 'contentmanager' ||
      _isEventManagerRoleName(normalized) ||
      _isGoRoleName(normalized);
}

bool _isMessageManagerRoleName(String normalized) {
  return normalized == 'messagingmanager' ||
      normalized == 'messagecenter' ||
      _isEventManagerRoleName(normalized);
}

bool _isCounselingManagerRoleName(String normalized) {
  return normalized == 'counselor' ||
      normalized == 'counsellor' ||
      normalized == 'counselingteam' ||
      normalized == 'counsellingteam' ||
      normalized == 'pastor' ||
      normalized == 'triageteam' ||
      normalized == 'pastoralcare' ||
      normalized == 'triumphantitmanager' ||
      _isEventManagerRoleName(normalized);
}

String _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = json[key]?.toString().trim() ?? '';
    if (raw.isNotEmpty && raw.toLowerCase() != 'null') return raw;
  }
  return '';
}

String _readRole(Map<String, dynamic> json) {
  final value = json['role'] ??
      json['user_role'] ??
      json['role_name'] ??
      json['account_type'] ??
      json['user_type'] ??
      json['type'];
  return value?.toString() ?? '';
}

List<String> _readRoles(Map<String, dynamic> json) {
  final value = json['roles'];
  final roles = _parseRolesValue(value);
  final singleRole = _readRole(json);
  if (singleRole.isNotEmpty && !roles.contains(singleRole)) {
    roles.add(singleRole);
  }
  return roles;
}

List<String> _parseRolesValue(dynamic value) {
  if (value is List) {
    return value
        .map((role) => role.toString())
        .where((role) => role.isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(',')
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toList();
  }
  return [];
}

bool _readBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  final text = value.toString().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes';
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

int _readActivationState(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is bool) return value ? 1 : 0;

  final text = value.toString().trim().toLowerCase();
  if (text.isEmpty || text == 'null') return 0;
  if (text == 'true' || text == 'yes') return 1;
  if (text == 'false' || text == 'no') return 0;

  return int.tryParse(text) ?? 0;
}
