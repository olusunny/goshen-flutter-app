import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../audio_player/miniPlayer.dart';
import '../audio_player/player_page.dart';
import '../auth/LoginScreen.dart';
import '../features/counseling/counseling_screen.dart';
import '../models/Events.dart';
import '../models/Media.dart';
import '../models/ScreenArguements.dart';
import '../models/Userdata.dart';
import '../notes/NotesListScreen.dart';
import '../prayers/prayer_community_screen.dart';
import '../prayers/prayer_guest_prompt.dart';
import '../prayers/prayer_points_screen.dart';
import '../providers/AppStateManager.dart';
import '../providers/AudioPlayerModel.dart';
import '../providers/events.dart';
import '../providers/HomeProvider.dart';
import '../screens/AudioScreen.dart';
import '../screens/BibleScreen.dart';
import '../screens/CategoriesScreen.dart';
import '../screens/DevotionalScreen.dart';
import '../screens/DonationAccountsScreen.dart';
import '../screens/EventsListScreen.dart';
import '../screens/EventsViewerScreen.dart';
import '../screens/GalleryScreen.dart';
import '../screens/GoshenRetreatScreen.dart';
import '../screens/HymnsListScreen.dart';
import '../screens/InboxListScreen.dart';
import '../screens/NoitemScreen.dart';
import '../screens/VideoScreen.dart';
import '../socials/UserProfileScreen.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';
import '../video_player/VideoPlayer.dart';
import 'WebViewScreen.dart';
import '../livetvplayer/LivestreamsPlayer.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    Key? key,
    required this.onMenuTap,
  }) : super(key: key);

  final VoidCallback onMenuTap;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final PageController _heroController;
  StreamSubscription? _inboxSubscription;
  int _heroIndex = 0;

  @override
  void initState() {
    super.initState();
    _heroController = PageController(viewportFraction: 0.94);
    _loadHomeForCurrentSession();
    _inboxSubscription = eventBus.on<InboxNotificationsChanged>().listen((_) {
      if (!mounted) return;
      Provider.of<HomeProvider>(context, listen: false).fetchItems();
    });
  }

  Future<void> _loadHomeForCurrentSession() async {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final user = await appState.ensureUserDataLoaded();
    if (!mounted) return;

    await Provider.of<HomeProvider>(context, listen: false).loadItems(
      user: user,
    );
  }

  @override
  void dispose() {
    _heroController.dispose();
    _inboxSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = Provider.of<HomeProvider>(context);
    final appState = Provider.of<AppStateManager>(context);
    final user = appState.userdata;

    return Column(
      children: [
        Expanded(
          child: home.isLoading
              ? const _HomeLoadingState()
              : home.isError
                  ? NoitemScreen(
                      title: 'Ooops!',
                      message:
                          'Could not load requested data at the moment, check your data connection and click to retry.',
                      onClick: home.loadItems,
                    )
                  : _buildHomeContent(context, home, user),
        ),
        const MiniPlayer(),
      ],
    );
  }

  Widget _buildHomeContent(
    BuildContext context,
    HomeProvider home,
    Userdata? user,
  ) {
    final colors = _HomePalette.of(context);
    final sliderItems = (home.data['sliders'] as List<Media>? ?? []);
    final heroItems = sliderItems.isEmpty ? _fallbackMedia : sliderItems;

    return ColoredBox(
      color: colors.background,
      child: RefreshIndicator(
        color: const Color(0xFFFFC857),
        backgroundColor: colors.card,
        onRefresh: home.fetchItems,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 132),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeHeader(
                user: user,
                heroItems: heroItems,
                heroController: _heroController,
                heroIndex: _heroIndex,
                notificationCount:
                    int.tryParse('${home.data['inbox'] ?? 0}') ?? 0,
                onHeroChanged: (index) => setState(() => _heroIndex = index),
                onProfileTap: () => _openProfile(context, user),
                onSettingsTap: widget.onMenuTap,
                onHeroTap: (media) => _openMediaDestination(context, media),
              ),
              HomeActionButtons(
                user: user,
                onPropheticTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrayerCommunityScreen(
                      openPropheticComposerOnLoad: true,
                    ),
                  ),
                ),
              ),
              if (home.data['verse_of_day_enabled'] == true)
                DailyBibleVerseHomeCard(
                  verse: home.data['verse_of_day'],
                  onTap: () => Navigator.pushNamed(
                    context,
                    BibleScreen.routeName,
                  ),
                ),
              ActivityCenterSection(
                goshenRetreatEnabled:
                    home.data['goshen_retreat_enabled'] == true,
                prayerPointsEnabled: home.data['prayer_points_enabled'] == true,
                counselingEnabled: home.data['counseling_enabled'] != false,
                devotionalsEnabled: home.data['devotionals_enabled'] == true,
                onEventsTap: () =>
                    Navigator.pushNamed(context, EventsListScreen.routeName),
                onNotesTap: () =>
                    Navigator.pushNamed(context, NotesListScreen.routeName),
                onDonateTap: () => Navigator.pushNamed(
                  context,
                  DonationAccountsScreen.routeName,
                ),
                onCategoriesTap: () =>
                    Navigator.pushNamed(context, CategoriesScreen.routeName),
                onGalleryTap: () =>
                    Navigator.pushNamed(context, GalleryScreen.routeName),
                onGoshenRetreatTap: () =>
                    Navigator.pushNamed(context, GoshenRetreatScreen.routeName),
                onPrayerPointsTap: () =>
                    Navigator.pushNamed(context, PrayerPointsScreen.routeName),
                onCounselingTap: () =>
                    Navigator.pushNamed(context, CounselingScreen.routeName),
                onDevotionalTap: () =>
                    Navigator.pushNamed(context, DevotionalScreen.routeName),
              ),
              QuickAccessSection(
                onVideosTap: () =>
                    Navigator.pushNamed(context, VideoScreen.routeName),
                onAudiosTap: () =>
                    Navigator.pushNamed(context, AudioScreen.routeName),
                onLivestreamTap: () => Navigator.pushNamed(
                  context,
                  LivestreamsPlayer.routeName,
                  arguments: ScreenArguements(
                    position: 0,
                    items: home.data['livestream'],
                    itemsList: const [],
                  ),
                ),
                onBibleTap: () =>
                    Navigator.pushNamed(context, BibleScreen.routeName),
                onHymnsTap: () =>
                    Navigator.pushNamed(context, HymnsListScreen.routeName),
                hymnsEnabled: home.data['hymns_enabled'] == true,
                onWebsiteTap: () => _openWebsite(context, home.data['website']),
              ),
              if (home.data['interactive_prayer_wall_enabled'] == true)
                PrayerRequestHomeCard(
                  prayerAvatars: (home.data['prayer_request_avatars'] as List?)
                          ?.map((item) => '$item')
                          .where((item) => item.trim().isNotEmpty)
                          .toList() ??
                      const [],
                  onPrayerTap: () {
                    if (user == null) {
                      showPrayerGuestPrompt(context);
                      return;
                    }
                    Navigator.pushNamed(
                        context, PrayerCommunityScreen.routeName);
                  },
                ),
              HomeSocialLinksSection(home: home),
            ],
          ),
        ),
      ),
    );
  }

  void _openProfile(BuildContext context, Userdata? user) {
    Navigator.pushNamed(
      context,
      user == null ? LoginScreen.routeName : UserProfileScreen.routeName,
    );
  }

  void _openBrowserTab(
    BuildContext context,
    String url, {
    required String title,
  }) {
    Navigator.pushNamed(
      context,
      WebViewScreen.routeName,
      arguments: ScreenArguements(url: url, title: title),
    );
  }

  void _openWebsite(BuildContext context, dynamic website) {
    final url = website?.toString().trim() ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The church website has not been configured yet.'),
        ),
      );
      return;
    }

    _openBrowserTab(context, url, title: 'Website');
  }

  void _openMediaDestination(BuildContext context, Media media) {
    if (media.mediaType == 'banner') {
      return;
    }

    if (media.mediaType == 'event') {
      _openFullEventFromHero(context, media);
      return;
    }

    if (media.mediaType == 'video') {
      Navigator.pushNamed(
        context,
        VideoPlayer.routeName,
        arguments: ScreenArguements(
          position: 0,
          items: media,
          itemsList: [media],
        ),
      );
      return;
    }

    Provider.of<AudioPlayerModel>(context, listen: false)
        .preparePlaylist([media], media);
    Navigator.pushNamed(context, PlayPage.routeName);
  }

  Future<void> _openFullEventFromHero(BuildContext context, Media media) async {
    Events? event;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CupertinoActivityIndicator(radius: 18)),
    );

    try {
      final response = await Dio().post(
        ApiUrl.EVENTS,
        data: jsonEncode({"data": {}}),
      );
      final res = decodeApiResponse(response.data);
      final raw = res is Map ? res['events'] : null;
      if (raw is List) {
        final events = raw
            .whereType<Map>()
            .map((json) => Events.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        event = events.firstWhere(
          (item) => item.id == media.id,
          orElse: () => events.firstWhere(
            (item) =>
                (item.title ?? '').trim().toLowerCase() ==
                (media.title ?? '').trim().toLowerCase(),
            orElse: () => _lightweightEvent(media),
          ),
        );
      }
    } catch (_) {
      event = _lightweightEvent(media);
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    Navigator.pushNamed(
      context,
      EventsViewerScreen.routeName,
      arguments: ScreenArguements(items: event ?? _lightweightEvent(media)),
    );
  }

  Events _lightweightEvent(Media media) {
    return Events(
      id: media.id,
      title: media.title,
      thumbnail: media.coverPhoto,
      details: media.description,
      startsAt: media.dateInserted,
      date: (media.dateInserted ?? '').length >= 10
          ? media.dateInserted!.substring(0, 10)
          : '',
      time: '',
      venue: '',
    );
  }
}

class PrayerRequestHomeCard extends StatelessWidget {
  const PrayerRequestHomeCard({
    Key? key,
    required this.prayerAvatars,
    required this.onPrayerTap,
  }) : super(key: key);

  final List<String> prayerAvatars;
  final VoidCallback onPrayerTap;

  @override
  Widget build(BuildContext context) {
    final colors = _HomePalette.of(context);
    final activeAvatars = prayerAvatars.take(5).toList();

    return Container(
      color: colors.background,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Material(
        color: const Color(0xFF0C2230),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPrayerTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF0C2230), Color(0xFF123D35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: const Color(0xFFFFC857).withValues(alpha: 0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0C2230).withValues(alpha: 0.28),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  top: -12,
                  bottom: -8,
                  child: CustomPaint(
                    size: const Size(142, 130),
                    painter: _PrayerCardGraphicPainter(),
                  ),
                ),
                Positioned(
                  right: -38,
                  bottom: -48,
                  child: Container(
                    width: 124,
                    height: 124,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFC857).withValues(alpha: 0.075),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFC857).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: const Color(0xFFFFC857)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.volunteer_activism_outlined,
                            color: Color(0xFFFFC857),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Prayer Requests',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Share your request and let the church stand with you.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 128),
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: onPrayerTap,
                              icon: const Icon(Icons.add_rounded, size: 17),
                              label: const Text('Submit'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC857),
                                foregroundColor: const Color(0xFF0C2230),
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (activeAvatars.isNotEmpty) ...[
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 92,
                            height: 34,
                            child: Stack(
                              children: [
                                for (var i = 0; i < activeAvatars.length; i++)
                                  Positioned(
                                    left: i * 15,
                                    child: CircleAvatar(
                                      radius: 17,
                                      backgroundColor: const Color(0xFF0C2230),
                                      child: CircleAvatar(
                                        radius: 14.5,
                                        backgroundColor: Colors.white,
                                        backgroundImage:
                                            CachedNetworkImageProvider(
                                          activeAvatars[i],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrayerCardGraphicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = const Color(0xFFFFC857).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final linePaint = Paint()
      ..color = const Color(0xFFFFC857).withValues(alpha: 0.23)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final softLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final leftHand = Path()
      ..moveTo(size.width * 0.17, size.height * 0.76)
      ..cubicTo(size.width * 0.27, size.height * 0.55, size.width * 0.38,
          size.height * 0.47, size.width * 0.47, size.height * 0.35)
      ..cubicTo(size.width * 0.50, size.height * 0.32, size.width * 0.55,
          size.height * 0.35, size.width * 0.54, size.height * 0.41)
      ..cubicTo(size.width * 0.51, size.height * 0.55, size.width * 0.42,
          size.height * 0.69, size.width * 0.36, size.height * 0.84);

    final rightHand = Path()
      ..moveTo(size.width * 0.83, size.height * 0.76)
      ..cubicTo(size.width * 0.73, size.height * 0.55, size.width * 0.62,
          size.height * 0.47, size.width * 0.53, size.height * 0.35)
      ..cubicTo(size.width * 0.50, size.height * 0.32, size.width * 0.45,
          size.height * 0.35, size.width * 0.46, size.height * 0.41)
      ..cubicTo(size.width * 0.49, size.height * 0.55, size.width * 0.58,
          size.height * 0.69, size.width * 0.64, size.height * 0.84);

    canvas.drawPath(leftHand, glowPaint);
    canvas.drawPath(rightHand, glowPaint);
    canvas.drawPath(leftHand, linePaint);
    canvas.drawPath(rightHand, linePaint);

    final haloCenter = Offset(size.width * 0.50, size.height * 0.24);
    canvas.drawCircle(haloCenter, size.width * 0.16, softLinePaint);
    canvas.drawCircle(haloCenter, size.width * 0.24, softLinePaint);

    for (final offset in const [
      Offset(0.25, 0.24),
      Offset(0.75, 0.22),
      Offset(0.50, 0.08),
    ]) {
      final center = Offset(size.width * offset.dx, size.height * offset.dy);
      canvas.drawLine(
        Offset(center.dx - 5, center.dy),
        Offset(center.dx + 5, center.dy),
        linePaint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - 5),
        Offset(center.dx, center.dy + 5),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    Key? key,
    required this.user,
    required this.heroItems,
    required this.heroController,
    required this.heroIndex,
    required this.notificationCount,
    required this.onHeroChanged,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onHeroTap,
  }) : super(key: key);

  final Userdata? user;
  final List<Media> heroItems;
  final PageController heroController;
  final int heroIndex;
  final int notificationCount;
  final ValueChanged<int> onHeroChanged;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final ValueChanged<Media> onHeroTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C2230), Color(0xFF102F3D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: onProfileTap,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    backgroundImage: _hasRemoteImage(user?.avatar)
                        ? CachedNetworkImageProvider(
                            user!.avatar!,
                            maxWidth: 144,
                            maxHeight: 144,
                          )
                        : null,
                    child: !_hasRemoteImage(user?.avatar)
                        ? const Icon(Icons.person_outline, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _displayName(user),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _NotificationIcon(
                  count: notificationCount,
                  onTap: () => Navigator.pushNamed(
                      context, InboxListScreenState.routeName),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Menu',
                  onPressed: onSettingsTap,
                  icon:
                      const Icon(Icons.settings_outlined, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 18),
            HeroMediaSlider(
              items: heroItems,
              controller: heroController,
              currentIndex: heroIndex,
              onChanged: onHeroChanged,
              onTap: onHeroTap,
            ),
          ],
        ),
      ),
    );
  }
}

class HeroMediaSlider extends StatefulWidget {
  const HeroMediaSlider({
    Key? key,
    required this.items,
    required this.controller,
    required this.currentIndex,
    required this.onChanged,
    required this.onTap,
  }) : super(key: key);

  final List<Media> items;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final ValueChanged<Media> onTap;

  @override
  State<HeroMediaSlider> createState() => _HeroMediaSliderState();
}

class _HeroMediaSliderState extends State<HeroMediaSlider> {
  static const Duration _autoSlideInterval = Duration(seconds: 5);
  static const Duration _autoSlideDuration = Duration(milliseconds: 520);

  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _restartAutoSlide();
  }

  @override
  void didUpdateWidget(covariant HeroMediaSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length ||
        oldWidget.controller != widget.controller) {
      _restartAutoSlide();
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    super.dispose();
  }

  void _restartAutoSlide() {
    _autoSlideTimer?.cancel();

    if (widget.items.length < 2) {
      return;
    }

    _autoSlideTimer = Timer.periodic(_autoSlideInterval, (_) {
      if (!mounted ||
          !widget.controller.hasClients ||
          widget.items.length < 2) {
        return;
      }

      final nextIndex = (widget.currentIndex + 1) % widget.items.length;
      widget.controller.animateToPage(
        nextIndex,
        duration: _autoSlideDuration,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = widget.items.length;

    return Column(
      children: [
        SizedBox(
          height: 188,
          child: PageView.builder(
            controller: widget.controller,
            itemCount: totalItems,
            onPageChanged: widget.onChanged,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => widget.onTap(item),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _AdaptiveBannerImage(
                          remoteUrl: item.coverPhoto,
                          fallbackAsset: _fallbackAsset(index),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Color(0xB3000000)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.category ?? 'Featured',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.title ?? 'Church update',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            totalItems,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: widget.currentIndex == index ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: widget.currentIndex == index
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DailyBibleVerseHomeCard extends StatelessWidget {
  const DailyBibleVerseHomeCard({
    Key? key,
    required this.verse,
    required this.onTap,
  }) : super(key: key);

  final dynamic verse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasVerse = verse is Map && verse != null;
    final data = hasVerse
        ? Map<String, dynamic>.from(verse as Map)
        : <String, dynamic>{};
    final reference = (data['reference'] ?? '').toString();
    final text = (data['text'] ?? '').toString();
    final version = (data['version'] ?? 'KJV').toString();
    final hasPublishedVerse = reference.isNotEmpty && text.isNotEmpty;

    return Container(
      color: _HomePalette.of(context).background,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: SizedBox(
        height: 188,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: hasPublishedVerse ? onTap : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF071720),
                    Color(0xFF0C2230),
                    Color(0xFF123D35),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: const Color(0xFFFFC857).withValues(alpha: 0.28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06131A).withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -28,
                    top: -26,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFC857).withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: Icon(
                      Icons.auto_stories,
                      size: 82,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC857)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                color: Color(0xFFFFC857),
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Verse of the Day',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (hasPublishedVerse)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  version,
                                  style: const TextStyle(
                                    color: Color(0xFFFFC857),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          hasPublishedVerse
                              ? reference
                              : 'Today\'s verse is pending',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFFC857),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasPublishedVerse
                              ? text
                              : 'Admin can publish today\'s verse from the backend. It refreshes daily at midnight London time.',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

class HomeActionButtons extends StatelessWidget {
  const HomeActionButtons({
    Key? key,
    required this.user,
    required this.onPropheticTap,
  }) : super(key: key);

  final Userdata? user;
  final VoidCallback onPropheticTap;

  @override
  Widget build(BuildContext context) {
    final showProphetic =
        user?.isVerified == true && user?.canManagePropheticDecree == true;
    if (!showProphetic) return const SizedBox.shrink();

    return Transform.translate(
      offset: const Offset(0, -4),
      child: Container(
        color: const Color(0xFF102F3D),
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: _PropheticDecreeHomeCard(onTap: onPropheticTap),
      ),
    );
  }
}

class _PropheticDecreeHomeCard extends StatelessWidget {
  const _PropheticDecreeHomeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFC857),
                Color(0xFFEBAA26),
                Color(0xFF195241),
              ],
              stops: [0.0, 0.42, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.34),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFC857).withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -14,
                top: -18,
                bottom: -18,
                child: CustomPaint(
                  size: const Size(150, 112),
                  painter: _PropheticCardGraphicPainter(),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C2230),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: Color(0xFFFFC857),
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Prophet Decree',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF071720),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Record and publish today\'s prophetic audio.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xCC071720),
                            fontSize: 12.5,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C2230).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropheticCardGraphicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.28);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.09)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.24 + i * 0.12);
      final amplitude = size.height * (0.16 + (i % 2) * 0.07);
      final path = Path()
        ..moveTo(x, size.height * 0.5 - amplitude)
        ..cubicTo(
          x + 12,
          size.height * 0.5 - amplitude * 0.45,
          x - 12,
          size.height * 0.5 + amplitude * 0.45,
          x,
          size.height * 0.5 + amplitude,
        );
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, wavePaint);
    }

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF0C2230).withValues(alpha: 0.16);
    final center = Offset(size.width * 0.78, size.height * 0.46);
    canvas.drawCircle(center, 28, ringPaint);
    canvas.drawCircle(center, 46, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ActivityCenterSection extends StatelessWidget {
  const ActivityCenterSection({
    Key? key,
    required this.onEventsTap,
    required this.onNotesTap,
    required this.onDonateTap,
    required this.onCategoriesTap,
    required this.onGalleryTap,
    required this.onGoshenRetreatTap,
    required this.onPrayerPointsTap,
    required this.onCounselingTap,
    required this.onDevotionalTap,
    required this.goshenRetreatEnabled,
    required this.prayerPointsEnabled,
    required this.counselingEnabled,
    required this.devotionalsEnabled,
  }) : super(key: key);

  final VoidCallback onEventsTap;
  final VoidCallback onNotesTap;
  final VoidCallback onDonateTap;
  final VoidCallback onCategoriesTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onGoshenRetreatTap;
  final VoidCallback onPrayerPointsTap;
  final VoidCallback onCounselingTap;
  final VoidCallback onDevotionalTap;
  final bool goshenRetreatEnabled;
  final bool prayerPointsEnabled;
  final bool counselingEnabled;
  final bool devotionalsEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = _HomePalette.of(context);
    final cards = [
      ActivityCardData(
        title: 'Events Schedule',
        subtitle: 'Church global upcoming events schedule',
        icon: Icons.event_available_outlined,
        color: const Color(0xFFD85B72),
        onTap: onEventsTap,
      ),
      if (goshenRetreatEnabled)
        ActivityCardData(
          title: 'Goshen Retreat',
          subtitle: 'Register, view tickets, and payments',
          icon: Icons.event_available_rounded,
          color: const Color(0xFF2C9B88),
          onTap: onGoshenRetreatTap,
        ),
      ActivityCardData(
        title: 'Categories',
        subtitle: 'Browse sermons and media by category',
        icon: Icons.category_outlined,
        color: const Color(0xFF0C8AC2),
        onTap: onCategoriesTap,
      ),
      ActivityCardData(
        title: 'Gallery',
        subtitle: 'Church moments and programme photos',
        icon: Icons.photo_library_outlined,
        color: const Color(0xFF8B5CF6),
        onTap: onGalleryTap,
      ),
      ActivityCardData(
        title: 'Notes',
        subtitle: 'Keep sermon notes and reflections close',
        icon: Icons.edit_note_outlined,
        color: const Color(0xFF2C9B88),
        onTap: onNotesTap,
      ),
      if (devotionalsEnabled)
        ActivityCardData(
          title: 'Devotional',
          subtitle: 'Read today\'s devotional content',
          icon: Icons.auto_stories_rounded,
          color: const Color(0xFF2C9B88),
          onTap: onDevotionalTap,
        ),
      if (prayerPointsEnabled)
        ActivityCardData(
          title: 'Prayer Points',
          subtitle: 'Read current church prayer points',
          icon: Icons.menu_book_rounded,
          color: const Color(0xFFFFB625),
          onTap: onPrayerPointsTap,
        ),
      if (counselingEnabled)
        ActivityCardData(
          title: 'Private Counseling',
          subtitle: 'Start a private pastoral care request',
          icon: Icons.health_and_safety_outlined,
          color: const Color(0xFF0B2A3A),
          onTap: onCounselingTap,
        ),
      ActivityCardData(
        title: 'Giving',
        subtitle: 'Give securely through available accounts',
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFFE1A63B),
        onTap: onDonateTap,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Activity Center'),
          const SizedBox(height: 14),
          SizedBox(
            height: 165,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => ActivityCard(data: cards[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityCard extends StatelessWidget {
  const ActivityCard({Key? key, required this.data}) : super(key: key);

  final ActivityCardData data;

  @override
  Widget build(BuildContext context) {
    final colors = _HomePalette.of(context);
    return SizedBox(
      width: 220,
      child: Material(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: data.onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: data.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(data.icon, color: data.color),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.badge,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'Heads up',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.badgeText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 12,
                    height: 1.35,
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

class QuickAccessSection extends StatelessWidget {
  const QuickAccessSection({
    Key? key,
    required this.onVideosTap,
    required this.onAudiosTap,
    required this.onLivestreamTap,
    required this.onBibleTap,
    required this.onHymnsTap,
    required this.hymnsEnabled,
    required this.onWebsiteTap,
  }) : super(key: key);

  final VoidCallback onVideosTap;
  final VoidCallback onAudiosTap;
  final VoidCallback onLivestreamTap;
  final VoidCallback onBibleTap;
  final VoidCallback onHymnsTap;
  final bool hymnsEnabled;
  final VoidCallback onWebsiteTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      QuickAccessData('Videos', Icons.play_circle_outline, onVideosTap),
      QuickAccessData('Audios', Icons.headphones_outlined, onAudiosTap),
      QuickAccessData('Livestream', Icons.live_tv_outlined, onLivestreamTap),
      QuickAccessData('Bible', Icons.menu_book_outlined, onBibleTap),
      if (hymnsEnabled)
        QuickAccessData('Hymns', Icons.library_music_outlined, onHymnsTap),
      QuickAccessData('Website', Icons.language_outlined, onWebsiteTap),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Quick Access'),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.08,
            ),
            itemBuilder: (context, index) =>
                QuickAccessItem(data: items[index]),
          ),
        ],
      ),
    );
  }
}

class QuickAccessItem extends StatelessWidget {
  const QuickAccessItem({Key? key, required this.data}) : super(key: key);

  final QuickAccessData data;

  @override
  Widget build(BuildContext context) {
    final colors = _HomePalette.of(context);
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: data.onTap,
        child: Container(
          height: 96,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(data.icon, color: colors.brand, size: 28),
              const SizedBox(height: 10),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdatesBannerSlider extends StatelessWidget {
  const UpdatesBannerSlider({
    Key? key,
    required this.items,
    required this.controller,
    required this.currentIndex,
    required this.onChanged,
    required this.onTap,
  }) : super(key: key);

  final List<Media> items;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final ValueChanged<Media> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _HomePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Updates'),
          const SizedBox(height: 14),
          SizedBox(
            height: 142,
            child: PageView.builder(
              controller: controller,
              itemCount: items.length,
              onPageChanged: onChanged,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onTap(item),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _AdaptiveBannerImage(
                        remoteUrl: item.coverPhoto,
                        fallbackAsset: _fallbackAsset(index + 1),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              items.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: currentIndex == index ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color:
                      currentIndex == index ? colors.brand : colors.indicator,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSocialLinksSection extends StatelessWidget {
  const HomeSocialLinksSection({Key? key, required this.home})
      : super(key: key);

  final HomeProvider home;

  @override
  Widget build(BuildContext context) {
    final colors = _HomePalette.of(context);
    final links = [
      _HomeSocialLink('Facebook', Icons.facebook, home.data['facebook_page']),
      _HomeSocialLink(
          'YouTube', Icons.play_circle_outline, home.data['youtube_page']),
      _HomeSocialLink(
          'TikTok', Icons.music_note_outlined, home.data['tiktok_page']),
      _HomeSocialLink(
          'Instagram', Icons.camera_alt_outlined, home.data['instagram_page']),
      _HomeSocialLink(
          'Telegram', Icons.send_outlined, home.data['telegram_page']),
      _HomeSocialLink(
          'Mixlr', Icons.graphic_eq_outlined, home.data['mixlr_page']),
      _HomeSocialLink(
          'WhatsApp', Icons.chat_outlined, home.data['whatsapp_page']),
    ].where((link) => link.url.trim().isNotEmpty).toList();

    if (links.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Connect With Us'),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: links
                  .map(
                    (link) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Material(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openSocialLink(link.url),
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                      alpha: colors.isDark ? 0.22 : 0.06),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(link.icon, color: colors.brand),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSocialLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _HomeSocialLink {
  const _HomeSocialLink(this.title, this.icon, dynamic url)
      : url = url == null ? '' : '$url';

  final String title;
  final IconData icon;
  final String url;
}

class _HomePalette {
  const _HomePalette({
    required this.isDark,
    required this.background,
    required this.card,
    required this.text,
    required this.muted,
    required this.brand,
    required this.badge,
    required this.badgeText,
    required this.indicator,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color text;
  final Color muted;
  final Color brand;
  final Color badge;
  final Color badgeText;
  final Color indicator;

  static _HomePalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _HomePalette(
      isDark: isDark,
      background: isDark ? const Color(0xFF071720) : const Color(0xFFF6F8FB),
      card: isDark ? const Color(0xFF102532) : Colors.white,
      text: isDark ? Colors.white : const Color(0xFF17262A),
      muted: isDark ? Colors.white70 : const Color(0xFF60707A),
      brand: isDark ? const Color(0xFFFFC857) : const Color(0xFF0C2230),
      badge: isDark ? const Color(0xFF173242) : const Color(0xFFEAF3FA),
      badgeText: isDark ? Colors.white70 : const Color(0xFF36566D),
      indicator: isDark ? const Color(0xFF315061) : const Color(0xFFCBD5DE),
    );
  }
}

class ActivityCardData {
  const ActivityCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class QuickAccessData {
  const QuickAccessData(this.title, this.icon, this.onTap);

  final String title;
  final IconData icon;
  final VoidCallback onTap;
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Inbox notifications',
          onPressed: onTap,
          icon:
              const Icon(Icons.notifications_none_rounded, color: Colors.white),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D67),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = _HomePalette.of(context);
    return Text(
      text,
      style: TextStyle(
        color: colors.text,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AdaptiveBannerImage extends StatelessWidget {
  const _AdaptiveBannerImage({
    required this.remoteUrl,
    required this.fallbackAsset,
  });

  final String? remoteUrl;
  final String fallbackAsset;

  @override
  Widget build(BuildContext context) {
    if (_hasRemoteImage(remoteUrl)) {
      final cacheWidth = (MediaQuery.sizeOf(context).width *
              MediaQuery.devicePixelRatioOf(context))
          .round();
      return CachedNetworkImage(
        imageUrl: remoteUrl!,
        fit: BoxFit.cover,
        memCacheWidth: cacheWidth,
        maxWidthDiskCache: cacheWidth,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }

    return _fallback();
  }

  Widget _placeholder() {
    return ColoredBox(
      color: const Color(0xFFE8EEF2),
      child: const Center(child: CupertinoActivityIndicator()),
    );
  }

  Widget _fallback() {
    return Image.asset(fallbackAsset, fit: BoxFit.cover);
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(height: 220, decoration: _loadingDecoration()),
          const SizedBox(height: 18),
          Container(height: 58, decoration: _loadingDecoration()),
          const SizedBox(height: 24),
          Container(height: 150, decoration: _loadingDecoration()),
          const SizedBox(height: 24),
          Container(height: 96, decoration: _loadingDecoration()),
          const SizedBox(height: 24),
          Container(height: 142, decoration: _loadingDecoration()),
        ],
      ),
    );
  }

  BoxDecoration _loadingDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

String _displayName(Userdata? user) {
  final name = user?.name?.trim();
  return name == null || name.isEmpty ? 'Guest' : name.split(' ').first;
}

bool _hasRemoteImage(String? value) {
  return value != null &&
      value.trim().isNotEmpty &&
      (value.startsWith('http://') || value.startsWith('https://'));
}

String _fallbackAsset(int index) {
  const assets = [
    'assets/images/worship.jpg',
    'assets/images/event.jpg',
    'assets/images/messages.jpg',
    'assets/images/cover_photos.jpg',
  ];
  return assets[index % assets.length];
}

final List<Media> _fallbackMedia = [
  Media(
    title: 'Worship Highlights',
    category: 'Featured',
    mediaType: 'audio',
    coverPhoto: '',
  ),
  Media(
    title: 'Upcoming Church Event',
    category: 'Updates',
    mediaType: 'video',
    coverPhoto: '',
  ),
];
