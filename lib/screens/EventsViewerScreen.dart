import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/strings.g.dart';
import '../models/Events.dart';
import '../utils/TextStyles.dart';
import '../utils/img.dart';
import 'NoitemScreen.dart';

class EventsViewerScreen extends StatefulWidget {
  static const routeName = "/eventsviewer";

  const EventsViewerScreen({Key? key, this.events}) : super(key: key);

  final Events? events;

  @override
  State<EventsViewerScreen> createState() => _EventsViewerScreenState();
}

class _EventsViewerScreenState extends State<EventsViewerScreen> {
  static const MethodChannel _shareChannel =
      MethodChannel('covenant_of_mercy/share');

  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final eventDate = _eventDateTime(widget.events);
    if (eventDate == null) return;
    final diff = eventDate.difference(DateTime.now());
    if (!mounted) return;
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.events;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(t.events),
        elevation: 0,
      ),
      body: event == null
          ? Center(
              child: NoitemScreen(
                title: t.oops,
                message: t.dataloaderror,
                onClick: () {},
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _EventBanner(
                    event: event,
                    onTap: () => _openBanner(event),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _openBanner(event),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0C2230),
                        side: const BorderSide(color: Color(0xFFFFB51D)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      icon: const Icon(Icons.fullscreen_rounded, size: 20),
                      label: const Text('Click to view full image banner'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _EventTitleBlock(event: event),
                  if (_hasProgrammeDetails(event)) ...[
                    const SizedBox(height: 18),
                    _EventProgrammeDetails(
                      event: event,
                      onOpenLink: _openExternalUrl,
                    ),
                  ],
                  if (event.eventSchedule.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _EventScheduleCard(days: event.eventSchedule),
                  ],
                  if (event.hasPilgrimageDetails) ...[
                    const SizedBox(height: 18),
                    _PilgrimageDetailsCard(
                      details: event.pilgrimageDetails,
                      onCall: (phone) => _openExternalUrl(
                        'tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  event.isPast
                      ? const _PastEventNotice()
                      : _CountdownRow(remaining: _remaining),
                  const SizedBox(height: 22),
                  if (_canShowRegistration(event))
                    Center(
                      child: SizedBox(
                        width: 236,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: () => _openRegistration(event),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB51D),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: const Text(
                            'Register Now ->',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  if (!event.isPast)
                    _EventShareSection(
                      onShare: (platform) => _shareEvent(event, platform),
                    ),
                  if (_eventDetails(event).isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: HtmlWidget(
                        _eventDetails(event),
                        textStyle:
                            TextStyles.medium(context).copyWith(fontSize: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  bool _canShowRegistration(Events event) {
    final url = event.registrationUrl?.trim() ?? '';
    if (url.isEmpty) return false;

    final country = PlatformDispatcher.instance.locale.countryCode ?? '';
    final availability = event.registrationAvailability ?? 'everywhere';
    if (availability == 'everywhere') return true;
    if (availability == 'nigeria') return country.toUpperCase() == 'NG';
    if (availability == 'outside_nigeria') return country.toUpperCase() != 'NG';
    return true;
  }

  Future<void> _openRegistration(Events event) async {
    final uri = Uri.tryParse(event.registrationUrl?.trim() ?? '');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareEvent(Events event, String platform) async {
    if (event.isPast) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Past events cannot be shared from the app.'),
        ),
      );
      return;
    }

    final text = _eventShareText(event);

    switch (platform) {
      case 'whatsapp':
        if (await _shareEventToPackage(event, text, 'com.whatsapp') ||
            await _shareEventToPackage(event, text, 'com.whatsapp.w4b')) {
          return;
        }
        break;
      case 'facebook':
        if (await _shareEventToPackage(event, text, 'com.facebook.katana') ||
            await _shareEventToPackage(event, text, 'com.facebook.lite')) {
          return;
        }
        break;
      case 'x':
        if (await _shareEventToPackage(event, text, 'com.twitter.android')) {
          return;
        }
        break;
      case 'email':
        await _shareEventWithBanner(event, text);
        return;
      case 'instagram':
        if (await _shareEventToPackage(event, text, 'com.instagram.android')) {
          return;
        }
        await _shareEventWithBanner(event, text);
        return;
      case 'tiktok':
        if (await _shareEventToPackage(
            event, text, 'com.zhiliaoapp.musically')) {
          return;
        }
        await _shareEventWithBanner(event, text);
        return;
      case 'more':
        await _shareEventWithBanner(event, text);
        return;
    }

    await _shareEventWithBanner(event, text);
  }

  Future<bool> _shareEventToPackage(
    Events event,
    String text,
    String packageName,
  ) async {
    final banner = await _downloadBannerForShare(event);
    if (banner == null) return false;

    try {
      return await _shareChannel.invokeMethod<bool>('shareImageToPackage', {
            'packageName': packageName,
            'imagePath': banner.path,
            'text': text,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _shareEventWithBanner(Events event, String text) async {
    final banner = await _downloadBannerForShare(event);
    if (banner != null) {
      await Share.shareXFiles(
        [banner],
        text: text,
        subject: event.title?.trim().isNotEmpty == true
            ? event.title!.trim()
            : 'Church event invitation',
      );
      return;
    }

    await Share.share(
      text,
      subject: event.title?.trim().isNotEmpty == true
          ? event.title!.trim()
          : 'Church event invitation',
    );
  }

  Future<XFile?> _downloadBannerForShare(Events event) async {
    final imageUrl = event.portraitImage?.trim() ?? '';
    if (imageUrl.isEmpty) return null;

    try {
      final dir = await getTemporaryDirectory();
      final id = event.id ?? DateTime.now().millisecondsSinceEpoch;
      final filePath = '${dir.path}/covenant_event_$id.jpg';
      await Dio().download(imageUrl, filePath);
      return XFile(filePath, mimeType: 'image/jpeg');
    } catch (_) {
      return null;
    }
  }

  void _openBanner(Events event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EventBannerViewer(
          event: event,
          canShare: !event.isPast,
          onShare: () => _shareEventWithBanner(event, _eventShareText(event)),
        ),
      ),
    );
  }
}

class _EventShareSection extends StatelessWidget {
  const _EventShareSection({required this.onShare});

  final Future<void> Function(String platform) onShare;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ShareItem(
        label: 'WhatsApp',
        platform: 'whatsapp',
        icon: FontAwesomeIcons.whatsapp,
        color: const Color(0xFF25D366),
      ),
      _ShareItem(
        label: 'Facebook',
        platform: 'facebook',
        icon: FontAwesomeIcons.facebookF,
        color: const Color(0xFF1877F2),
      ),
      _ShareItem(
        label: 'Instagram',
        platform: 'instagram',
        icon: FontAwesomeIcons.instagram,
        color: const Color(0xFFE4405F),
      ),
      _ShareItem(
        label: 'TikTok',
        platform: 'tiktok',
        icon: FontAwesomeIcons.tiktok,
        color: Colors.black,
      ),
      _ShareItem(
        label: 'X',
        platform: 'x',
        icon: FontAwesomeIcons.xTwitter,
        color: Colors.black,
      ),
      _ShareItem(
        label: 'Email',
        platform: 'email',
        icon: FontAwesomeIcons.envelope,
        color: const Color(0xFF0C2230),
      ),
      _ShareItem(
        label: 'More',
        platform: 'more',
        icon: Icons.ios_share_rounded,
        color: const Color(0xFFFFB51D),
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.share_rounded, color: Color(0xFF0C2230), size: 20),
              SizedBox(width: 8),
              Text(
                'Share this event',
                style: TextStyle(
                  color: Color(0xFF0C2230),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _ShareButton(
                        item: item,
                        onTap: () => onShare(item.platform),
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
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.item,
    required this.onTap,
  });

  final _ShareItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: item.color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: item.icon is IconData
                    ? Icon(
                        item.icon as IconData,
                        color: Colors.white,
                        size: 19,
                      )
                    : FaIcon(
                        item.icon as FaIconData,
                        color: Colors.white,
                        size: 18,
                      ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF273B47),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareItem {
  const _ShareItem({
    required this.label,
    required this.platform,
    required this.icon,
    required this.color,
  });

  final String label;
  final String platform;
  final Object icon;
  final Color color;
}

class _EventBanner extends StatelessWidget {
  const _EventBanner({
    required this.event,
    required this.onTap,
  });

  final Events event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Container(
              color: Colors.white,
              child: AspectRatio(
                aspectRatio: 16 / 7.2,
                child: CachedNetworkImage(
                  imageUrl: event.thumbnail ?? '',
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CupertinoActivityIndicator(radius: 16),
                  ),
                  errorWidget: (_, __, ___) => Image.asset(
                    Img.get('event.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventBannerViewer extends StatelessWidget {
  const _EventBannerViewer({
    required this.event,
    required this.onShare,
    required this.canShare,
  });

  final Events event;
  final Future<void> Function() onShare;
  final bool canShare;

  @override
  Widget build(BuildContext context) {
    final title = event.title?.trim();
    final hasPortrait = (event.portraitImage ?? '').trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title == null || title.isEmpty ? 'Event banner' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
      ),
      floatingActionButton: canShare
          ? FloatingActionButton.extended(
              onPressed: onShare,
              backgroundColor: const Color(0xFFFFB51D),
              foregroundColor: const Color(0xFF0C2230),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text(
                'Share',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : null,
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: event.fullScreenImage,
              fit: hasPortrait ? BoxFit.cover : BoxFit.contain,
              placeholder: (_, __) => const CupertinoActivityIndicator(
                color: Colors.white,
                radius: 18,
              ),
              errorWidget: (_, __, ___) => Image.asset(
                Img.get('event.jpg'),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventTitleBlock extends StatelessWidget {
  const _EventTitleBlock({required this.event});

  final Events event;

  @override
  Widget build(BuildContext context) {
    final formattedDate = _formattedDate(event);
    return Column(
      children: [
        if (event.isPast) ...[
          const _PastEventBadge(),
          const SizedBox(height: 12),
        ],
        Text(
          event.title ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0B2A4A),
            fontSize: 28,
            height: 1.12,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (formattedDate.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            formattedDate.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFE11F55),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        if ((event.venue ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoPill(
            icon: Icons.location_on_outlined,
            text: event.venue!.trim(),
          ),
        ],
        if ((event.time ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _InfoPill(
            icon: Icons.schedule_outlined,
            text: _timeRange(event),
          ),
        ],
      ],
    );
  }
}

class _PastEventBadge extends StatelessWidget {
  const _PastEventBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF60707A).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: const Color(0xFF60707A).withValues(alpha: 0.2)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, color: Color(0xFF60707A), size: 18),
          SizedBox(width: 7),
          Text(
            'Past event',
            style: TextStyle(
              color: Color(0xFF60707A),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PastEventNotice extends StatelessWidget {
  const _PastEventNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6EEF2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.event_available_rounded, color: Color(0xFF60707A)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This programme has already taken place. You can still view and share the event details.',
              style: TextStyle(
                color: Color(0xFF60707A),
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0C2230)),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF344B5A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    return Row(
      children: [
        _CountdownBox(value: days, label: 'Days'),
        const SizedBox(width: 10),
        _CountdownBox(value: hours, label: 'Hours'),
        const SizedBox(width: 10),
        _CountdownBox(value: minutes, label: 'Minutes'),
        const SizedBox(width: 10),
        _CountdownBox(value: seconds, label: 'Seconds'),
      ],
    );
  }
}

class _EventProgrammeDetails extends StatelessWidget {
  const _EventProgrammeDetails({
    required this.event,
    required this.onOpenLink,
  });

  final Events event;
  final Future<void> Function(String url) onOpenLink;

  @override
  Widget build(BuildContext context) {
    final musicianText = event.invitedGospelMusicians
        .map((musician) => musician.name)
        .where((name) => name.isNotEmpty)
        .join(', ');
    final musicianImages = event.invitedGospelMusicians
        .where((musician) => musician.imageUrl.isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFFFFB51D), size: 22),
              SizedBox(width: 8),
              Text(
                'Programme details',
                style: TextStyle(
                  color: Color(0xFF0C2230),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if ((event.theme ?? '').trim().isNotEmpty)
                _ProgrammeChip(
                  icon: Icons.flag_rounded,
                  label: 'Theme',
                  value: event.theme!.trim(),
                ),
              if ((event.bibleVerse ?? '').trim().isNotEmpty)
                _ProgrammeChip(
                  icon: Icons.menu_book_rounded,
                  label: 'Bible Verse',
                  value: event.bibleVerse!.trim(),
                ),
              if ((event.host ?? '').trim().isNotEmpty)
                _ProgrammeChip(
                  icon: Icons.person_rounded,
                  label: 'Host',
                  value: event.host!.trim(),
                ),
              if ((event.otherMinisters ?? '').trim().isNotEmpty)
                _ProgrammeChip(
                  icon: Icons.groups_rounded,
                  label: 'Other Ministers',
                  value: event.otherMinisters!.trim(),
                ),
              if (musicianText.isNotEmpty)
                _ProgrammeChip(
                  icon: Icons.music_note_rounded,
                  label: 'Invited Gospel Musicians',
                  value: musicianText,
                ),
            ],
          ),
          if (musicianImages.isNotEmpty) ...[
            const SizedBox(height: 18),
            _GospelMusiciansCarousel(musicians: musicianImages),
          ],
          if (event.liveStreamingPlatforms.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Live streaming',
              style: TextStyle(
                color: Color(0xFF0C2230),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ...event.liveStreamingPlatforms.map(
              (platform) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _StreamingPlatformTile(
                  platform: platform,
                  onTap: platform.url.isEmpty
                      ? null
                      : () => onOpenLink(platform.url),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgrammeChip extends StatelessWidget {
  const _ProgrammeChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EEF2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF0C2230).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0C2230), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF71808A),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0C2230),
                    fontSize: 14,
                    height: 1.3,
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

class _GospelMusiciansCarousel extends StatelessWidget {
  const _GospelMusiciansCarousel({required this.musicians});

  final List<EventGospelMusician> musicians;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.mic_external_on_rounded,
                color: Color(0xFFFFB51D), size: 20),
            SizedBox(width: 8),
            Text(
              'Featured gospel ministers',
              style: TextStyle(
                color: Color(0xFF0C2230),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: musicians.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final musician = musicians[index];
              return _GospelMusicianPortraitCard(
                musician: musician,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _GospelMusicianImageViewer(
                      musicians: musicians,
                      initialIndex: index,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GospelMusicianPortraitCard extends StatelessWidget {
  const _GospelMusicianPortraitCard({
    required this.musician,
    required this.onTap,
  });

  final EventGospelMusician musician;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = musician.name.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 124,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 16,
              offset: Offset(0, 9),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: musician.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: const Color(0xFFF4F8FA),
                child: const Center(
                  child: CupertinoActivityIndicator(radius: 13),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFF0C2230),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Color(0xFFFFB51D),
                  size: 38,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.74),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fullscreen_rounded,
                  color: Color(0xFF0C2230),
                  size: 18,
                ),
              ),
            ),
            if (name.isNotEmpty)
              Positioned(
                left: 11,
                right: 11,
                bottom: 12,
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.08,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GospelMusicianImageViewer extends StatefulWidget {
  const _GospelMusicianImageViewer({
    required this.musicians,
    required this.initialIndex,
  });

  final List<EventGospelMusician> musicians;
  final int initialIndex;

  @override
  State<_GospelMusicianImageViewer> createState() =>
      _GospelMusicianImageViewerState();
}

class _GospelMusicianImageViewerState
    extends State<_GospelMusicianImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final musician = widget.musicians[_index];
    final title = musician.name.isEmpty ? 'Gospel minister' : musician.name;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.musicians.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              final item = widget.musicians[index];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const CupertinoActivityIndicator(
                      color: Colors.white,
                      radius: 18,
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white70,
                      size: 52,
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.musicians.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.musicians.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StreamingPlatformTile extends StatelessWidget {
  const _StreamingPlatformTile({
    required this.platform,
    required this.onTap,
  });

  final EventStreamingPlatform platform;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF0C2230),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.live_tv_rounded, color: Color(0xFFFFB51D)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                platform.platform.isEmpty ? 'Live stream' : platform.platform,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (platform.url.isNotEmpty)
              const Icon(Icons.open_in_new_rounded,
                  color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EventScheduleCard extends StatelessWidget {
  const _EventScheduleCard({required this.days});

  final List<EventScheduleDay> days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_note_rounded,
                  color: Color(0xFFFFB51D), size: 22),
              SizedBox(width: 8),
              Text(
                'Event schedule',
                style: TextStyle(
                  color: Color(0xFF0C2230),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...days.map(
            (day) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8FA),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE6EEF2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (day.dayLabel.isNotEmpty)
                      Text(
                        day.dayLabel,
                        style: const TextStyle(
                          color: Color(0xFF0C2230),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    if (day.dateLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        day.dateLabel,
                        style: const TextStyle(
                          color: Color(0xFF71808A),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (day.sessions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...day.sessions.map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB51D)
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.schedule_rounded,
                                  color: Color(0xFF0C2230),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (session.title.isNotEmpty)
                                      Text(
                                        session.title,
                                        style: const TextStyle(
                                          color: Color(0xFF0C2230),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    if (session.time.isNotEmpty)
                                      Text(
                                        session.time,
                                        style: const TextStyle(
                                          color: Color(0xFF465862),
                                          fontSize: 13,
                                          height: 1.35,
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

class _PilgrimageDetailsCard extends StatelessWidget {
  const _PilgrimageDetailsCard({
    required this.details,
    required this.onCall,
  });

  final PilgrimageDetails details;
  final void Function(String phone) onCall;

  @override
  Widget build(BuildContext context) {
    final summaryItems = <_ProgrammeChip>[
      if (details.organizer.isNotEmpty)
        _ProgrammeChip(
          icon: Icons.church_rounded,
          label: 'Organizer',
          value: details.organizer,
        ),
      if (details.packagedBy.isNotEmpty)
        _ProgrammeChip(
          icon: Icons.flight_takeoff_rounded,
          label: 'Packaged by',
          value: details.packagedBy,
        ),
      if (details.theme.isNotEmpty)
        _ProgrammeChip(
          icon: Icons.auto_awesome_rounded,
          label: 'Pilgrimage theme',
          value: details.theme,
        ),
      if (details.countryVenue.isNotEmpty)
        _ProgrammeChip(
          icon: Icons.public_rounded,
          label: 'Country / Venue',
          value: details.countryVenue,
        ),
      if (details.dateText.isNotEmpty)
        _ProgrammeChip(
          icon: Icons.date_range_rounded,
          label: 'Pilgrimage date',
          value: details.dateText,
        ),
      if (details.ministering.isNotEmpty)
        _ProgrammeChip(
          icon: Icons.groups_rounded,
          label: 'Ministering',
          value: details.ministering,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2230),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180C2230),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.travel_explore_rounded,
                  color: Color(0xFFFFB51D), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pilgrimage details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...summaryItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: item,
            ),
          ),
          if (details.participationFees.any((fee) => fee.hasContent)) ...[
            const SizedBox(height: 8),
            _PilgrimageSectionTitle(
              icon: Icons.payments_rounded,
              title: 'Participation fee breakdown',
            ),
            const SizedBox(height: 10),
            ...details.participationFees
                .where((fee) => fee.hasContent)
                .map((fee) => _FeeRow(fee: fee)),
          ],
          if (details.paymentDetails.any((payment) => payment.hasContent)) ...[
            const SizedBox(height: 14),
            _PilgrimageSectionTitle(
              icon: Icons.account_balance_rounded,
              title: 'Payment details',
            ),
            const SizedBox(height: 10),
            ...details.paymentDetails
                .where((payment) => payment.hasContent)
                .map((payment) => _PaymentDetailBlock(payment: payment)),
          ],
          if (details.registrationContacts
              .any((contact) => contact.hasContent)) ...[
            const SizedBox(height: 14),
            _PilgrimageSectionTitle(
              icon: Icons.call_rounded,
              title: 'Registration contacts',
            ),
            const SizedBox(height: 10),
            ...details.registrationContacts
                .where((contact) => contact.hasContent)
                .map((contact) => _PilgrimageContactTile(
                      contact: contact,
                      onCall: onCall,
                    )),
          ],
        ],
      ),
    );
  }
}

class _PilgrimageSectionTitle extends StatelessWidget {
  const _PilgrimageSectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFFB51D), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({required this.fee});

  final PilgrimageFee fee;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fee.label.isNotEmpty)
                  Text(
                    fee.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (fee.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    fee.note,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (fee.amount.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              fee.amount,
              style: const TextStyle(
                color: Color(0xFFFFB51D),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentDetailBlock extends StatelessWidget {
  const _PaymentDetailBlock({required this.payment});

  final PilgrimagePaymentSection payment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (payment.title.isNotEmpty)
            Text(
              payment.title,
              style: const TextStyle(
                color: Color(0xFF0C2230),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          if (payment.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              payment.details,
              style: const TextStyle(
                color: Color(0xFF465862),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PilgrimageContactTile extends StatelessWidget {
  const _PilgrimageContactTile({
    required this.contact,
    required this.onCall,
  });

  final PilgrimageContact contact;
  final void Function(String phone) onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB51D).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.support_agent_rounded,
                color: Color(0xFF0C2230), size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (contact.name.isNotEmpty)
                  Text(
                    contact.name,
                    style: const TextStyle(
                      color: Color(0xFF0C2230),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (contact.phone.isNotEmpty)
                  Text(
                    contact.phone,
                    style: const TextStyle(
                      color: Color(0xFF465862),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          if (contact.phone.isNotEmpty)
            IconButton.filled(
              onPressed: () => onCall(contact.phone),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFFB51D),
                foregroundColor: const Color(0xFF0C2230),
              ),
              icon: const Icon(Icons.call_rounded),
            ),
        ],
      ),
    );
  }
}

class _CountdownBox extends StatelessWidget {
  const _CountdownBox({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 98,
        decoration: BoxDecoration(
          color: const Color(0xFF08284D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime? _eventDateTime(Events? event) {
  return event?.startDateTime;
}

String _formattedDate(Events event) {
  final date = _eventDateTime(event);
  if (date == null) return event.date ?? '';
  return DateFormat('MMMM d, yyyy').format(date);
}

String _timeRange(Events event) {
  final start = event.time?.trim() ?? '';
  final end = DateTime.tryParse(event.endsAt ?? '');
  if (end == null) return start;
  return '$start - ${DateFormat('h:mm a').format(end)}';
}

String _eventDetails(Events event) {
  final value = event.details?.trim() ?? '';
  if (value == '<p></p>' || value == '<p><br></p>') return '';
  return value;
}

bool _hasProgrammeDetails(Events event) {
  return (event.theme ?? '').trim().isNotEmpty ||
      (event.bibleVerse ?? '').trim().isNotEmpty ||
      (event.host ?? '').trim().isNotEmpty ||
      (event.otherMinisters ?? '').trim().isNotEmpty ||
      event.liveStreamingPlatforms.isNotEmpty ||
      event.invitedGospelMusicians.isNotEmpty;
}

String _eventScheduleShareText(Events event) {
  if (event.eventSchedule.isEmpty) return '';
  final dayBlocks = <String>[];
  for (final day in event.eventSchedule) {
    final lines = <String>[];
    final header = [day.dayLabel, day.dateLabel]
        .where((item) => item.trim().isNotEmpty)
        .join(' - ');
    if (header.isNotEmpty) lines.add(header.toUpperCase());
    for (final session in day.sessions) {
      final label = session.title.isEmpty ? '' : '${session.title}: ';
      if (session.time.isNotEmpty) lines.add('  - $label${session.time}');
    }
    if (lines.isNotEmpty) dayBlocks.add(lines.join('\n'));
  }
  return dayBlocks.join('\n\n');
}

String _pilgrimageShareText(Events event) {
  if (!event.hasPilgrimageDetails) return '';
  final details = event.pilgrimageDetails;
  final lines = <String>[
    if (details.organizer.isNotEmpty) 'Organizer: ${details.organizer}',
    if (details.packagedBy.isNotEmpty) 'Packaged by: ${details.packagedBy}',
    if (details.theme.isNotEmpty) 'Theme: ${details.theme}',
    if (details.countryVenue.isNotEmpty)
      'Country/Venue: ${details.countryVenue}',
    if (details.dateText.isNotEmpty) 'Date: ${details.dateText}',
    if (details.ministering.isNotEmpty) 'Ministering: ${details.ministering}',
  ];

  final fees =
      details.participationFees.where((fee) => fee.hasContent).map((fee) {
    final label = fee.label.isEmpty ? 'Fee' : fee.label;
    final amount = fee.amount.isEmpty ? '' : ': ${fee.amount}';
    final note = fee.note.isEmpty ? '' : ' (${fee.note})';
    return '  - $label$amount$note';
  }).join('\n');
  if (fees.isNotEmpty) lines.add('Participation Fees:\n$fees');

  final contacts = details.registrationContacts
      .where((contact) => contact.hasContent)
      .map((contact) {
    if (contact.name.isEmpty) return contact.phone;
    if (contact.phone.isEmpty) return contact.name;
    return '  - ${contact.name}: ${contact.phone}';
  }).join('\n');
  if (contacts.isNotEmpty) lines.add('Registration Contacts:\n$contacts');

  return lines.join('\n\n');
}

String _eventShareText(Events event) {
  final title = event.title?.trim();
  final date = _formattedDate(event).trim();
  final time = _timeRange(event).trim();
  final venue = event.venue?.trim();
  final theme = event.theme?.trim();
  final bibleVerse = event.bibleVerse?.trim();
  final host = event.host?.trim();
  final musicians = event.invitedGospelMusicians
      .map((musician) => musician.name)
      .where((name) => name.isNotEmpty)
      .join(', ');
  final schedule = _eventScheduleShareText(event);
  final pilgrimage = _pilgrimageShareText(event);
  final streaming = event.liveStreamingPlatforms
      .map((platform) {
        final label = platform.platform.trim();
        final url = platform.url.trim();
        if (label.isEmpty && url.isEmpty) return '';
        if (url.isEmpty) return label;
        if (label.isEmpty) return url;
        return '$label: $url';
      })
      .where((item) => item.isNotEmpty)
      .join('\n');
  final registration = event.registrationUrl?.trim();

  final sections = <String>[];

  if (title != null && title.isNotEmpty) {
    sections.add(title.toUpperCase());
  }

  final overview = <String>[
    if (theme != null && theme.isNotEmpty) 'Theme: $theme',
    if (bibleVerse != null && bibleVerse.isNotEmpty) 'Bible Verse: $bibleVerse',
    if (date.isNotEmpty) 'Date: $date',
    if (time.isNotEmpty) 'Time: $time',
    if (venue != null && venue.isNotEmpty) 'Venue: $venue',
  ];
  if (overview.isNotEmpty) sections.add(overview.join('\n'));

  if (schedule.isNotEmpty) {
    sections.add('SCHEDULE\n$schedule');
  }

  final ministers = <String>[
    if (host != null && host.isNotEmpty) 'Host: $host',
    if (musicians.isNotEmpty) 'Invited Gospel Musicians: $musicians',
  ];
  if (ministers.isNotEmpty) sections.add(ministers.join('\n'));

  if (pilgrimage.isNotEmpty) {
    sections.add('PILGRIMAGE DETAILS\n$pilgrimage');
  }

  if (streaming.isNotEmpty) {
    sections.add('LIVE STREAMING\n$streaming');
  }

  if (registration != null && registration.isNotEmpty) {
    sections.add('REGISTER HERE\n$registration');
  }

  sections.add('You are invited to join us. Please share with someone.');

  return sections.join('\n\n');
}
