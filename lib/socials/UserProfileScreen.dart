import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../models/ScreenArguements.dart';
import '../models/Userdata.dart';
import '../providers/AppStateManager.dart';
import '../screens/GoshenExperienceScreen.dart';
import '../screens/GoshenRetreatScreen.dart';
import '../screens/GoshenWalletScreen.dart';
import '../socials/UpdateUserProfile.dart';
import '../utils/Utility.dart';
import '../utils/img.dart';
import '../utils/my_colors.dart';
import '../utils/member_profile_presentation.dart';
import '../widgets/country_selector.dart';

class UserProfileScreen extends StatelessWidget {
  static String routeName = "/userprofile";

  const UserProfileScreen({Key? key, this.user}) : super(key: key);

  final Userdata? user;

  @override
  Widget build(BuildContext context) {
    final appUser = Provider.of<AppStateManager>(context).userdata;
    final profile = user ?? appUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA);
    final card = isDark ? const Color(0xFF102532) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF102532);
    final muted = isDark ? Colors.white60 : const Color(0xFF60707A);
    final isOwnProfile = appUser?.email == profile?.email;

    return Scaffold(
      backgroundColor: background,
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 270,
                  pinned: true,
                  backgroundColor: const Color(0xFF0C2230),
                  title: Text(profile.name ?? 'Profile'),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        _ProfileImage(
                          url: profile.coverPhoto ?? '',
                          fallback: Img.get('cover_photos.jpg'),
                          fit: BoxFit.cover,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.32),
                                Colors.black.withValues(alpha: 0.05),
                                Colors.black.withValues(alpha: 0.58),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(18, 88, 18, 18),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: isDark ? 0.22 : 0.08),
                                  blurRadius: 28,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                Positioned(
                                  top: -74,
                                  child: Container(
                                    width: 118,
                                    height: 118,
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: ClipOval(
                                      child: _ProfileImage(
                                        url: profile.avatar ?? '',
                                        fallback: Img.get('avatar.png'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
                                  children: [
                                    const SizedBox(height: 58),
                                    Text(
                                      profile.name ?? '',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: text,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      profile.email ?? '',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 14,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _TriumphantIdBadge(
                                      id: profile.triumphantId ?? '',
                                      memberType: profile.memberType ?? '',
                                      text: text,
                                      muted: muted,
                                    ),
                                    if (isOwnProfile) ...[
                                      const SizedBox(height: 18),
                                      SizedBox(
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pushReplacementNamed(
                                              context,
                                              UpdateUserProfile.routeName,
                                              arguments: ScreenArguements(
                                                  check: false),
                                            );
                                          },
                                          icon: const Icon(Icons.edit_outlined),
                                          label: Text(t.updateprofile),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFFFFB522),
                                            foregroundColor: MyColors.primary,
                                            textStyle: const TextStyle(
                                                fontWeight: FontWeight.w800),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isOwnProfile) ...[
                            _ProfileActionCard(
                              card: card,
                              text: text,
                              muted: muted,
                              icon: Icons.person_search_outlined,
                              iconColor: const Color(0xFF2C9B88),
                              title: 'Profile Details',
                              subtitle:
                                  'View your contact, residence, and profile information.',
                              onTap: () => Navigator.pushNamed(
                                context,
                                ProfileDetailsScreen.routeName,
                                arguments: ScreenArguements(items: profile),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _ProfileActionCard(
                              card: card,
                              text: text,
                              muted: muted,
                              icon: Icons.event_available_rounded,
                              iconColor: const Color(0xFF2C9B88),
                              title: 'My Goshen Status',
                              subtitle:
                                  'Registrations, tickets, payments, and follow-up.',
                              onTap: () => Navigator.pushNamed(
                                context,
                                GoshenMyRegistrationScreen.routeName,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ProfileActionCard(
                              card: card,
                              text: text,
                              muted: muted,
                              icon: Icons.account_balance_wallet_outlined,
                              iconColor: const Color(0xFFFFB522),
                              title: 'My Wallet',
                              subtitle:
                                  'Save towards Goshen Retreat and manage auto top-up.',
                              onTap: () => Navigator.pushNamed(
                                context,
                                GoshenWalletScreen.routeName,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ProfileActionCard(
                              card: card,
                              text: text,
                              muted: muted,
                              icon: Icons.celebration_rounded,
                              iconColor: const Color(0xFF2C9B88),
                              title: 'Goshen Experience',
                              subtitle:
                                  'Share feedback, testimony, audio, or video after check-in.',
                              onTap: () => Navigator.pushNamed(
                                context,
                                GoshenExperienceScreen.routeName,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class ProfileDetailsScreen extends StatelessWidget {
  static const routeName = '/profile-details';

  const ProfileDetailsScreen({super.key, this.user});

  final Userdata? user;

  @override
  Widget build(BuildContext context) {
    final appUser = Provider.of<AppStateManager>(context).userdata;
    final profile = user ?? appUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA);
    final card = isDark ? const Color(0xFF102532) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF102532);
    final muted = isDark ? Colors.white60 : const Color(0xFF60707A);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Profile Details'),
        backgroundColor: const Color(0xFF0C2230),
        foregroundColor: Colors.white,
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                _InfoCard(
                  card: card,
                  text: text,
                  muted: muted,
                  children: [
                    _InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: t.gender,
                      value: _fallback(profile.gender),
                    ),
                    _InfoRow(
                      icon: Icons.public_rounded,
                      label: 'Country of residence',
                      value: _countryResidence(profile.countryOfResidence),
                    ),
                    _InfoRow(
                      icon: Icons.map_outlined,
                      label: _regionLabel(profile.countryOfResidence),
                      value: _fallback(profile.stateCountyProvince),
                    ),
                    _InfoRow(
                      icon: Icons.email_outlined,
                      label: t.emailaddress,
                      value: _fallback(profile.email),
                    ),
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: t.phonenumber,
                      value: _fallback(profile.phone),
                    ),
                    _InfoRow(
                      icon: Icons.auto_awesome_outlined,
                      label: t.aboutme,
                      value: (profile.aboutMe?.isEmpty ?? true)
                          ? '-----'
                          : Utility.getBase64DecodedString(profile.aboutMe!),
                      multiline: true,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  String _fallback(String? value) {
    return value == null || value.trim().isEmpty ? '-----' : value;
  }

  String _countryResidence(String? value) {
    final country = value?.trim() ?? '';
    return country.isEmpty ? '-----' : '${countryFlag(country)} $country';
  }

  String _regionLabel(String? country) {
    switch ((country ?? '').trim().toLowerCase()) {
      case 'nigeria':
      case 'ghana':
      case 'south africa':
      case 'australia':
      case 'united states':
        return 'State';
      case 'united kingdom':
        return 'Country';
      case 'canada':
        return 'Province';
      default:
        return 'State / county / province';
    }
  }
}

class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({
    required this.card,
    required this.text,
    required this.muted,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color card;
  final Color text;
  final Color muted;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: iconColor, size: 27),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TriumphantIdBadge extends StatelessWidget {
  const _TriumphantIdBadge({
    required this.id,
    required this.memberType,
    required this.text,
    required this.muted,
  });

  final String id;
  final String memberType;
  final Color text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final value = triumphantIdStatusMessage(
      memberType: memberType,
      triumphantId: id,
    );
    final detail = triumphantIdStatusDetail(
      memberType: memberType,
      triumphantId: id,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFFFFB522).withValues(alpha: 0.14)
            : const Color(0xFFFFF4D8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFB522).withValues(alpha: isDark ? 0.35 : 0.5),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB522).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.badge_outlined,
                color: isDark ? const Color(0xFFFFC857) : MyColors.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Triumphant ID',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileImage extends StatelessWidget {
  const _ProfileImage(
      {required this.url, required this.fallback, required this.fit});

  final String url;
  final String fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Image.asset(fallback, fit: fit);
    }
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, __, ___) => Image.asset(fallback, fit: fit),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.card,
    required this.text,
    required this.muted,
    required this.children,
  });

  final Color card;
  final Color text;
  final Color muted;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.18
                    : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE7EEF2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: isDark ? const Color(0xFFFFC857) : MyColors.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF60707A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: multiline ? 5 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF102532),
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
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
