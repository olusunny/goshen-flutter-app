import 'dart:convert';

import 'package:churchapp_flutter/utils/Alerts.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';

import '../auth/LoginScreen.dart';
import '../i18n/strings.g.dart';
import '../models/Userdata.dart';
import '../prayers/prayer_community_screen.dart';
import '../prayers/prayer_guest_prompt.dart';
import '../providers/AppStateManager.dart';
import '../providers/HomeProvider.dart';
import '../screens/AboutUsScreen.dart';
import '../screens/DevotionalScreen.dart';
import '../screens/GoshenRetreatScreen.dart';
import '../screens/GroupsScreen.dart';
import '../screens/ManageGroupsScreen.dart';
import '../screens/MoreMenuScreen.dart';
import '../service/MoreMenuPreloadService.dart';
import '../socials/Settings.dart';
import '../socials/UpdateUserProfile.dart';
import '../testimonies/testimony_wall_screen.dart';
import '../prayers/prayer_points_screen.dart';
import '../utils/ApiUrl.dart';
import '../utils/app_themes.dart';
import '../utils/langs.dart';
import '../utils/my_colors.dart';
import '../widgets/premium_confirm_dialog.dart';

class DrawerScreen extends StatefulWidget {
  DrawerScreen({Key? key}) : super(key: key);

  @override
  _DrawerScreenState createState() => _DrawerScreenState();
}

class _DrawerScreenState extends State<DrawerScreen> {
  late AppStateManager appManager;
  Userdata? userdata;
  bool _testimoniesEnabled = false;
  bool _goshenRetreatEnabled = false;
  bool _prayerPointsEnabled = true;
  bool _interactivePrayerWallEnabled = true;
  bool _devotionalsEnabled = true;
  bool _churchGroupsEnabled = true;

  @override
  void initState() {
    super.initState();
    _applySnapshot(MoreMenuPreloadService.instance.snapshot, notify: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFeatureFlags());
  }

  Future<void> _refreshFeatureFlags() async {
    if (!mounted) return;

    Map<String, dynamic>? homeData;
    Userdata? user;
    try {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      homeData = homeProvider.data;
      _applyHomeData(homeData);
    } catch (_) {}

    try {
      user = Provider.of<AppStateManager>(context, listen: false).userdata;
    } catch (_) {}

    _applySnapshot(MoreMenuPreloadService.instance.snapshot);

    try {
      final snapshot = await MoreMenuPreloadService.instance.warm(
        user: user,
        homeData: homeData,
      );
      _applySnapshot(snapshot);
    } catch (_) {}
  }

  void _applyHomeData(Map<String, dynamic>? data, {bool notify = true}) {
    if (data == null || data.isEmpty) return;
    final testimoniesEnabled =
        data['testimonies_enabled'] == true || _testimoniesEnabled;
    final goshenRetreatEnabled =
        data['goshen_retreat_enabled'] == true || _goshenRetreatEnabled;
    _setFeatureFlags(
      testimoniesEnabled: testimoniesEnabled,
      goshenRetreatEnabled: goshenRetreatEnabled,
      prayerPointsEnabled:
          _readFlag(data['prayer_points_enabled'], _prayerPointsEnabled),
      interactivePrayerWallEnabled: _readFlag(
          data['interactive_prayer_wall_enabled'],
          _interactivePrayerWallEnabled),
      devotionalsEnabled:
          _readFlag(data['devotionals_enabled'], _devotionalsEnabled),
      churchGroupsEnabled:
          _readFlag(data['church_groups_enabled'], _churchGroupsEnabled),
      notify: notify,
    );
  }

  void _applySnapshot(MoreMenuPreloadSnapshot? snapshot, {bool notify = true}) {
    if (snapshot == null) return;
    _setFeatureFlags(
      testimoniesEnabled: snapshot.testimoniesEnabled,
      goshenRetreatEnabled: snapshot.goshenRetreatEnabled,
      prayerPointsEnabled: snapshot.prayerPointsEnabled,
      interactivePrayerWallEnabled: snapshot.interactivePrayerWallEnabled,
      devotionalsEnabled: snapshot.devotionalsEnabled,
      churchGroupsEnabled: snapshot.churchGroupsEnabled,
      notify: notify,
    );
  }

  void _setFeatureFlags({
    required bool testimoniesEnabled,
    required bool goshenRetreatEnabled,
    required bool prayerPointsEnabled,
    required bool interactivePrayerWallEnabled,
    required bool devotionalsEnabled,
    required bool churchGroupsEnabled,
    required bool notify,
  }) {
    if (mounted &&
        (_testimoniesEnabled != testimoniesEnabled ||
            _goshenRetreatEnabled != goshenRetreatEnabled ||
            _prayerPointsEnabled != prayerPointsEnabled ||
            _interactivePrayerWallEnabled != interactivePrayerWallEnabled ||
            _devotionalsEnabled != devotionalsEnabled ||
            _churchGroupsEnabled != churchGroupsEnabled)) {
      void update() {
        _testimoniesEnabled = testimoniesEnabled;
        _goshenRetreatEnabled = goshenRetreatEnabled;
        _prayerPointsEnabled = prayerPointsEnabled;
        _interactivePrayerWallEnabled = interactivePrayerWallEnabled;
        _devotionalsEnabled = devotionalsEnabled;
        _churchGroupsEnabled = churchGroupsEnabled;
      }

      if (notify) {
        setState(update);
      } else {
        update();
      }
    }
  }

  bool _readFlag(dynamic value, bool fallback) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final text = value.toString().toLowerCase().trim();
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }

  @override
  Widget build(BuildContext context) {
    appManager = Provider.of<AppStateManager>(context);
    userdata = appManager.userdata;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF071720) : const Color(0xFFF4F8FA);
    final card = isDark ? const Color(0xFF102532) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF102532);
    final muted = isDark ? Colors.white60 : const Color(0xFF60707A);
    final themeSwitch = appManager.themeData == appThemeData[AppTheme.Dark];
    final language = appLanguageData[
        AppLanguage.values[appManager.preferredLanguage]]!['name']!;
    return SafeArea(
      child: Container(
        color: background,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0C2230), Color(0xFF153F50)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.24 : 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _Avatar(userdata: userdata),
                    const SizedBox(height: 12),
                    Text(
                      userdata == null
                          ? t.guestuser
                          : userdata!.name ?? t.guestuser,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      userdata?.email ?? 'MFM Triumphant Church',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          userdata != null
                              ? showLogoutAlert()
                              : Navigator.pushNamed(
                                  context, LoginScreen.routeName);
                        },
                        icon: Icon(userdata != null
                            ? Icons.logout_rounded
                            : Icons.login_rounded),
                        label: Text(userdata != null ? t.logout : t.login),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB522),
                          foregroundColor: MyColors.primary,
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w800),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _DrawerSection(
                card: card,
                children: [
                  if (_interactivePrayerWallEnabled)
                    _DrawerTile(
                        icon: Icons.volunteer_activism_outlined,
                        title: 'Interactive Prayer Wall',
                        onTap: _openPrayerCommunity),
                  if (_prayerPointsEnabled)
                    _DrawerTile(
                        icon: Icons.menu_book_rounded,
                        title: 'Prayer Points',
                        onTap: () => Navigator.pushNamed(
                            context, PrayerPointsScreen.routeName)),
                  if (_devotionalsEnabled)
                    _DrawerTile(
                        icon: Icons.auto_stories_rounded,
                        title: 'Devotional',
                        onTap: () => Navigator.pushNamed(
                            context, DevotionalScreen.routeName)),
                  if (_goshenRetreatEnabled)
                    _DrawerTile(
                        icon: Icons.event_available_rounded,
                        title: 'Goshen Retreat',
                        onTap: () => Navigator.pushNamed(
                            context, GoshenRetreatScreen.routeName)),
                  if (_testimoniesEnabled)
                    _DrawerTile(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Testimonies & Thanksgiving',
                        onTap: () => Navigator.pushNamed(
                            context, TestimonyWallScreen.routeName)),
                  if (_churchGroupsEnabled)
                    _DrawerTile(
                        icon: Icons.diversity_3_outlined,
                        title: 'Church Groups',
                        onTap: () => Navigator.pushNamed(
                            context, GroupsScreen.routeName)),
                  if (userdata?.canManageChurchGroups == true)
                    _DrawerTile(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Manage Groups',
                        onTap: () => Navigator.pushNamed(
                            context, ManageGroupsScreen.routeName)),
                  _DrawerTile(
                      icon: Icons.dashboard_customize_outlined,
                      title: 'More Features',
                      onTap: () => Navigator.pushNamed(
                          context, MoreMenuScreen.routeName)),
                ],
              ),
              const SizedBox(height: 14),
              _DrawerSection(
                card: card,
                children: [
                  _SettingTile(
                    icon: Icons.language_rounded,
                    title: t.selectlanguage,
                    value: language,
                    onTap: showLanguageDialog,
                    muted: muted,
                  ),
                  _SettingTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Notification',
                    value: 'Preferences',
                    onTap: () =>
                        Navigator.pushNamed(context, SettingsScreen.routeName),
                    muted: muted,
                  ),
                  SwitchListTile(
                    value: themeSwitch,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    activeThumbColor: const Color(0xFFFFB522),
                    title: Text(t.nightmode,
                        style: TextStyle(
                            color: text, fontWeight: FontWeight.w700)),
                    secondary: Icon(Icons.dark_mode_outlined,
                        color: isDark
                            ? const Color(0xFFFFC857)
                            : MyColors.primary),
                    onChanged: (value) => appManager
                        .setTheme(value ? AppTheme.Dark : AppTheme.White),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DrawerSection(
                card: card,
                children: [
                  _DrawerTile(
                      icon: Icons.rate_review_outlined,
                      title: t.rate,
                      muted: true,
                      onTap: requestReview),
                  _DrawerTile(
                      icon: Icons.info_outline_rounded,
                      title: t.about,
                      muted: true,
                      onTap: () => Navigator.pushNamed(
                          context, AboutUsScreen.routeName)),
                  _DrawerTile(
                      icon: Icons.description_outlined,
                      title: t.terms,
                      muted: true,
                      onTap: () => Navigator.pushNamed(
                          context, AboutUsScreen.termsRouteName)),
                  _DrawerTile(
                      icon: Icons.privacy_tip_outlined,
                      title: t.privacy,
                      muted: true,
                      onTap: () => Navigator.pushNamed(
                          context, AboutUsScreen.privacyRouteName)),
                  if (userdata != null)
                    _DrawerTile(
                        icon: Icons.delete_forever_outlined,
                        title: t.deleteaccount,
                        danger: true,
                        onTap: showDeleteAccountAlert),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPrayerCommunity() {
    if (userdata == null) {
      showPrayerGuestPrompt(context);
    } else if (userdata!.activated == 1) {
      showDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(t.updateprofile),
          content: Text(t.updateprofilehint),
          actions: [
            CupertinoDialogAction(
                child: Text(t.cancel),
                onPressed: () => Navigator.of(context).pop()),
            CupertinoDialogAction(
              child: Text(t.ok),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, UpdateUserProfile.routeName);
              },
            ),
          ],
        ),
      );
    } else {
      Navigator.pushNamed(context, PrayerCommunityScreen.routeName);
    }
  }

  Future<void> showLogoutAlert() async {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (BuildContext context) => _PremiumLogoutDialog(
        title: t.logoutfromapp,
        message:
            'You will be signed out of your account. You can still browse public church content, but posting prayer requests, responding, and using member features will require signing in again.',
        onConfirm: () {
          Navigator.of(context).pop();
          appManager.unsetUserData();
        },
      ),
    );
  }

  Future<void> showDeleteAccountAlert() async {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (BuildContext context) => PremiumConfirmDialog(
        title: t.deleteaccount,
        message:
            'This will permanently remove your MFM Triumphant Church account, profile, and personal app data. This action cannot be undone.',
        cancelLabel: t.cancel,
        confirmLabel: 'Delete',
        icon: Icons.delete_forever_rounded,
        confirmIcon: Icons.delete_outline_rounded,
        isDanger: true,
        onConfirm: () {
          Navigator.of(context).pop();
          deleteAccountServer(userdata!.email!);
        },
      ),
    );
  }

  Future<void> deleteAccountServer(String email) async {
    Alerts.showProgressDialog(context, t.processingpleasewait);
    try {
      final response = await Dio().post(ApiUrl.DELETE_ACCOUNT,
          data: jsonEncode({
            "data": {
              "email": email,
              "api_token": userdata?.apiToken ?? "",
            }
          }));
      Navigator.of(context).pop();
      if (response.statusCode == 200) {
        Alerts.show(context, "", t.deleteaccountsuccess);
        appManager.unsetUserData();
      } else {
        Alerts.show(context, "", t.error);
      }
    } catch (exception) {
      Navigator.of(context).pop();
      Alerts.show(context, "", exception.toString());
    }
  }

  Future<void> requestReview() async {
    final inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      inAppReview.requestReview();
    }
  }

  void showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          scrollable: true,
          title: Text(t.chooseapplanguage),
          content: SizedBox(
            height: 250,
            width: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: appLanguageData.length,
              itemBuilder: (BuildContext context, int index) {
                final name =
                    appLanguageData[AppLanguage.values[index]]!['name']!;
                final selected = index == appManager.preferredLanguage;
                return ListTile(
                  trailing: selected
                      ? const Icon(Icons.check)
                      : const SizedBox.shrink(),
                  title: Text(name),
                  onTap: () {
                    appManager.setAppLanguage(index);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _PremiumLogoutDialog extends StatelessWidget {
  const _PremiumLogoutDialog({
    required this.title,
    required this.message,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF102532) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF102532);
    final muted = isDark ? Colors.white70 : const Color(0xFF60707A);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: card,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.18),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _LogoutDialogGraphicPainter()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFC857), Color(0xFFFFB522)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB522)
                                .withValues(alpha: isDark ? 0.26 : 0.34),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFF0C2230),
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: text,
                        fontSize: 21,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: muted,
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: text,
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : const Color(0xFFE4EBEF),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            child: Text(t.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onConfirm,
                            icon: const Icon(Icons.check_rounded, size: 19),
                            label: Text(t.logout),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB522),
                              foregroundColor: const Color(0xFF0C2230),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutDialogGraphicPainter extends CustomPainter {
  const _LogoutDialogGraphicPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final goldFill = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFC857).withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.12, size.height * 0.08),
        radius: size.width * 0.72,
      ));
    final tealFill = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0C2230).withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.94, size.height * 0.08),
        radius: size.width * 0.58,
      ));
    final line = Paint()
      ..color = const Color(0xFFFFC857).withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawRect(Offset.zero & size, goldFill);
    canvas.drawRect(Offset.zero & size, tealFill);
    canvas.drawCircle(Offset(size.width * 0.96, size.height * 0.02), 76, line);
    canvas.drawCircle(Offset(size.width * 0.96, size.height * 0.02), 118, line);

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.9)
      ..cubicTo(size.width * 0.28, size.height * 0.72, size.width * 0.48,
          size.height * 1.02, size.width * 0.68, size.height * 0.82)
      ..cubicTo(size.width * 0.82, size.height * 0.68, size.width * 0.9,
          size.height * 0.9, size.width * 1.04, size.height * 0.74);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _LogoutDialogGraphicPainter oldDelegate) =>
      false;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.userdata});

  final Userdata? userdata;

  @override
  Widget build(BuildContext context) {
    final avatar = userdata?.avatar ?? '';
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.7), width: 3),
      ),
      child: ClipOval(
        child: avatar.isNotEmpty
            ? Image.network(avatar, fit: BoxFit.cover)
            : Image.asset('assets/icon/icon.png', fit: BoxFit.cover),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection({required this.card, required this.children});

  final Color card;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.18
                    : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.muted = false,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool muted;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = danger
        ? Colors.redAccent
        : (isDark ? Colors.white : const Color(0xFF102532));
    final iconColor = danger
        ? Colors.redAccent
        : (isDark
            ? const Color(0xFFFFC857)
            : (muted ? Colors.grey[600] : MyColors.primary));

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      horizontalTitleGap: 10,
      minLeadingWidth: 22,
      leading: Icon(icon, color: iconColor),
      title: Text(title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: text, fontSize: 16, fontWeight: FontWeight.w700)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: isDark ? Colors.white30 : Colors.black26),
      onTap: onTap,
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    required this.muted,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      horizontalTitleGap: 10,
      minLeadingWidth: 22,
      leading: Icon(icon,
          color: isDark ? const Color(0xFFFFC857) : MyColors.primary),
      title: Text(title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF102532),
              fontSize: 16,
              fontWeight: FontWeight.w700)),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 86),
        child: Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
                color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
      onTap: onTap,
    );
  }
}
