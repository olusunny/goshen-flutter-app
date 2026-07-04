import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../providers/AudioPlayerModel.dart';
import '../providers/AppStateManager.dart';
import '../prayers/prayer_community_screen.dart';
import '../prayers/prayer_guest_prompt.dart';
import '../screens/DrawerScreen.dart';
import '../screens/MoreMenuScreen.dart';
import '../widgets/premium_confirm_dialog.dart';
import 'Home.dart';

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);
  static const routeName = '/homescreen';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _handleBackPress(context);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        key: scaffoldKey,
        body: MyHomePage(
          onMenuTap: () => scaffoldKey.currentState?.openDrawer(),
        ),
        drawer: Container(
          color: Colors.white,
          width: 300,
          child: Drawer(child: DrawerScreen()),
        ),
        bottomNavigationBar: CustomBottomNavBar(
          onMenuTap: () =>
              Navigator.pushNamed(context, MoreMenuScreen.routeName),
          onPrayerTap: () {
            final user =
                Provider.of<AppStateManager>(context, listen: false).userdata;
            if (user == null) {
              showPrayerGuestPrompt(context);
              return;
            }
            Navigator.pushNamed(context, PrayerCommunityScreen.routeName);
          },
        ),
      ),
    );
  }

  Future<bool> _handleBackPress(BuildContext context) async {
    if (Provider.of<AudioPlayerModel>(context, listen: false).currentMedia !=
        null) {
      return (await showDialog<bool>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.58),
            builder: (context) => PremiumConfirmDialog(
              title: t.quitapp,
              message: t.quitappaudiowarning,
              cancelLabel: t.cancel,
              confirmLabel: t.ok,
              icon: Icons.music_note_rounded,
              confirmIcon: Icons.exit_to_app_rounded,
              onConfirm: () {
                Provider.of<AudioPlayerModel>(context, listen: false)
                    .cleanUpResources();
                Navigator.of(context).pop(true);
              },
            ),
          )) ??
          false;
    }

    return (await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.58),
          builder: (context) => PremiumConfirmDialog(
            title: t.quitapp,
            message:
                'Do you want to close MFM Triumphant Church now? You can reopen the app anytime to continue from where you stopped.',
            cancelLabel: t.cancel,
            confirmLabel: t.ok,
            icon: Icons.power_settings_new_rounded,
            confirmIcon: Icons.exit_to_app_rounded,
            onConfirm: () {
              SystemNavigator.pop();
              Navigator.of(context).pop(true);
            },
          ),
        )) ??
        false;
  }
}

class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({
    Key? key,
    required this.onMenuTap,
    required this.onPrayerTap,
  }) : super(key: key);

  final VoidCallback onMenuTap;
  final VoidCallback onPrayerTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: bottomInset > 0 ? 8 : 10),
      child: Container(
        height: 78,
        margin: const EdgeInsets.symmetric(horizontal: 0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 22,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: _BottomNavItem(
                    icon: Icons.layers_outlined,
                    label: 'Home',
                    active: true,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 82),
                Expanded(
                  child: _BottomNavItem(
                    icon: Icons.more_horiz_rounded,
                    label: 'Menu',
                    onTap: onMenuTap,
                  ),
                ),
              ],
            ),
            Positioned(
              top: -22,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(36),
                  onTap: onPrayerTap,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF0C2230), Color(0xFF1A4B5C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x400C2230),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF173A49) : const Color(0xFF60707A);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
