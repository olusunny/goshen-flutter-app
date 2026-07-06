import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../utils/TimUtil.dart';
import 'prayer_api_client.dart';
import 'prayer_models.dart';

class PrayerPointsScreen extends StatefulWidget {
  const PrayerPointsScreen({super.key});

  static const routeName = '/prayer-points';

  @override
  State<PrayerPointsScreen> createState() => _PrayerPointsScreenState();
}

class _PrayerPointsScreenState extends State<PrayerPointsScreen> {
  final PrayerApiClient _api = PrayerApiClient();
  Future<List<PrayerPoint>>? _future;
  List<PrayerPoint> _points = const [];

  @override
  void initState() {
    super.initState();
    _points = _api.cachedPrayerPoints ?? const [];
    _future = _load();
  }

  Future<List<PrayerPoint>> _load() async {
    final points = await _api.fetchPrayerPoints();
    if (mounted) {
      setState(() => _points = points);
    }
    return points;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {
      // FutureBuilder renders the error state; keep pull-to-refresh settled.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPointsPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Prayer Points')),
      body: RefreshIndicator(
        color: colors.accent,
        backgroundColor: colors.card,
        onRefresh: _refresh,
        child: FutureBuilder<List<PrayerPoint>>(
          future: _future,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                    _points.isEmpty;
            final error = snapshot.hasError && _points.isEmpty
                ? snapshot.error.toString()
                : null;

            if (isLoading) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                children: const [
                  _PrayerPointsHeader(),
                  SizedBox(height: 18),
                  _PrayerPointSkeleton(),
                  SizedBox(height: 12),
                  _PrayerPointSkeleton(),
                ],
              );
            }

            if (error != null) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                children: [
                  const _PrayerPointsHeader(),
                  const SizedBox(height: 18),
                  _PrayerPointsError(message: error, onRetry: _refresh),
                ],
              );
            }

            if (_points.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                children: const [
                  _PrayerPointsHeader(),
                  SizedBox(height: 18),
                  _PrayerPointsEmpty(),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              itemCount: _points.length + 1,
              separatorBuilder: (_, index) => index == 0
                  ? const SizedBox(height: 18)
                  : const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return const _PrayerPointsHeader();
                return _PrayerPointReadCard(point: _points[index - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _PrayerPointsHeader extends StatelessWidget {
  const _PrayerPointsHeader();

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPointsPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.hero,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.menu_book_rounded, color: colors.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prayer Points',
                  style: TextStyle(
                    color: colors.heroText,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.06,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Read church prayer points and declarations for focused prayer.',
                  style: TextStyle(
                    color: colors.heroMuted,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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

class _PrayerPointReadCard extends StatelessWidget {
  const _PrayerPointReadCard({required this.point});

  final PrayerPoint point;

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPointsPalette.of(context);
    final hasContent = point.content.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.16 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (point.hasThumbnail)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: point.thumbnailUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: colors.softCard,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: colors.muted,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.favorite_border_rounded,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            point.title,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              height: 1.18,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _prayerPointMeta(point),
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasContent) ...[
                  const SizedBox(height: 14),
                  HtmlWidget(
                    point.content,
                    textStyle: TextStyle(
                      color: colors.text.withValues(alpha: 0.9),
                      fontSize: 16,
                      height: 1.48,
                      fontWeight: FontWeight.w500,
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

class _PrayerPointsError extends StatelessWidget {
  const _PrayerPointsError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPointsPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, color: colors.accent, size: 34),
          const SizedBox(height: 14),
          Text(
            'Unable to load prayer points',
            style: TextStyle(
              color: colors.text,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              color: colors.muted,
              fontSize: 15.5,
              height: 1.42,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _PrayerPointsEmpty extends StatelessWidget {
  const _PrayerPointsEmpty();

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPointsPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.favorite_border_rounded, color: colors.accent, size: 46),
          const SizedBox(height: 14),
          Text(
            'No prayer points yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Published church prayer points will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.muted,
              fontSize: 15.5,
              height: 1.42,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerPointSkeleton extends StatelessWidget {
  const _PrayerPointSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPointsPalette.of(context);
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: colors.softCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
    );
  }
}

String _prayerPointMeta(PrayerPoint point) {
  final parts = <String>[];
  if (point.author.trim().isNotEmpty) parts.add(point.author.trim());
  if (point.date > 0) parts.add(TimUtil.formatFullDatestamp(point.date));
  return parts.isEmpty ? 'Prayer point' : parts.join(' - ');
}

class _PrayerPointsPalette {
  const _PrayerPointsPalette({
    required this.isDark,
    required this.background,
    required this.card,
    required this.softCard,
    required this.hero,
    required this.text,
    required this.muted,
    required this.heroText,
    required this.heroMuted,
    required this.border,
    required this.accent,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color softCard;
  final Color hero;
  final Color text;
  final Color muted;
  final Color heroText;
  final Color heroMuted;
  final Color border;
  final Color accent;

  static _PrayerPointsPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PrayerPointsPalette(
      isDark: isDark,
      background: isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
      card: isDark ? const Color(0xFF102532) : Colors.white,
      softCard: isDark ? const Color(0xFF0C2230) : const Color(0xFFF0F5F7),
      hero: isDark ? const Color(0xFF0B2D2A) : const Color(0xFF0C302A),
      text: isDark ? Colors.white : const Color(0xFF102532),
      muted: isDark ? Colors.white70 : const Color(0xFF60707A),
      heroText: Colors.white,
      heroMuted: Colors.white.withValues(alpha: 0.74),
      border: isDark ? Colors.white10 : const Color(0xFFE1E8EC),
      accent: const Color(0xFFFFB625),
    );
  }
}
