import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';

import '../features/fundraising/fundraising_screen.dart';
import '../features/counseling/counseling_screen.dart';
import '../i18n/strings.g.dart';
import '../prayers/prayer_community_screen.dart';
import '../prayers/prayer_guest_prompt.dart';
import '../prayers/prayer_points_screen.dart';
import '../providers/AppStateManager.dart';
import '../providers/HomeProvider.dart';
import '../screens/AboutUsScreen.dart';
import '../screens/BookmarkScreen.dart';
import '../screens/ContactUsScreen.dart';
import '../screens/DonationAccountsScreen.dart';
import '../screens/DevotionalScreen.dart';
import '../screens/Downloader.dart';
import '../screens/DynamicFormsScreen.dart';
import '../screens/GalleryScreen.dart';
import '../screens/GoshenExperienceScreen.dart';
import '../screens/GoshenManagementHubScreen.dart';
import '../screens/GoshenQuizScreen.dart';
import '../screens/GoshenScannerManagerScreen.dart';
import '../screens/GoshenRetreatScreen.dart';
import '../screens/GoshenWalletScreen.dart';
import '../screens/GroupsScreen.dart';
import '../screens/HymnsListScreen.dart';
import '../screens/ManageGroupsScreen.dart';
import '../screens/PastorsScreen.dart';
import '../screens/PlaylistsScreen.dart';
import '../screens/SuggestionScreen.dart';
import '../service/MoreMenuPreloadService.dart';
import '../socials/Settings.dart';
import '../socials/UpdateUserProfile.dart';
import '../testimonies/testimony_wall_screen.dart';

class MoreMenuScreen extends StatefulWidget {
  const MoreMenuScreen({super.key});

  static const routeName = '/more-menu';

  @override
  State<MoreMenuScreen> createState() => _MoreMenuScreenState();
}

class _MoreMenuScreenState extends State<MoreMenuScreen> {
  bool _testimoniesEnabled = false;
  bool _goshenRetreatEnabled = false;
  bool _fundraisingEnabled = false;
  bool _prayerPointsEnabled = true;
  bool _interactivePrayerWallEnabled = true;
  bool _hymnsEnabled = true;
  bool _devotionalsEnabled = true;
  bool _churchGroupsEnabled = true;
  bool _dynamicFormsEnabled = true;
  bool _goshenQuizEnabled = true;
  bool _scannerManagerEnabled = false;
  bool _scannerConsoleEnabled = false;

  @override
  void initState() {
    super.initState();
    _applySnapshot(MoreMenuPreloadService.instance.snapshot);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFeatureFlags());
  }

  Future<void> _refreshFeatureFlags() async {
    if (!mounted) return;

    Map<String, dynamic>? homeData;
    try {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      homeData = homeProvider.data;
    } catch (_) {}

    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    final snapshot = await MoreMenuPreloadService.instance.warm(
      user: user,
      homeData: homeData,
    );
    _applySnapshot(snapshot);
  }

  void _applySnapshot(MoreMenuPreloadSnapshot? snapshot) {
    if (snapshot == null) return;

    if (mounted &&
        (_testimoniesEnabled != snapshot.testimoniesEnabled ||
            _goshenRetreatEnabled != snapshot.goshenRetreatEnabled ||
            _fundraisingEnabled != snapshot.fundraisingEnabled ||
            _prayerPointsEnabled != snapshot.prayerPointsEnabled ||
            _interactivePrayerWallEnabled !=
                snapshot.interactivePrayerWallEnabled ||
            _hymnsEnabled != snapshot.hymnsEnabled ||
            _devotionalsEnabled != snapshot.devotionalsEnabled ||
            _churchGroupsEnabled != snapshot.churchGroupsEnabled ||
            _dynamicFormsEnabled != snapshot.dynamicFormsEnabled ||
            _goshenQuizEnabled != snapshot.goshenQuizEnabled ||
            _scannerManagerEnabled != snapshot.scannerManagerEnabled ||
            _scannerConsoleEnabled != snapshot.scannerConsoleEnabled)) {
      setState(() {
        _testimoniesEnabled = snapshot.testimoniesEnabled;
        _goshenRetreatEnabled = snapshot.goshenRetreatEnabled;
        _fundraisingEnabled = snapshot.fundraisingEnabled;
        _prayerPointsEnabled = snapshot.prayerPointsEnabled;
        _interactivePrayerWallEnabled = snapshot.interactivePrayerWallEnabled;
        _hymnsEnabled = snapshot.hymnsEnabled;
        _devotionalsEnabled = snapshot.devotionalsEnabled;
        _churchGroupsEnabled = snapshot.churchGroupsEnabled;
        _dynamicFormsEnabled = snapshot.dynamicFormsEnabled;
        _goshenQuizEnabled = snapshot.goshenQuizEnabled;
        _scannerManagerEnabled = snapshot.scannerManagerEnabled;
        _scannerConsoleEnabled = snapshot.scannerConsoleEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppStateManager>(context).userdata;
    final colors = _MorePalette.of(context);
    final bottomPadding = 28 + MediaQuery.viewPaddingOf(context).bottom;
    final canManageGoshenRegistration =
        user?.canManageGoshenRegistrationTools == true;
    final canManageGoshenVouchers = user?.canManageGoshenVoucherTools == true;
    final canManageFundraising = user?.canManageFundraisingTools == true;
    final canManageQuiz = user?.canManageQuizTools == true;
    final canViewSurveyStats = user?.canViewGoshenExperienceStats == true;
    final canManageWalletWithdrawals =
        user?.canManageWalletWithdrawalTools == true;
    final canManageDynamicForms = user?.canManageDynamicFormTools == true;
    final canManageChurchEvents = user?.canManageChurchEventTools == true;
    final canManageVerseOfDay = user?.canManageVerseOfDayTools == true;
    final canSendAdminMessages = user?.canSendAdminMessageTools == true;
    final canOpenGoshenManagement = user != null &&
        (_scannerManagerEnabled ||
            _scannerConsoleEnabled ||
            canManageGoshenRegistration ||
            canManageGoshenVouchers ||
            canManageFundraising ||
            canManageQuiz ||
            canViewSurveyStats ||
            canManageWalletWithdrawals ||
            canManageDynamicForms ||
            canManageChurchEvents ||
            canManageVerseOfDay ||
            canSendAdminMessages);
    final items = <_MoreMenuItem>[
      if (canOpenGoshenManagement)
        _MoreMenuItem(
            'Control Hub',
            Icons.admin_panel_settings_rounded,
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GoshenManagementHubScreen(
                      user: user,
                      canUseScannerConsole: _scannerConsoleEnabled,
                      canManageScanners: _scannerManagerEnabled,
                      canManageRegistration: canManageGoshenRegistration,
                      canManageVouchers: canManageGoshenVouchers,
                      canManageFundraising: canManageFundraising,
                      canManageWalletWithdrawals: canManageWalletWithdrawals,
                      canManageDynamicForms: canManageDynamicForms,
                      canManageChurchEvents: canManageChurchEvents,
                      canSendAdminMessages: canSendAdminMessages,
                    ),
                  ),
                ),
            accent: const Color(0xFFFFC857),
            featured: true),
      _MoreMenuItem('Giving', Icons.volunteer_activism_outlined,
          () => Navigator.pushNamed(context, DonationAccountsScreen.routeName),
          accent: const Color(0xFFE1A63B)),
      if (_dynamicFormsEnabled)
        _MoreMenuItem('Forms', Icons.dynamic_form_rounded,
            () => Navigator.pushNamed(context, DynamicFormsScreen.routeName),
            accent: const Color(0xFF2C9B88)),
      if (_fundraisingEnabled)
        _MoreMenuItem('Project support', Icons.campaign_rounded,
            () => Navigator.pushNamed(context, FundraisingScreen.routeName),
            accent: const Color(0xFFE1A63B)),
      if (_goshenRetreatEnabled)
        _MoreMenuItem('Goshen Retreat', Icons.event_available_rounded,
            () => Navigator.pushNamed(context, GoshenRetreatScreen.routeName),
            accent: const Color(0xFF2C9B88)),
      if (_goshenRetreatEnabled && user != null)
        _MoreMenuItem('My Wallet', Icons.account_balance_wallet_outlined,
            () => Navigator.pushNamed(context, GoshenWalletScreen.routeName),
            accent: const Color(0xFFFFC857)),
      if (_goshenRetreatEnabled && user != null)
        _MoreMenuItem(
            'Goshen Experience',
            Icons.celebration_rounded,
            () =>
                Navigator.pushNamed(context, GoshenExperienceScreen.routeName),
            accent: const Color(0xFF2C9B88)),
      if (_goshenRetreatEnabled && _goshenQuizEnabled && user != null)
        _MoreMenuItem('Goshen Quiz', Icons.quiz_rounded,
            () => Navigator.pushNamed(context, GoshenQuizScreen.routeName),
            accent: const Color(0xFFFFC857)),
      if (_goshenRetreatEnabled && _scannerConsoleEnabled && user != null)
        _MoreMenuItem(
            'Scanner Console',
            Icons.qr_code_scanner_rounded,
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GoshenScannerScreen(user: user),
                  ),
                ),
            accent: const Color(0xFFFFC857)),
      if (_goshenRetreatEnabled && _scannerManagerEnabled && user != null)
        _MoreMenuItem(
            'Manage Scanners',
            Icons.manage_accounts_rounded,
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GoshenScannerManagerScreen(user: user),
                  ),
                ),
            accent: const Color(0xFFFFC857)),
      if (_devotionalsEnabled)
        _MoreMenuItem('Devotional', Icons.auto_stories_rounded,
            () => Navigator.pushNamed(context, DevotionalScreen.routeName),
            accent: const Color(0xFFFFC857)),
      if (_hymnsEnabled)
        _MoreMenuItem('Hymns', Icons.library_music_outlined,
            () => Navigator.pushNamed(context, HymnsListScreen.routeName),
            accent: const Color(0xFF2C9B88)),
      _MoreMenuItem(t.myplaylists, Icons.playlist_play_rounded,
          () => Navigator.pushNamed(context, PlaylistsScreen.routeName)),
      _MoreMenuItem(t.bookmarks, Icons.collections_bookmark_outlined,
          () => Navigator.pushNamed(context, BookmarksScreen.routeName)),
      if (_prayerPointsEnabled)
        _MoreMenuItem('Prayer Points', Icons.menu_book_rounded,
            () => Navigator.pushNamed(context, PrayerPointsScreen.routeName),
            accent: const Color(0xFFFFC857)),
      if (_interactivePrayerWallEnabled)
        _MoreMenuItem('Interactive Prayer Wall',
            Icons.volunteer_activism_outlined, () => _openPrayer(context)),
      if (user != null)
        _MoreMenuItem('Counseling', Icons.health_and_safety_outlined,
            () => Navigator.pushNamed(context, CounselingScreen.routeName),
            accent: const Color(0xFFFFC857)),
      if (_testimoniesEnabled)
        _MoreMenuItem('Testimonies & Thanksgiving', Icons.auto_awesome_rounded,
            () => Navigator.pushNamed(context, TestimonyWallScreen.routeName),
            accent: const Color(0xFFFFC857)),
      _MoreMenuItem('Church Pastors', Icons.groups_2_outlined,
          () => Navigator.pushNamed(context, PastorsScreen.routeName)),
      if (_churchGroupsEnabled)
        _MoreMenuItem('Church Groups', Icons.diversity_3_outlined,
            () => Navigator.pushNamed(context, GroupsScreen.routeName)),
      if (user?.canManageChurchGroups == true)
        _MoreMenuItem('Manage Groups', Icons.admin_panel_settings_outlined,
            () => Navigator.pushNamed(context, ManageGroupsScreen.routeName),
            accent: const Color(0xFF2C9B88)),
      _MoreMenuItem('Gallery', Icons.photo_library_outlined,
          () => Navigator.pushNamed(context, GalleryScreen.routeName)),
      _MoreMenuItem('Downloads', Icons.download_for_offline_outlined,
          () => Navigator.pushNamed(context, Downloader.routeName)),
      _MoreMenuItem('Suggestions', Icons.lightbulb_outline_rounded,
          () => Navigator.pushNamed(context, SuggestionScreen.routeName),
          accent: const Color(0xFF8B5CF6)),
      _MoreMenuItem('Contact Us', Icons.support_agent_outlined,
          () => Navigator.pushNamed(context, ContactUsScreen.routeName)),
      _MoreMenuItem('Notifications', Icons.notifications_active_outlined,
          () => Navigator.pushNamed(context, SettingsScreen.routeName),
          accent: const Color(0xFF2C9B88)),
      _MoreMenuItem(t.about, Icons.info_outline_rounded,
          () => Navigator.pushNamed(context, AboutUsScreen.routeName)),
      _MoreMenuItem(t.terms, Icons.description_outlined,
          () => Navigator.pushNamed(context, AboutUsScreen.termsRouteName)),
      _MoreMenuItem(t.privacy, Icons.privacy_tip_outlined,
          () => Navigator.pushNamed(context, AboutUsScreen.privacyRouteName)),
      _MoreMenuItem(t.rate, Icons.rate_review_outlined, () => _requestReview()),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('More')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                margin: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0C2230), Color(0xFF17465A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: CustomPaint(painter: _MenuHeroGraphicPainter()),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: const Icon(
                              Icons.dashboard_customize_outlined,
                              color: Color(0xFFFFC857),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Church app menu',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    height: 1.05,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'All tools and pages in one place',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, bottomPadding),
            sliver: SliverGrid.builder(
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 172,
              ),
              itemBuilder: (context, index) {
                return _MoreMenuCard(item: items[index], colors: colors);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openPrayer(BuildContext context) {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) {
      showPrayerGuestPrompt(context);
      return;
    }
    if (!user.isVerified) {
      showDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(t.updateprofile),
          content: Text(t.updateprofilehint),
          actions: [
            CupertinoDialogAction(
              child: Text(t.cancel),
              onPressed: () => Navigator.of(context).pop(),
            ),
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
      return;
    }
    Navigator.pushNamed(context, PrayerCommunityScreen.routeName);
  }

  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      review.requestReview();
    }
  }
}

class _MoreMenuCard extends StatelessWidget {
  const _MoreMenuCard({required this.item, required this.colors});

  final _MoreMenuItem item;
  final _MorePalette colors;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    final textColor = item.featured ? Colors.white : colors.text;
    final mutedColor =
        item.featured ? Colors.white.withValues(alpha: 0.74) : colors.muted;
    final iconColor = item.featured ? const Color(0xFF0C2230) : item.accent;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: item.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: item.featured
                ? const LinearGradient(
                    colors: [Color(0xFF0C2230), Color(0xFF155D50)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      colors.card,
                      Color.lerp(colors.card, item.accent,
                          colors.isDark ? 0.14 : 0.04)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(
              color: item.featured
                  ? const Color(0xFFFFC857).withValues(alpha: 0.62)
                  : colors.isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.72),
              width: item.featured ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: item.featured
                    ? const Color(0xFF0C2230).withValues(alpha: 0.22)
                    : Colors.black
                        .withValues(alpha: colors.isDark ? 0.26 : 0.07),
                blurRadius: item.featured ? 28 : 22,
                offset: Offset(0, item.featured ? 16 : 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MenuCardGraphicPainter(
                      accent: item.accent,
                      isDark: colors.isDark || item.featured,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: item.featured
                              ? const Color(0xFFFFC857)
                              : item.accent.withValues(
                                  alpha: colors.isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: item.featured
                                ? Colors.white.withValues(alpha: 0.16)
                                : item.accent.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Icon(item.icon, color: iconColor, size: 24),
                      ),
                      if (item.featured) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            'Management tools',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: item.featured ? 19 : 16,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: colors.isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : item.featured
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFF1F5F8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: mutedColor,
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuHeroGraphicPainter extends CustomPainter {
  const _MenuHeroGraphicPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = const Color(0xFFFFC857).withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final teal = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFC857).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.88, size.height * 0.12),
        radius: size.width * 0.42,
      ));

    canvas.drawRect(Offset.zero & size, glow);
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.12), 78, teal);
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.12), 118, teal);

    final path = Path()
      ..moveTo(size.width * 0.58, size.height * 0.18)
      ..cubicTo(size.width * 0.72, size.height * 0.02, size.width * 0.84,
          size.height * 0.35, size.width * 1.04, size.height * 0.12)
      ..moveTo(size.width * 0.62, size.height * 0.72)
      ..cubicTo(size.width * 0.74, size.height * 0.54, size.width * 0.86,
          size.height * 0.94, size.width * 1.02, size.height * 0.68);
    canvas.drawPath(path, gold);

    final dotPaint = Paint()
      ..color = const Color(0xFFFFC857).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width * (0.68 + i * 0.055), size.height * 0.38),
        3.5,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MenuHeroGraphicPainter oldDelegate) => false;
}

class _MenuCardGraphicPainter extends CustomPainter {
  const _MenuCardGraphicPainter({
    required this.accent,
    required this.isDark,
  });

  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final softAccent = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.09 : 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final fillAccent = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.08 : 0.045)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.1),
      size.width * 0.42,
      fillAccent,
    );

    final wave = Path()
      ..moveTo(size.width * 0.58, size.height * 0.18)
      ..quadraticBezierTo(size.width * 0.82, size.height * 0.06,
          size.width * 1.05, size.height * 0.28)
      ..moveTo(size.width * 0.5, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.78, size.height * 0.58,
          size.width * 1.04, size.height * 0.84);
    canvas.drawPath(wave, softAccent);

    final gridPaint = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.08 : 0.04)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.68 + i * 0.08);
      canvas.drawLine(
        Offset(x, size.height * 0.2),
        Offset(x, size.height * 0.5),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MenuCardGraphicPainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.isDark != isDark;
  }
}

class _MoreMenuItem {
  const _MoreMenuItem(
    this.title,
    this.icon,
    this.onTap, {
    this.accent = const Color(0xFF2C9B88),
    this.featured = false,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  final bool featured;
}

class _MorePalette {
  const _MorePalette({
    required this.isDark,
    required this.background,
    required this.card,
    required this.text,
    required this.muted,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color text;
  final Color muted;

  static _MorePalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _MorePalette(
      isDark: isDark,
      background: isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
      card: isDark ? const Color(0xFF102532) : Colors.white,
      text: isDark ? Colors.white : const Color(0xFF102532),
      muted: isDark ? Colors.white54 : const Color(0xFF60707A),
    );
  }
}
