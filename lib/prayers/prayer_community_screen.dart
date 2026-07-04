import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../auth/LoginScreen.dart';
import '../models/Userdata.dart';
import '../providers/AppStateManager.dart';
import '../socials/UpdateUserProfile.dart';
import '../utils/Alerts.dart';
import '../utils/TimUtil.dart';
import 'prayer_api_client.dart';
import 'prayer_guest_prompt.dart';
import 'prayer_models.dart';
import 'voice_recording_dialog.dart';

class PrayerCommunityScreen extends StatefulWidget {
  const PrayerCommunityScreen({
    super.key,
    this.openPropheticComposerOnLoad = false,
  });

  static const routeName = '/prayer-community';
  final bool openPropheticComposerOnLoad;

  @override
  State<PrayerCommunityScreen> createState() => _PrayerCommunityScreenState();
}

class _PrayerCommunityScreenState extends State<PrayerCommunityScreen> {
  final PrayerApiClient _api = PrayerApiClient();
  List<PrayerRequest> _items = [];
  List<PrayerPoint> _prayerPoints = [];
  PropheticDecree? _decree;
  PrayerSubmissionStatus _submissionStatus =
      const PrayerSubmissionStatus(canSubmit: true, cooldownSeconds: 0);
  Timer? _cooldownTimer;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    final cachedFeed = _api.cachedPrayerFeed(user);
    if (cachedFeed != null) {
      _items = cachedFeed.requests;
      _submissionStatus = cachedFeed.submissionStatus;
      _decree = _api.cachedActivePropheticDecree;
      _prayerPoints = _api.cachedPrayerPoints ?? const <PrayerPoint>[];
      _loading = false;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _loadPrayers(silent: true));
    } else {
      _loadPrayers();
    }
    if (widget.openPropheticComposerOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPropheticDecreeComposer();
      });
    }
  }

  Future<void> _loadPrayers({bool silent = false}) async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = false;
      });
    } else {
      _error = false;
    }
    try {
      final results = await Future.wait<dynamic>([
        _api.fetchPrayerFeed(user: user),
        _api.fetchActivePropheticDecree(),
        _api.fetchPrayerPoints(),
      ]);
      final feed = results[0] as PrayerFeed;
      _items = feed.requests;
      _setSubmissionStatus(feed.submissionStatus);
      _decree = results[1] as PropheticDecree?;
      _prayerPoints = results[2] as List<PrayerPoint>;
    } catch (e) {
      print(e);
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _setSubmissionStatus(PrayerSubmissionStatus status) {
    _cooldownTimer?.cancel();
    _submissionStatus = status;
    if (status.cooldownSeconds > 0) {
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final remaining = _submissionStatus.cooldownSeconds - 1;
        setState(() {
          _submissionStatus = PrayerSubmissionStatus(
            canSubmit: remaining <= 0,
            cooldownSeconds: remaining < 0 ? 0 : remaining,
            nextAvailableAt: _submissionStatus.nextAvailableAt,
            message: _submissionStatus.message,
          );
        });
        if (remaining <= 0) _cooldownTimer?.cancel();
      });
    }
  }

  String _cooldownText() {
    final seconds = _submissionStatus.cooldownSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }

  Future<void> _openComposer() async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) {
      showPrayerGuestPrompt(context);
      return;
    }
    if (!user.isVerified) {
      _showProfileGate(context);
      return;
    }
    if (!_submissionStatus.canSubmit) {
      Alerts.show(
        context,
        'Prayer request limit',
        'You can submit one prayer request every 24 hours. Try again in ${_cooldownText()}.',
      );
      return;
    }
    final created = await Navigator.push<PrayerRequest>(
      context,
      MaterialPageRoute(builder: (_) => PrayerComposerScreen(api: _api)),
    );
    if (created != null && mounted) {
      setState(() => _items.insert(0, created));
      await _loadPrayers();
    }
  }

  Future<void> _openPropheticDecreeComposer() async {
    final decree = await Navigator.push<PropheticDecree>(
      context,
      MaterialPageRoute(
        builder: (_) => PropheticDecreeComposerScreen(api: _api),
      ),
    );
    if (decree != null && mounted) {
      setState(() => _decree = decree);
    }
  }

  Future<void> _flagPrayer(PrayerRequest prayer) async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) {
      Navigator.pushNamed(context, LoginScreen.routeName);
      return;
    }
    if (!user.isVerified) {
      _showProfileGate(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Flag prayer request?'),
        content: Text(
            'Flag this request if it contains inappropriate, abusive, or unsafe content.'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: Text('Flag'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final count = await _api.flagPrayer(prayerId: prayer.id, user: user);
      if (!mounted) return;
      Alerts.show(
          context,
          'Flag submitted',
          count >= 3
              ? 'This request has been hidden for review.'
              : 'Thank you. The admin can review this request.');
      await _loadPrayers();
    } catch (e) {
      print(e);
      if (mounted) {
        Alerts.show(context, 'Error',
            _friendlyPrayerError(e, 'Unable to flag this request right now.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppStateManager>(context).userdata;
    final colors = _PrayerPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Interactive Prayer Wall')),
      floatingActionButton: FloatingActionButton(
        backgroundColor:
            _submissionStatus.canSubmit ? colors.fab : colors.muted,
        foregroundColor: colors.fabIcon,
        tooltip: _submissionStatus.canSubmit
            ? 'Add prayer request'
            : 'Available in ${_cooldownText()}',
        child: Icon(
          _submissionStatus.canSubmit ? Icons.add : Icons.lock_clock,
          color: colors.fabIcon,
        ),
        onPressed: _openComposer,
      ),
      body: Container(
        color: colors.background,
        child: _buildBody(user),
      ),
    );
  }

  Widget _buildBody(Userdata? user) {
    if (_loading) return Center(child: CupertinoActivityIndicator());
    if (_error) {
      return _EmptyState(
        icon: Icons.cloud_off,
        title: 'Unable to load prayers',
        message: 'Check your connection and tap to retry.',
        action: _loadPrayers,
      );
    }
    final canAddDecree = _canAddPropheticDecree(user);
    final colors = _PrayerPalette.of(context);
    return RefreshIndicator(
      onRefresh: _loadPrayers,
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 96),
        children: [
          _PrayerIntroPanel(
            requestCount: _items.length,
            hasPropheticDecree: _decree != null,
            cooldownLabel: _submissionStatus.canSubmit
                ? null
                : 'Next prayer in ${_cooldownText()}',
          ),
          SizedBox(height: 16),
          _PropheticDecreeCard(
            decree: _decree,
            canAdd: canAddDecree,
            onAdd: _openPropheticDecreeComposer,
          ),
          if (_prayerPoints.isNotEmpty) ...[
            SizedBox(height: 16),
            _PrayerPointsSection(points: _prayerPoints),
          ],
          if (_items.isEmpty)
            _EmptyState(
              icon: Icons.favorite_border,
              title: 'No interactive prayer requests on the wall yet',
              message:
                  'Be the first to share a request with the church community.',
              action: _openComposer,
            )
          else ...[
            Padding(
              padding: EdgeInsets.fromLTRB(2, 22, 2, 8),
              child: Text(
                'Prayer Wall',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ..._items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _PrayerCard(
                  prayer: item,
                  onFlag: () => _flagPrayer(item),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PrayerDetailScreen(api: _api, prayer: item),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _canAddPropheticDecree(Userdata? user) {
    return user != null && user.isVerified && user.isGeneralOverseer;
  }
}

class _PrayerPalette {
  const _PrayerPalette({
    required this.isDark,
    required this.background,
    required this.card,
    required this.softCard,
    required this.text,
    required this.muted,
    required this.border,
    required this.brand,
    required this.accent,
    required this.fab,
    required this.fabIcon,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color softCard;
  final Color text;
  final Color muted;
  final Color border;
  final Color brand;
  final Color accent;
  final Color fab;
  final Color fabIcon;

  static _PrayerPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PrayerPalette(
      isDark: isDark,
      background: isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
      card: isDark ? const Color(0xFF102532) : Colors.white,
      softCard: isDark ? const Color(0xFF132D3A) : const Color(0xFFFFF7FD),
      text: isDark ? Colors.white : const Color(0xFF102532),
      muted: isDark ? Colors.white60 : const Color(0xFF60707A),
      border: isDark ? Colors.white12 : const Color(0xFFE3EAF0),
      brand: const Color(0xFF0C2230),
      accent: const Color(0xFFFFC857),
      fab: isDark ? const Color(0xFFFFC857) : const Color(0xFF0C2230),
      fabIcon: isDark ? const Color(0xFF0C2230) : Colors.white,
    );
  }
}

class _PrayerIntroPanel extends StatelessWidget {
  const _PrayerIntroPanel({
    required this.requestCount,
    required this.hasPropheticDecree,
    this.cooldownLabel,
  });

  final int requestCount;
  final bool hasPropheticDecree;
  final String? cooldownLabel;

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPalette.of(context);
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C2230), Color(0xFF153F50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.28 : 0.12),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.volunteer_activism_outlined,
                color: Colors.white, size: 28),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Let\'s Pray Together',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  cooldownLabel ??
                      (hasPropheticDecree
                          ? 'Listen, share, and stand with the church community.'
                          : 'Share requests and encourage one another in prayer.'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '$requestCount',
                  style: TextStyle(
                    color: colors.brand,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'active',
                  style: TextStyle(
                    color: colors.brand.withValues(alpha: 0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class PrayerDetailScreen extends StatefulWidget {
  const PrayerDetailScreen({required this.api, required this.prayer});

  final PrayerApiClient api;
  final PrayerRequest prayer;

  @override
  State<PrayerDetailScreen> createState() => _PrayerDetailScreenState();
}

class _PrayerDetailScreenState extends State<PrayerDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  List<PrayerComment> _comments = [];
  bool _loading = true;
  bool _submitting = false;
  bool _anonymous = false;
  String? _audioPath;
  int _recordSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _cleanupAudio();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _cleanupAudio() async {
    if (_audioPath != null) {
      try {
        final file = File(_audioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error cleaning up audio file: $e');
      }
      _audioPath = null;
      _recordSeconds = 0;
    }
  }

  Future<void> _toggleRecording() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const VoiceRecordingDialog(
          maxDuration: 10,
          title: 'Record Response',
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _audioPath = result['path'] as String?;
        _recordSeconds = result['duration'] as int;
      });
    }
  }

  Future<void> _loadComments() async {
    try {
      _comments = await widget.api.fetchComments(widget.prayer.id);
    } catch (e) {
      print(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submitComment() async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (!_ensureVerifiedUser(user)) return;
    if (!widget.prayer.canComment) {
      Alerts.show(context, 'Prayer response',
          'You cannot respond to your own prayer request.');
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty && _audioPath == null) return;
    setState(() => _submitting = true);
    try {
      final comment = await widget.api.submitComment(
        prayerId: widget.prayer.id,
        user: user!,
        content: text,
        anonymous: _anonymous,
        audioPath: _audioPath,
        audioDuration: _audioPath == null ? 0 : _recordSeconds,
      );
      _commentController.clear();
      await _cleanupAudio();
      setState(() => _comments.add(comment));
    } catch (e) {
      print(e);
      Alerts.show(context, 'Error',
          _friendlyPrayerError(e, 'Unable to add your response right now.'));
    }
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _flagPrayer() async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (!_ensureVerifiedUser(user)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Flag prayer request?'),
        content: Text(
            'Flag this request if it contains inappropriate, abusive, or unsafe content.'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: Text('Flag'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final count = await widget.api.flagPrayer(
        prayerId: widget.prayer.id,
        user: user!,
      );
      if (mounted) {
        Alerts.show(
            context,
            'Flag submitted',
            count >= 3
                ? 'This request has been hidden for review.'
                : 'Thank you. The admin can review this request.');
      }
    } catch (e) {
      print(e);
      if (mounted) {
        Alerts.show(context, 'Error',
            _friendlyPrayerError(e, 'Unable to flag this request right now.'));
      }
    }
  }

  bool _ensureVerifiedUser(Userdata? user) {
    if (user == null) {
      Navigator.pushNamed(context, LoginScreen.routeName);
      return false;
    }
    if (user.activated == 1) {
      _showProfileGate(context);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPalette.of(context);
    final canRespond = widget.prayer.canComment;
    return Scaffold(
      appBar: AppBar(title: Text('Prayer Wall Post')),
      backgroundColor: colors.background,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(14),
              children: [
                _PrayerCard(
                  prayer: widget.prayer,
                  expanded: true,
                  onFlag: _flagPrayer,
                ),
                SizedBox(height: 18),
                Text('Responses',
                    style: TextStyle(
                        color: colors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                if (_loading)
                  Center(child: CupertinoActivityIndicator())
                else if (_comments.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 26),
                    child: Center(
                        child: Text('No responses yet.',
                            style: TextStyle(color: colors.muted))),
                  )
                else
                  ..._comments.map((comment) => _CommentTile(comment: comment)),
              ],
            ),
          ),
          SafeArea(
            child: Container(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                color: colors.card,
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: canRespond
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _anonymous,
                              onChanged: (value) =>
                                  setState(() => _anonymous = value ?? false),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Respond anonymously',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_audioPath != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.redAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.info_outline,
                                        size: 12, color: Colors.redAccent),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Auto-deletes on expiry',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_audioPath != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: 8.0, left: 8.0, right: 8.0),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: colors.isDark
                                    ? Colors.black26
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.graphic_eq,
                                      color: colors.accent, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Voice Response (${_recordSeconds}s)',
                                      style: TextStyle(
                                        color: colors.text,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  _LocalAudioButton(path: _audioPath!),
                                  SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _cleanupAudio()),
                                    child: Icon(Icons.cancel,
                                        color: Colors.redAccent.shade200,
                                        size: 20),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        Row(
                          children: [
                            Material(
                              color: _audioPath != null
                                  ? colors.muted.withValues(alpha: 0.32)
                                  : colors.brand,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _audioPath != null
                                    ? null
                                    : _toggleRecording,
                                child: SizedBox(
                                  width: 46,
                                  height: 46,
                                  child: Icon(
                                    Icons.mic_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                minLines: 1,
                                maxLines: 3,
                                decoration: InputDecoration(
                                    hintText: 'Write a response...'),
                              ),
                            ),
                            SizedBox(width: 8),
                            _submitting
                                ? CupertinoActivityIndicator()
                                : IconButton(
                                    icon: Icon(Icons.send,
                                        color: colors.isDark
                                            ? colors.accent
                                            : colors.brand),
                                    onPressed: _submitComment,
                                  ),
                          ],
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, color: colors.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You cannot respond to your own prayer request.',
                              style: TextStyle(
                                color: colors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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

class PrayerComposerScreen extends StatefulWidget {
  const PrayerComposerScreen({required this.api});

  final PrayerApiClient api;

  @override
  State<PrayerComposerScreen> createState() => _PrayerComposerScreenState();
}

class _PrayerComposerScreenState extends State<PrayerComposerScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _anonymous = false;
  bool _submitting = false;
  bool _aiBusy = false;
  String? _audioPath;
  int _recordSeconds = 0;
  List<String> _suggestions = [
    'Healing',
    'Family',
    'Guidance',
    'Breakthrough',
    'Thanksgiving',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const VoiceRecordingDialog(
          maxDuration: 30,
          title: 'Record Prayer',
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _audioPath = result['path'] as String?;
        _recordSeconds = result['duration'] as int;
      });
    }
  }

  Future<void> _rewrite() async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) {
      Navigator.pushNamed(context, LoginScreen.routeName);
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _aiBusy = true);
    try {
      final rewrite = await widget.api.rewritePrayer(user, text);
      if (rewrite.isNotEmpty) _controller.text = rewrite;
    } catch (e) {
      print(e);
      Alerts.show(context, 'Error', 'The rewrite service is unavailable.');
    }
    if (mounted) setState(() => _aiBusy = false);
  }

  Future<void> _suggest() async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) {
      Navigator.pushNamed(context, LoginScreen.routeName);
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final suggestions =
          await widget.api.suggestPrayers(user, _controller.text);
      if (suggestions.isNotEmpty) setState(() => _suggestions = suggestions);
    } catch (e) {
      print(e);
      Alerts.show(context, 'Error', 'The suggestion service is unavailable.');
    }
    if (mounted) setState(() => _aiBusy = false);
  }

  Future<bool> _pickAvatarIfMissing(Userdata user) async {
    // Profile images are optional for prayer requests. The public card can
    // safely fall back to initials/avatar placeholders.
    return true;
  }

  Future<void> _submit() async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) {
      Navigator.pushNamed(context, LoginScreen.routeName);
      return;
    }
    if (user.activated == 1) {
      _showProfileGate(context);
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty && _audioPath == null) {
      Alerts.show(context, 'Prayer Required',
          'Write a prayer request or record a voice prayer.');
      return;
    }
    final hasProfileImage = await _pickAvatarIfMissing(user);
    if (!hasProfileImage) return;
    setState(() => _submitting = true);
    try {
      final prayer = await widget.api.submitPrayer(
        user: Provider.of<AppStateManager>(context, listen: false).userdata!,
        content: text,
        anonymous: _anonymous,
        audioPath: _audioPath,
        audioDuration:
            _audioPath == null ? 0 : _recordSeconds.clamp(1, 30).toInt(),
      );
      Navigator.pop(context, prayer);
    } catch (e) {
      print(e);
      Alerts.show(context, 'Error',
          _friendlyPrayerError(e, 'Unable to submit your prayer right now.'));
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Share Prayer'),
        actions: [
          TextButton(
            child: _submitting
                ? CupertinoActivityIndicator()
                : Text('POST', style: TextStyle(color: Colors.white)),
            onPressed: _submitting ? null : _submit,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your prayer request will automatically expire and delete after 24 hours.',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TextField(
              controller: _controller,
              minLines: 7,
              maxLines: 12,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Share what you want the community to pray about...',
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((text) {
                return ActionChip(
                  label: Text(text),
                  onPressed: () {
                    final current = _controller.text.trim();
                    _controller.text =
                        current.isEmpty ? text : '$current\n$text';
                  },
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                FloatingActionButton(
                  heroTag: 'prayer_mic',
                  backgroundColor: colors.fab,
                  child: Icon(
                    Icons.mic,
                    color: colors.fabIcon,
                  ),
                  onPressed: _toggleRecording,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _audioPath == null
                        ? 'Record voice prayer, up to 30 seconds'
                        : 'Voice prayer attached (${_recordSeconds}s)',
                    style: TextStyle(color: colors.text),
                  ),
                ),
                if (_audioPath != null) _LocalAudioButton(path: _audioPath!),
                if (_audioPath != null)
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => setState(() {
                      _audioPath = null;
                      _recordSeconds = 0;
                    }),
                  ),
              ],
            ),
            SizedBox(height: 16),
            SwitchListTile(
              value: _anonymous,
              contentPadding: EdgeInsets.zero,
              title: Text('Post anonymously'),
              subtitle: Text('Your name and profile image will be hidden.',
                  style: TextStyle(color: colors.muted)),
              onChanged: (value) => setState(() => _anonymous = value),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: Icon(Icons.auto_fix_high),
                  label: Text('Rewrite'),
                  onPressed: _aiBusy ? null : _rewrite,
                ),
                SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: Icon(Icons.lightbulb_outline),
                  label: Text('Suggest'),
                  onPressed: _aiBusy ? null : _suggest,
                ),
                if (_aiBusy) ...[
                  SizedBox(width: 12),
                  CupertinoActivityIndicator(),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PropheticDecreeComposerScreen extends StatefulWidget {
  const PropheticDecreeComposerScreen({required this.api});

  final PrayerApiClient api;

  @override
  State<PropheticDecreeComposerScreen> createState() =>
      _PropheticDecreeComposerScreenState();
}

class _PropheticDecreeComposerScreenState
    extends State<PropheticDecreeComposerScreen> {
  final TextEditingController _labelController =
      TextEditingController(text: 'Daily Prophet Decree');
  bool _submitting = false;
  String? _audioPath;
  int _recordSeconds = 0;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const VoiceRecordingDialog(
          maxDuration: 180,
          title: 'Daily Prophet Decree',
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _audioPath = result['path'] as String?;
        _recordSeconds = result['duration'] as int;
      });
    }
  }

  Future<void> _submit() async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) {
      Navigator.pushNamed(context, LoginScreen.routeName);
      return;
    }
    if (!user.isVerified) {
      _showProfileGate(context);
      return;
    }
    if (!user.isGeneralOverseer) {
      Alerts.show(context, 'Restricted',
          'Only verified users with the G.O role can add a daily prophet decree.');
      return;
    }
    final audioPath = _audioPath;
    if (audioPath == null || audioPath.isEmpty) {
      Alerts.show(context, 'Audio Required',
          'Record a daily prophet decree before submitting.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final decree = await widget.api.submitPropheticDecree(
        user: user,
        label: _labelController.text.trim().isEmpty
            ? 'Daily Prophet Decree'
            : _labelController.text.trim(),
        audioPath: audioPath,
        audioDuration: _recordSeconds.clamp(1, 180).toInt(),
      );
      Navigator.pop(context, decree);
    } catch (e) {
      print(e);
      Alerts.show(
          context,
          'Error',
          _friendlyPrayerError(
              e, 'Unable to submit the daily prophet decree right now.'));
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Add Daily Prophet Decree'),
        actions: [
          TextButton(
            child: _submitting
                ? CupertinoActivityIndicator()
                : Text('SUBMIT', style: TextStyle(color: Colors.white)),
            onPressed: _submitting ? null : _submit,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                labelText: 'Label',
              ),
            ),
            SizedBox(height: 18),
            Row(
              children: [
                FloatingActionButton(
                  heroTag: 'prophetic_decree_mic',
                  backgroundColor: colors.fab,
                  child: Icon(
                    Icons.mic,
                    color: colors.fabIcon,
                  ),
                  onPressed: _toggleRecording,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _audioPath == null
                        ? 'Record daily prophet decree audio (up to 3 minutes)'
                        : 'Daily prophet decree attached (${_recordSeconds}s)',
                    style: TextStyle(color: colors.text),
                  ),
                ),
                if (_audioPath != null) _LocalAudioButton(path: _audioPath!),
                if (_audioPath != null)
                  IconButton(
                    icon: Icon(Icons.close),
                    tooltip: 'Replace recording',
                    onPressed: () => setState(() {
                      _audioPath = null;
                      _recordSeconds = 0;
                    }),
                  ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Submitting will replace the active Daily Prophet Decree shown above Interactive Prayer Wall.',
              style: TextStyle(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerPointsSection extends StatelessWidget {
  const _PrayerPointsSection({required this.points});

  final List<PrayerPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: colors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Prayer Points',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...points.map(
          (point) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PrayerPointCard(point: point),
          ),
        ),
      ],
    );
  }
}

class _PrayerPointCard extends StatelessWidget {
  const _PrayerPointCard({required this.point});

  final PrayerPoint point;

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPalette.of(context);
    final plainContent = _plainPrayerPointContent(point.content);
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.16 : 0.06),
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
              aspectRatio: 16 / 8,
              child: CachedNetworkImage(
                imageUrl: point.thumbnailUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: colors.softCard,
                  alignment: Alignment.center,
                  child: Icon(Icons.image_not_supported_outlined,
                      color: colors.muted),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.favorite_border_rounded,
                          color: colors.accent),
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
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _prayerPointMeta(point),
                            style: TextStyle(
                              color: colors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plainContent,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text.withValues(alpha: 0.88),
                    height: 1.4,
                    fontSize: 15,
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

String _plainPrayerPointContent(String value) {
  return value
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _prayerPointMeta(PrayerPoint point) {
  final parts = <String>[];
  if (point.author.trim().isNotEmpty) parts.add(point.author.trim());
  if (point.date > 0) parts.add(TimUtil.formatFullDatestamp(point.date));
  return parts.isEmpty ? 'Prayer point' : parts.join(' - ');
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({
    required this.prayer,
    this.onTap,
    this.onFlag,
    this.expanded = false,
  });

  final PrayerRequest prayer;
  final VoidCallback? onTap;
  final VoidCallback? onFlag;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPalette.of(context);
    final text = expanded || prayer.content.length < 150
        ? prayer.content
        : prayer.content.substring(0, 150).trim() + '...';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(alpha: colors.isDark ? 0.20 : 0.06),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(url: prayer.displayAvatar),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prayer.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        prayer.date > 0
                            ? TimUtil.formatFullDatestamp(prayer.date)
                            : 'Shared recently',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if ((prayer.audioUrl ?? '').isNotEmpty)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (colors.isDark ? colors.accent : colors.brand)
                          .withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.graphic_eq,
                        size: 18,
                        color: colors.isDark ? colors.accent : colors.brand),
                  ),
                if (onFlag != null)
                  IconButton(
                    tooltip: 'Flag as inappropriate',
                    icon: Icon(Icons.flag_outlined,
                        size: 20, color: Colors.redAccent),
                    onPressed: onFlag,
                  ),
              ],
            ),
            SizedBox(height: 12),
            Text(prayer.title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.18,
                )),
            SizedBox(height: 6),
            Text(
              text,
              style: TextStyle(
                color: colors.isDark ? Colors.white70 : const Color(0xFF263B43),
                height: 1.42,
              ),
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.mode_comment_outlined,
                    size: 18, color: colors.muted),
                SizedBox(width: 6),
                Text(
                  prayer.commentsCount == 1
                      ? '1 response'
                      : '${prayer.commentsCount} responses',
                  style: TextStyle(
                    color: colors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((prayer.audioUrl ?? '').isNotEmpty) ...[
                  Spacer(),
                  _AudioPreviewButton(source: prayer.audioUrl!, isLocal: false),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PropheticDecreeCard extends StatelessWidget {
  const _PropheticDecreeCard({
    required this.decree,
    required this.canAdd,
    required this.onAdd,
  });

  final PropheticDecree? decree;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPalette.of(context);
    final item = decree;
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.softCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.18 : 0.05),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (colors.isDark ? colors.accent : colors.brand)
                      .withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.campaign,
                    color: colors.isDark ? colors.accent : colors.brand,
                    size: 23),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item?.label ?? 'Daily Prophet Decree',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 20,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (canAdd) ...[
                      SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(Icons.mic,
                              size: 17,
                              color:
                                  colors.isDark ? colors.accent : colors.brand),
                          label: Text('Add Daily Prophet Decree'),
                          onPressed: onAdd,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (item == null)
            Text(
              'No active Daily Prophet Decree is available yet.',
              style: TextStyle(color: colors.muted),
            )
          else ...[
            Row(
              children: [
                _Avatar(url: item.goAvatar, size: 44),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.displayName,
                          style: TextStyle(
                              color: colors.text, fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text(
                        item.date > 0
                            ? TimUtil.formatFullDatestamp(item.date)
                            : 'Date unavailable',
                        style: TextStyle(color: colors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (item.hasAudio)
              _RemoteAudioPreview(
                url: item.audioUrl,
                label:
                    "Listen to today's decree from PATO, tap the button to play",
                prominent: true,
              )
            else
              Text('Audio preview unavailable.',
                  style: TextStyle(color: colors.muted)),
          ],
        ],
      ),
    );
  }
}

class _RemoteAudioPreview extends StatelessWidget {
  const _RemoteAudioPreview({
    required this.url,
    this.label,
    this.prominent = false,
  });

  final String url;
  final String? label;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPalette.of(context);
    return Row(
      children: [
        _AudioPreviewButton(
          source: url,
          isLocal: false,
          prominent: prominent,
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            label ?? 'Tap to play voice message',
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _LocalAudioButton extends StatelessWidget {
  const _LocalAudioButton({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return _AudioPreviewButton(source: path, isLocal: true);
  }
}

class _AudioPreviewButton extends StatefulWidget {
  const _AudioPreviewButton({
    required this.source,
    required this.isLocal,
    this.prominent = false,
  });

  final String source;
  final bool isLocal;
  final bool prominent;

  @override
  State<_AudioPreviewButton> createState() => _AudioPreviewButtonState();
}

class _AudioPreviewButtonState extends State<_AudioPreviewButton>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  late final AnimationController _pulseController;
  bool _loading = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
      lowerBound: 0.92,
      upperBound: 1.15,
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _AudioPreviewButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _controller?.pause();
      _controller?.dispose();
      _controller = null;
      _playing = false;
      _loading = false;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _controller?.pause();
      if (mounted) {
        setState(() {
          _playing = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    try {
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      String path;
      if (widget.isLocal) {
        final file = File(widget.source);
        if (!await file.exists() || await file.length() == 0) {
          throw StateError('Recorded audio file is empty.');
        }
        path = widget.source;
      } else {
        path = await _downloadRemoteAudio(widget.source);
      }

      final controller = VideoPlayerController.file(File(path));
      _controller = controller;
      await controller.initialize();

      controller.addListener(() {
        if (!mounted) return;
        final isPlaying = controller.value.isPlaying;
        final isCompleted =
            controller.value.position >= controller.value.duration;

        setState(() {
          _playing = isPlaying;
          _loading = controller.value.isBuffering;
        });

        if (isCompleted && isPlaying) {
          controller.pause();
          controller.seekTo(Duration.zero);
          setState(() {
            _playing = false;
          });
        }
      });

      await controller.play();
      if (mounted) {
        setState(() {
          _playing = true;
          _loading = false;
        });
      }
    } catch (e) {
      print(e);
      if (mounted) {
        Alerts.show(context, 'Playback Error', 'Unable to play this audio.');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<String> _downloadRemoteAudio(String url) async {
    final dir = Directory(
      '${(await getApplicationSupportDirectory()).path}/prayer_audio_cache',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _trimPrayerAudioCache(dir);

    final cached = await _findCachedAudio(dir, url);
    if (cached != null) {
      return cached.path;
    }

    final dio = Dio();
    final response = await dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'audio/*'},
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Downloaded audio file is empty.');
    }

    final extension = _audioExtensionFromHeaders(response.headers) ??
        _audioExtensionFromUrl(url) ??
        'wav';
    final file =
        File('${dir.path}/prayer_audio_${url.hashCode.abs()}.$extension');
    final projectedSize = await _directorySize(dir) + bytes.length;
    if (projectedSize > _maxPrayerAudioCacheBytes) {
      await _trimPrayerAudioCache(dir, requiredFreeBytes: bytes.length);
    }

    if ((await _directorySize(dir) + bytes.length) >
        _maxPrayerAudioCacheBytes) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/prayer_audio_${url.hashCode.abs()}.$extension',
      );
      await tempFile.writeAsBytes(bytes, flush: true);
      return tempFile.path;
    }

    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static const int _maxPrayerAudioCacheBytes = 200 * 1024 * 1024;

  Future<File?> _findCachedAudio(Directory dir, String url) async {
    final prefix = 'prayer_audio_${url.hashCode.abs()}.';
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && entity.uri.pathSegments.last.startsWith(prefix)) {
        if (await entity.length() > 0) return entity;
      }
    }
    return null;
  }

  Future<void> _trimPrayerAudioCache(
    Directory dir, {
    int requiredFreeBytes = 0,
  }) async {
    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) files.add(entity);
    }

    var total = 0;
    final fileStats = <_CachedAudioFile>[];
    for (final file in files) {
      try {
        final stat = await file.stat();
        total += stat.size;
        fileStats.add(_CachedAudioFile(file, stat.size, stat.changed));
      } catch (_) {}
    }

    final target = _maxPrayerAudioCacheBytes - requiredFreeBytes;
    if (total <= target) return;

    fileStats.sort((a, b) => a.changed.compareTo(b.changed));
    for (final item in fileStats) {
      if (total <= target) break;
      try {
        await item.file.delete();
        total -= item.size;
      } catch (_) {}
    }
  }

  Future<int> _directorySize(Directory dir) async {
    var total = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  String? _audioExtensionFromHeaders(Headers headers) {
    final disposition = headers.value('content-disposition') ?? '';
    final filenameMatch = RegExp(r'filename="?([^";]+)"?')
        .firstMatch(disposition.replaceAll("'", ''));
    if (filenameMatch != null) {
      final filename = filenameMatch.group(1) ?? '';
      final dot = filename.lastIndexOf('.');
      if (dot >= 0 && dot < filename.length - 1) {
        return filename.substring(dot + 1).toLowerCase();
      }
    }

    final contentType = headers.value('content-type')?.toLowerCase() ?? '';
    if (contentType.contains('mpeg')) return 'mp3';
    if (contentType.contains('mp4') || contentType.contains('aac'))
      return 'm4a';
    if (contentType.contains('ogg')) return 'ogg';
    if (contentType.contains('webm')) return 'webm';
    if (contentType.contains('wav') || contentType.contains('wave'))
      return 'wav';
    return null;
  }

  String? _audioExtensionFromUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    for (final extension in ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'webm']) {
      if (path.endsWith('.$extension')) return extension;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPalette.of(context);
    final icon = _loading
        ? CupertinoActivityIndicator(
            color: colors.isDark ? colors.accent : colors.brand)
        : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded);
    final baseColor = colors.isDark ? colors.accent : colors.brand;

    if (!widget.prominent) {
      return IconButton(
        icon: _loading
            ? CupertinoActivityIndicator()
            : Icon(
                _playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
        color: baseColor,
        iconSize: 34,
        onPressed: _loading ? null : _toggle,
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _playing ? 1.0 : _pulseController.value;
        return Transform.scale(
          scale: pulse,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
              Material(
                color: baseColor,
                shape: const CircleBorder(),
                elevation: 6,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _loading ? null : _toggle,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: IconTheme(
                      data: const IconThemeData(
                        color: Colors.white,
                        size: 30,
                      ),
                      child: Center(child: icon),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _friendlyPrayerError(Object error, String fallback) {
  if (error is PrayerApiException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  final message = error.toString().replaceFirst('Exception: ', '').trim();
  if (message.isNotEmpty &&
      !message.contains('DioException') &&
      !message.contains('Instance of')) {
    return message;
  }
  return fallback;
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final PrayerComment comment;

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPalette.of(context);
    final hasAudio = comment.audioUrl != null && comment.audioUrl!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(url: comment.displayAvatar, size: 34),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.displayName,
                    style: TextStyle(
                        color: colors.text, fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                if (comment.content.isNotEmpty)
                  Text(comment.content,
                      style: TextStyle(
                          color: colors.isDark
                              ? Colors.white70
                              : const Color(0xFF263B43))),
                if (hasAudio) ...[
                  if (comment.content.isNotEmpty) SizedBox(height: 6),
                  _RemoteAudioPreview(
                    url: comment.audioUrl!,
                    label: 'Play voice message',
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

class _CachedAudioFile {
  const _CachedAudioFile(this.file, this.size, this.changed);

  final File file;
  final int size;
  final DateTime changed;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, this.size = 42});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPalette.of(context);
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: colors.isDark ? Colors.white12 : Colors.grey.shade300,
        child: url.isEmpty
            ? Icon(Icons.person, color: Colors.white, size: size * .62)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Icon(Icons.person, color: Colors.white),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPalette.of(context);
    return InkWell(
      onTap: action,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 54,
                  color: colors.isDark ? colors.accent : colors.brand),
              SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: colors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

void _showProfileGate(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => CupertinoAlertDialog(
      title: Text('Profile Required'),
      content: Text(
          'Please complete your profile before joining the Interactive Prayer Wall.'),
      actions: [
        CupertinoDialogAction(
          child: Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        CupertinoDialogAction(
          child: Text('Update'),
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, UpdateUserProfile.routeName);
          },
        ),
      ],
    ),
  );
}
