import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../i18n/strings.g.dart';
import '../models/ChurchGroup.dart';
import '../utils/Alerts.dart';
import '../utils/ApiUrl.dart';
import '../utils/member_profile_requirements.dart';
import '../utils/my_colors.dart';
import '../widgets/country_selector.dart';
import '../socials/UpdateUserProfile.dart';
import 'LoginScreen.dart';
import 'VerifyEmailScreen.dart';
import 'auth_ui.dart';
import 'google_auth_service.dart';

class RegisterScreen extends StatefulWidget {
  static const routeName = "/register";

  @override
  RegisterScreenRouteState createState() => RegisterScreenRouteState();
}

class RegisterScreenRouteState extends State<RegisterScreen> {
  final firstNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final passwordController = TextEditingController();
  final repeatPasswordController = TextEditingController();
  String profileTitle = '';
  String gender = 'Male';
  String maritalStatus = '';
  String memberType = 'church_member';
  String countryOfResidence = '';
  String stateCountyProvince = '';
  double? addressLatitude;
  double? addressLongitude;
  int? groupId;
  List<ChurchGroup> groups = [];
  bool groupsLoading = true;
  bool locatingAddress = false;
  final googleAuth = GoogleAuthService();
  bool googleEnabled = false;
  bool googleLoading = false;

  @override
  void initState() {
    super.initState();
    loadGroups();
    _loadGoogleConfig();
  }

  Future<void> _loadGoogleConfig() async {
    try {
      final config = await googleAuth.fetchConfig();
      if (!mounted) return;
      setState(() => googleEnabled = config.enabled);
    } catch (_) {
      if (!mounted) return;
      setState(() => googleEnabled = false);
    }
  }

  Future<void> loadGroups() async {
    try {
      final response = await http.get(Uri.parse(ApiUrl.FETCH_GROUPS));
      final res = json.decode(response.body) as Map<String, dynamic>;
      final parsed = (res['groups'] as List? ?? [])
          .whereType<Map>()
          .map((item) => ChurchGroup.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (!mounted) return;
      setState(() {
        groups = parsed;
        groupId = _defaultGroupId(parsed);
        groupsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => groupsLoading = false);
    }
  }

  void verifyFormAndSubmit() {
    final firstName = firstNameController.text.trim();
    final middleName = middleNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final name = [firstName, middleName, lastName]
        .where((part) => part.isNotEmpty)
        .join(' ');
    final email = emailController.text.trim();
    final password = passwordController.text;
    final repeatPassword = repeatPasswordController.text;

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        name.isEmpty ||
        email.isEmpty ||
        phoneController.text.trim().isEmpty ||
        gender.trim().isEmpty ||
        memberType.trim().isEmpty ||
        (!isVisitorMemberType(memberType) &&
            (profileTitle.trim().isEmpty ||
                maritalStatus.trim().isEmpty ||
                groupId == null ||
                countryOfResidence.isEmpty ||
                stateCountyProvince.isEmpty ||
                addressController.text.trim().isEmpty)) ||
        password.isEmpty ||
        repeatPassword.isEmpty) {
      Alerts.show(
          context,
          t.error,
          isVisitorMemberType(memberType)
              ? 'Please fill your first name, last name, email, phone number, member status, gender and password.'
              : 'Please fill your title, first name, last name, email, phone number, marital status, member status, gender, church group, country, state/county/province, address and password.');
    } else if (!EmailValidator.validate(email)) {
      Alerts.show(context, t.error, t.invalidemailerrorhint);
    } else if (password.length < 8) {
      Alerts.show(context, t.error, 'Password must be at least 8 characters.');
    } else if (password != repeatPassword) {
      Alerts.show(context, t.error, t.passwordsdontmatch);
    } else {
      registerUser(email, name, firstName, middleName, lastName,
          phoneController.text.trim(), password);
    }
  }

  Future<void> registerUser(String email, String name, String firstName,
      String middleName, String lastName, String phone, String password) async {
    Alerts.showProgressDialog(context, t.processingpleasewait);
    try {
      final response = await http.post(
        Uri.parse(ApiUrl.REGISTER),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "data": <String, dynamic>{
            "email": email,
            "name": name,
            "title": profileTitle,
            "profile_title": profileTitle,
            "salutation": profileTitle,
            "first_name": firstName,
            "middle_name": middleName,
            "last_name": lastName,
            "phone": phone,
            "gender": gender,
            "marital_status": maritalStatus,
            "member_type": memberType,
            "password": password
          }..addAll(isVisitorMemberType(memberType)
              ? const <String, dynamic>{}
              : {
                  "group_id": groupId,
                  "country_of_residence": countryOfResidence,
                  "state_county_province": stateCountyProvince,
                  "address": addressController.text.trim(),
                  "address_latitude": addressLatitude,
                  "address_longitude": addressLongitude,
                })
        }),
      );
      Navigator.of(context).pop();

      if (response.statusCode != 200) {
        Alerts.show(context, t.error, 'Unable to create account right now.');
        return;
      }

      final res = json.decode(response.body) as Map<String, dynamic>;
      if (res["status"] == "error") {
        Alerts.show(context, t.error, _messageFrom(res, t.error));
        return;
      }

      Alerts.show(context, 'Check your email',
          _messageFrom(res, 'We sent your verification code.'));
      Navigator.of(context).pushReplacementNamed(
        VerifyEmailScreen.routeName,
        arguments: VerifyEmailArgs(email: email, password: password),
      );
    } catch (_) {
      Navigator.of(context).pop();
      Alerts.show(context, t.error, 'Unable to create account right now.');
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => locatingAddress = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Alerts.show(context, t.error,
            'Please turn on location services to fill your address automatically.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        Alerts.show(context, t.error,
            'Location permission is needed to fill your address automatically. You can also type the address manually.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = placemarks.isEmpty ? null : placemarks.first;
      final addressParts = [
        place?.street,
        place?.subLocality,
        place?.locality,
        place?.administrativeArea,
        place?.country,
      ]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty);

      setState(() {
        addressLatitude = position.latitude;
        addressLongitude = position.longitude;
        addressController.text = addressParts.join(', ');
      });
    } catch (_) {
      Alerts.show(context, t.error,
          'Unable to detect your address right now. Please type it manually.');
    } finally {
      if (mounted) setState(() => locatingAddress = false);
    }
  }

  String _messageFrom(Map<String, dynamic> response, String fallback) {
    final message = response['message'] ?? response['msg'];
    return message == null || message.toString().trim().isEmpty
        ? fallback
        : message.toString();
  }

  int? _defaultGroupId(List<ChurchGroup> items) {
    for (final group in items) {
      if (group.name.toLowerCase() == 'no group') return group.id;
    }
    return items.isEmpty ? null : items.first.id;
  }

  Future<void> _continueWithGoogle() async {
    setState(() => googleLoading = true);
    try {
      final result = await googleAuth.signInWithResult(context);
      if (!mounted) return;
      if (result != null) {
        if (result.isNewUser || result.profileNeedsUpdate) {
          Navigator.of(context).pushReplacementNamed(
            UpdateUserProfile.routeName,
          );
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (_) {
      if (mounted) {
        Alerts.show(
            context, t.error, 'Unable to continue with Google right now.');
      }
    } finally {
      if (mounted) setState(() => googleLoading = false);
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    passwordController.dispose();
    repeatPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AuthShell(
      title: 'Create account',
      subtitle:
          'Register with your email. You will verify it before the account becomes active.',
      child: Column(
        children: [
          AuthTextField(
            controller: firstNameController,
            label: 'First name',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: middleNameController,
            label: 'Middle name',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: lastNameController,
            label: 'Last name',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          if (!isVisitorMemberType(memberType)) ...[
            _TitleSelector(
              value: profileTitle,
              onChanged: (value) => setState(() => profileTitle = value),
            ),
            const SizedBox(height: 14),
          ],
          AuthTextField(
            controller: emailController,
            label: t.emailaddress,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: phoneController,
            label: 'Phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          _GenderSelector(
            value: gender,
            onChanged: (value) => setState(() => gender = value),
          ),
          const SizedBox(height: 14),
          _MemberTypeSelector(
            value: memberType,
            onChanged: (value) => setState(() {
              memberType = value;
              if (!isVisitorMemberType(value)) {
                groupId ??= _defaultGroupId(groups);
              }
            }),
          ),
          const SizedBox(height: 14),
          if (!isVisitorMemberType(memberType)) ...[
            _MaritalStatusSelector(
              value: maritalStatus,
              onChanged: (value) => setState(() => maritalStatus = value),
            ),
            const SizedBox(height: 14),
            _GroupSelector(
              groups: groups,
              value: groupId,
              isLoading: groupsLoading,
              onChanged: (value) => setState(() => groupId = value),
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
              onChanged: (value) => setState(() => stateCountyProvince = value),
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: addressController,
              label: 'Residential address',
              icon: Icons.home_work_outlined,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: locatingAddress ? null : _useCurrentLocation,
                icon: locatingAddress
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
                label: Text(
                  locatingAddress
                      ? 'Detecting address...'
                      : 'Use current location',
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          AuthTextField(
            controller: passwordController,
            label: t.password,
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: repeatPasswordController,
            label: t.repeatpassword,
            icon: Icons.verified_user_outlined,
            isPassword: true,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: t.register,
            icon: Icons.person_add_alt_1_rounded,
            onPressed: verifyFormAndSubmit,
          ),
          if (googleEnabled) ...[
            const SizedBox(height: 12),
            _GoogleAuthButton(
              label: googleLoading ? 'Connecting...' : 'Continue with Google',
              onPressed: googleLoading ? null : _continueWithGoogle,
            ),
          ],
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pushReplacementNamed(LoginScreen.routeName),
            child: Text(
              t.alreadyhaveanaccount,
              style:
                  TextStyle(color: isDark ? Colors.white70 : MyColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleAuthButton extends StatelessWidget {
  const _GoogleAuthButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : MyColors.primary,
          side: BorderSide(
              color: isDark ? Colors.white24 : const Color(0xFFDCE5EA)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({
    required this.groups,
    required this.value,
    required this.isLoading,
    required this.onChanged,
  });

  final List<ChurchGroup> groups;
  final int? value;
  final bool isLoading;
  final ValueChanged<int?> onChanged;

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
      decoration: InputDecoration(
        labelText: isLoading ? 'Loading groups...' : 'Church group',
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

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8EC),
        ),
      ),
      child: Row(
        children: ['Male', 'Female'].map((item) {
          final selected = value == item;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color:
                      selected ? const Color(0xFFFFB522) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  item,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? MyColors.primary
                        : (isDark ? Colors.white70 : const Color(0xFF60707A)),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TitleSelector extends StatelessWidget {
  const _TitleSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _RegisterDropdown(
      value: value,
      label: 'Title',
      icon: Icons.badge_outlined,
      items: const {
        'Mr.': 'Mr.',
        'Mrs.': 'Mrs.',
        'Miss': 'Miss',
      },
      onChanged: onChanged,
    );
  }
}

class _MaritalStatusSelector extends StatelessWidget {
  const _MaritalStatusSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _RegisterDropdown(
      value: value,
      label: 'Marital status',
      icon: Icons.favorite_border_rounded,
      items: const {
        'Single': 'Single',
        'Married': 'Married',
        'Widowed': 'Widowed',
        'Divorced/Separated': 'Divorced/Separated',
        'Prefer not to say': 'Prefer not to say',
      },
      onChanged: onChanged,
    );
  }
}

class _RegisterDropdown extends StatelessWidget {
  const _RegisterDropdown({
    required this.value,
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final String label;
  final IconData icon;
  final Map<String, String> items;
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
      decoration: InputDecoration(
        labelText: label,
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

class _MemberTypeSelector extends StatelessWidget {
  const _MemberTypeSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = const {
      'church_member': 'Church member',
      'visitor': 'Visitor',
    };

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8EC),
        ),
      ),
      child: Row(
        children: options.entries.map((entry) {
          final selected = value == entry.key;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                decoration: BoxDecoration(
                  color:
                      selected ? const Color(0xFFFFB522) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  entry.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? MyColors.primary
                        : (isDark ? Colors.white70 : const Color(0xFF60707A)),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
