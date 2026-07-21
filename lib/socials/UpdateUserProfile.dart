import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.g.dart';
import '../models/ChurchGroup.dart';
import '../models/ScreenArguements.dart';
import '../models/Userdata.dart';
import '../providers/AppStateManager.dart';
import '../socials/UserProfileScreen.dart';
import '../utils/Alerts.dart';
import '../utils/ApiUrl.dart';
import '../utils/Utility.dart';
import '../utils/img.dart';
import '../utils/member_profile_requirements.dart';
import '../utils/member_profile_presentation.dart';
import '../utils/my_colors.dart';
import '../widgets/country_selector.dart';
import '../widgets/birthday_month_day_field.dart';

class UpdateUserProfile extends StatefulWidget {
  static const routeName = "/updateprofile";

  const UpdateUserProfile({Key? key, this.check}) : super(key: key);

  final bool? check;

  @override
  UpdateUserProfileState createState() => UpdateUserProfileState();
}

class UpdateUserProfileState extends State<UpdateUserProfile> {
  Userdata? userdata;
  String profileTitle = "";
  String gender = "Male";
  String maritalStatus = "";
  String memberType = "church_member";
  String birthdayMonthDay = '';
  String countryOfResidence = "";
  String stateCountyProvince = "";
  int? groupId;
  List<ChurchGroup> groups = [];
  bool groupsLoading = true;
  String avatar = "";
  String coverPhoto = "";
  final firstNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final aboutController = TextEditingController();

  @override
  void initState() {
    super.initState();
    userdata = Provider.of<AppStateManager>(context, listen: false).userdata;
    profileTitle = (userdata?.profileTitle?.isNotEmpty ?? false)
        ? userdata!.profileTitle!
        : '';
    gender =
        (userdata?.gender?.isNotEmpty ?? false) ? userdata!.gender! : 'Male';
    maritalStatus = (userdata?.maritalStatus?.isNotEmpty ?? false)
        ? userdata!.maritalStatus!
        : '';
    memberType = (userdata?.memberType?.isNotEmpty ?? false)
        ? userdata!.memberType!
        : 'church_member';
    birthdayMonthDay = normalizeBirthdayMonthDay(
      userdata?.birthdayMonthDay?.isNotEmpty ?? false
          ? userdata?.birthdayMonthDay
          : userdata?.dateOfBirth,
    );
    groupId = userdata?.groupId;
    countryOfResidence = userdata?.countryOfResidence ?? "";
    stateCountyProvince = userdata?.stateCountyProvince ?? "";
    firstNameController.text = userdata?.firstName ?? '';
    middleNameController.text = userdata?.middleName ?? '';
    lastNameController.text = userdata?.lastName ?? '';
    if (firstNameController.text.trim().isEmpty &&
        lastNameController.text.trim().isEmpty) {
      final parts = (userdata?.name ?? '')
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) firstNameController.text = parts.first;
      if (parts.length > 1)
        lastNameController.text = parts.sublist(1).join(' ');
    }
    phoneController.text = userdata?.phone ?? '';
    addressController.text = userdata?.address ?? '';
    aboutController.text = (userdata?.aboutMe?.isEmpty ?? true)
        ? ''
        : Utility.getBase64DecodedString(userdata!.aboutMe!);
    loadGroups();
  }

  Future<void> loadGroups() async {
    try {
      final response = await Dio().get(ApiUrl.FETCH_GROUPS);
      final res = response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : json.decode(response.data);
      final parsed = (res['groups'] as List? ?? [])
          .whereType<Map>()
          .map((item) => ChurchGroup.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (!mounted) return;
      setState(() {
        groups = parsed;
        if (!isVisitorMemberType(memberType)) {
          groupId ??= _defaultGroupId(parsed);
        }
        groupsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => groupsLoading = false);
    }
  }

  int? _defaultGroupId(List<ChurchGroup> items) {
    for (final group in items) {
      if (group.name.toLowerCase() == 'no group') return group.id;
    }
    return items.isEmpty ? null : items.first.id;
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    aboutController.dispose();
    super.dispose();
  }

  Future<void> pickImages(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowCompression: true,
      allowMultiple: false,
      withData: false,
      allowedExtensions: ['png', 'PNG', 'JPEG', 'JPG', 'jpg', 'jpeg', 'webp'],
    );
    if (!mounted || result == null) return;
    final path = result.files.first.path;
    if (path == null) return;
    setState(() {
      if (type == 'avatar') {
        avatar = path;
      } else {
        coverPhoto = path;
      }
    });
  }

  Future<void> validateAndSubmit() async {
    final firstName = firstNameController.text.trim();
    final middleName = middleNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final phone = phoneController.text.trim();
    final address = addressController.text.trim();
    final about = aboutController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        phone.isEmpty ||
        gender.isEmpty ||
        memberType.isEmpty ||
        (!isVisitorMemberType(memberType) &&
            (profileTitle.isEmpty ||
                maritalStatus.isEmpty ||
                birthdayMonthDay.isEmpty ||
                groupId == null ||
                countryOfResidence.isEmpty ||
                stateCountyProvince.isEmpty ||
                address.isEmpty))) {
      Alerts.show(
          context,
          t.error,
          isVisitorMemberType(memberType)
              ? 'Please fill your first name, last name, gender, member type and phone number before saving.'
              : 'Please fill your title, first name, last name, birthday, gender, marital status, member type, church group, country, state/county/province, address and phone number before saving.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await uploadFileFromDio(firstName, middleName, lastName, phone, address,
        about, prefs.getString("firebase_token"));
  }

  Future<void> uploadFileFromDio(
      String firstName,
      String middleName,
      String lastName,
      String phone,
      String address,
      String aboutme,
      String? token) async {
    Alerts.showProgressDialog(context, t.processingpleasewait);
    final fullName = [firstName, middleName, lastName]
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    final fields = <String, dynamic>{
      "email": userdata!.email,
      "fullname": fullName,
      "first_name": firstName,
      "middle_name": middleName,
      "last_name": lastName,
      "phone": phone,
      "gender": gender,
      "member_type": memberType,
      "about_me": Utility.getBase64EncodedString(aboutme),
      "notify_token": token,
    };
    if (!isVisitorMemberType(memberType)) {
      fields.addAll({
        "title": profileTitle,
        "profile_title": profileTitle,
        "salutation": profileTitle,
        "marital_status": maritalStatus,
        "birthday_month_day": birthdayMonthDay,
        "group_id": groupId,
        "country_of_residence": countryOfResidence,
        "state_county_province": stateCountyProvince,
        "address": address,
        "address_latitude": userdata?.addressLatitude,
        "address_longitude": userdata?.addressLongitude,
      });
    }
    final formData = FormData.fromMap(fields);

    if (avatar.isNotEmpty) {
      formData.files
          .add(MapEntry("avatar", await MultipartFile.fromFile(avatar)));
    }
    if (coverPhoto.isNotEmpty) {
      formData.files.add(
          MapEntry("cover_photo", await MultipartFile.fromFile(coverPhoto)));
    }

    try {
      final response =
          await Dio().post(ApiUrl.BASEURL + "updateProfile", data: formData);
      Navigator.of(context).pop();
      final res = response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : json.decode(response.data);
      if (res["status"] == "error") {
        Alerts.show(context, t.error, res["msg"] ?? res["message"] ?? t.error);
        return;
      }

      final updatedUser = Userdata.fromJsonActivated(res["user"]);
      if ((updatedUser.birthdayMonthDay ?? '').trim().isEmpty) {
        updatedUser.birthdayMonthDay = birthdayMonthDay;
      }
      Provider.of<AppStateManager>(context, listen: false)
          .setUserData(updatedUser);

      Navigator.pushReplacementNamed(
        context,
        UserProfileScreen.routeName,
        arguments: ScreenArguements(items: updatedUser),
      );
    } on DioException catch (e) {
      Navigator.of(context).pop();
      Alerts.show(
          context, t.error, e.message ?? 'Unable to update profile right now.');
    }
  }

  Future<void> _pickBirthday() async {
    final selected = await pickBirthdayMonthDay(context, birthdayMonthDay);
    if (selected != null && mounted) {
      setState(() => birthdayMonthDay = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppStateManager>(context).userdata;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA);
    final card = isDark ? const Color(0xFF102532) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF102532);
    final muted = isDark ? Colors.white60 : const Color(0xFF60707A);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C2230),
        title: Text(t.updateprofile),
        actions: [
          IconButton(
            tooltip: 'Save profile',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: validateAndSubmit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          children: [
            _EditProfileHero(
              user: user,
              avatar: avatar,
              coverPhoto: coverPhoto,
              onPickAvatar: () => pickImages('avatar'),
              onPickCover: () => pickImages('coverphoto'),
            ),
            Transform.translate(
              offset: const Offset(0, 0),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.fromLTRB(18, 30, 18, 18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileField(
                            controller: firstNameController,
                            label: 'First name',
                            icon: Icons.person_outline_rounded,
                            text: text,
                            muted: muted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ProfileField(
                            controller: lastNameController,
                            label: 'Last name',
                            icon: Icons.badge_outlined,
                            text: text,
                            muted: muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ProfileField(
                      controller: middleNameController,
                      label: 'Middle name',
                      icon: Icons.person_pin_outlined,
                      text: text,
                      muted: muted,
                    ),
                    const SizedBox(height: 14),
                    if (!isVisitorMemberType(memberType)) ...[
                      _ProfileDropdown(
                        value: profileTitle,
                        label: 'Title',
                        icon: Icons.badge_outlined,
                        items: const {
                          'Mr.': 'Mr.',
                          'Mrs.': 'Mrs.',
                          'Miss': 'Miss',
                        },
                        text: text,
                        muted: muted,
                        onChanged: (value) =>
                            setState(() => profileTitle = value),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _GenderSelector(
                      value: gender,
                      onChanged: (value) => setState(() => gender = value),
                    ),
                    const SizedBox(height: 14),
                    _MemberTypeSelector(
                      value: memberType,
                      lockedUntil: userdata?.memberTypeEditableAt,
                      onChanged: (value) => setState(() {
                        memberType = value;
                        if (!isVisitorMemberType(value)) {
                          groupId ??= _defaultGroupId(groups);
                        }
                      }),
                    ),
                    const SizedBox(height: 14),
                    if (!isVisitorMemberType(memberType)) ...[
                      BirthdayMonthDayField(
                        value: birthdayMonthDay,
                        onTap: _pickBirthday,
                        text: text,
                        muted: muted,
                      ),
                      const SizedBox(height: 14),
                      _ProfileDropdown(
                        value: maritalStatus,
                        label: 'Marital status',
                        icon: Icons.favorite_border_rounded,
                        items: const {
                          'Single': 'Single',
                          'Married': 'Married',
                          'Widowed': 'Widowed',
                          'Divorced/Separated': 'Divorced/Separated',
                          'Prefer not to say': 'Prefer not to say',
                        },
                        text: text,
                        muted: muted,
                        onChanged: (value) =>
                            setState(() => maritalStatus = value),
                      ),
                      const SizedBox(height: 14),
                      _ProfileGroupSelector(
                        groups: groups,
                        value: groupId,
                        isLoading: groupsLoading,
                        onChanged: (value) => setState(() => groupId = value),
                        text: text,
                        muted: muted,
                      ),
                      const SizedBox(height: 14),
                      CountrySelector(
                        value: countryOfResidence,
                        onChanged: (value) => setState(() {
                          countryOfResidence = value;
                          stateCountyProvince = '';
                        }),
                      ),
                      const SizedBox(height: 14),
                      StateProvinceSelector(
                        country: countryOfResidence,
                        value: stateCountyProvince,
                        onChanged: (value) =>
                            setState(() => stateCountyProvince = value),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 14),
                    _ProfileField(
                      controller: phoneController,
                      label: t.phonenumber,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      text: text,
                      muted: muted,
                    ),
                    const SizedBox(height: 14),
                    if (!isVisitorMemberType(memberType)) ...[
                      _ProfileField(
                        controller: addressController,
                        label: 'Address',
                        icon: Icons.home_work_outlined,
                        maxLines: 2,
                        text: text,
                        muted: muted,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _ProfileField(
                      controller: aboutController,
                      label: t.aboutme,
                      icon: Icons.auto_awesome_outlined,
                      maxLines: 4,
                      text: text,
                      muted: muted,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: validateAndSubmit,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB522),
                          foregroundColor: MyColors.primary,
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileGroupSelector extends StatelessWidget {
  const _ProfileGroupSelector({
    required this.groups,
    required this.value,
    required this.isLoading,
    required this.onChanged,
    required this.text,
    required this.muted,
  });

  final List<ChurchGroup> groups;
  final int? value;
  final bool isLoading;
  final ValueChanged<int?> onChanged;
  final Color text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<int>(
      initialValue: groups.any((group) => group.id == value) ? value : null,
      items: groups
          .map((group) => DropdownMenuItem<int>(
                value: group.id,
                child: Text(group.name),
              ))
          .toList(),
      onChanged: isLoading ? null : onChanged,
      style: TextStyle(color: text, fontWeight: FontWeight.w700),
      dropdownColor: isDark ? const Color(0xFF102532) : Colors.white,
      decoration: InputDecoration(
        labelText: isLoading ? 'Loading groups...' : 'Church group',
        labelStyle: TextStyle(color: muted),
        prefixIcon: Icon(Icons.groups_2_outlined,
            color: isDark ? const Color(0xFFFFC857) : MyColors.primary),
        filled: true,
        fillColor: isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFFB522), width: 1.4),
        ),
      ),
    );
  }
}

class _EditProfileHero extends StatelessWidget {
  const _EditProfileHero({
    required this.user,
    required this.avatar,
    required this.coverPhoto,
    required this.onPickAvatar,
    required this.onPickCover,
  });

  final Userdata? user;
  final String avatar;
  final String coverPhoto;
  final VoidCallback onPickAvatar;
  final VoidCallback onPickCover;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 278,
      child: Stack(
        children: [
          Positioned.fill(
            bottom: 62,
            child: _FlexibleProfileImage(
              localPath: coverPhoto,
              remoteUrl: user?.coverPhoto ?? '',
              fallback: Img.get('cover_photos.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            bottom: 62,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.38),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 82,
            child: _ImageActionButton(
                icon: Icons.photo_camera_rounded, onTap: onPickCover),
          ),
          Positioned(
            left: 22,
            bottom: 0,
            child: Stack(
              children: [
                Container(
                  width: 112,
                  height: 112,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: ClipOval(
                    child: _FlexibleProfileImage(
                      localPath: avatar,
                      remoteUrl: user?.avatar ?? '',
                      fallback: Img.get('avatar.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _ImageActionButton(
                    icon: Icons.person_add_alt_1_rounded,
                    onTap: onPickAvatar,
                    small: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlexibleProfileImage extends StatelessWidget {
  const _FlexibleProfileImage({
    required this.localPath,
    required this.remoteUrl,
    required this.fallback,
    required this.fit,
  });

  final String localPath;
  final String remoteUrl;
  final String fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (localPath.isNotEmpty) {
      return Image.file(File(localPath), fit: fit, width: double.infinity);
    }
    if (remoteUrl.isNotEmpty) {
      return Image.network(
        remoteUrl,
        fit: fit,
        width: double.infinity,
        errorBuilder: (_, __, ___) => Image.asset(fallback, fit: fit),
      );
    }
    return Image.asset(fallback, fit: fit, width: double.infinity);
  }
}

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton(
      {required this.icon, required this.onTap, this.small = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0C2230),
      borderRadius: BorderRadius.circular(small ? 16 : 20),
      elevation: 8,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(small ? 16 : 20),
        child: SizedBox(
          width: small ? 42 : 58,
          height: small ? 42 : 58,
          child: Icon(icon, color: Colors.white, size: small ? 19 : 24),
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.text,
    required this.muted,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color text;
  final Color muted;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: text, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: muted),
        prefixIcon: Icon(icon,
            color: isDark ? const Color(0xFFFFC857) : MyColors.primary),
        filled: true,
        fillColor: isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFFB522), width: 1.4),
        ),
      ),
    );
  }
}

class _ProfileDropdown extends StatelessWidget {
  const _ProfileDropdown({
    required this.value,
    required this.label,
    required this.icon,
    required this.items,
    required this.text,
    required this.muted,
    required this.onChanged,
  });

  final String value;
  final String label;
  final IconData icon;
  final Map<String, String> items;
  final Color text;
  final Color muted;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeValue = items.containsKey(value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      items: items.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
      style: TextStyle(color: text, fontWeight: FontWeight.w700),
      dropdownColor: isDark ? const Color(0xFF102532) : Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: muted),
        prefixIcon: Icon(icon,
            color: isDark ? const Color(0xFFFFC857) : MyColors.primary),
        filled: true,
        fillColor: isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFFB522), width: 1.4),
        ),
      ),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
            value: 'Male',
            label: Text(t.male),
            icon: const Icon(Icons.male_rounded)),
        ButtonSegment(
            value: 'Female',
            label: Text(t.female),
            icon: const Icon(Icons.female_rounded)),
      ],
      selected: {value},
      onSelectionChanged: (values) => onChanged(values.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFFFFB522)
              : (isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA)),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? MyColors.primary
              : (isDark ? Colors.white70 : const Color(0xFF60707A)),
        ),
      ),
    );
  }
}

class _MemberTypeSelector extends StatelessWidget {
  const _MemberTypeSelector({
    required this.value,
    required this.lockedUntil,
    required this.onChanged,
  });

  final String value;
  final String? lockedUntil;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedValue = value == 'visitor' ? 'visitor' : 'church_member';
    final isLocked = isMembershipStatusLocked(lockedUntil);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Membership status',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF60707A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'church_member',
              label: Text('Church member'),
              icon: Icon(Icons.church_outlined),
            ),
            ButtonSegment(
              value: 'visitor',
              label: Text('Visitor'),
              icon: Icon(Icons.person_pin_circle_outlined),
            ),
          ],
          selected: {selectedValue},
          onSelectionChanged:
              isLocked ? null : (values) => onChanged(values.first),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Color(0xFFFFB522)
                  : (isDark
                      ? const Color(0xFF071720)
                      : const Color(0xFFF5F8FA)),
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? MyColors.primary
                  : (isDark ? Colors.white70 : const Color(0xFF60707A)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          membershipStatusLockMessage(lockedUntil),
          style: TextStyle(
            color: isLocked
                ? (isDark ? const Color(0xFFFFC857) : MyColors.primary)
                : (isDark ? Colors.white60 : const Color(0xFF60707A)),
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
