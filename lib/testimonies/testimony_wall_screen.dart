import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../auth/LoginScreen.dart';
import '../providers/AppStateManager.dart';
import '../socials/UpdateUserProfile.dart';
import '../utils/Alerts.dart';
import '../utils/my_colors.dart';
import '../prayers/voice_recording_dialog.dart';
import 'testimony_api_client.dart';
import 'testimony_models.dart';

class TestimonyWallScreen extends StatefulWidget {
  const TestimonyWallScreen({super.key});

  static const routeName = '/testimonies';

  @override
  State<TestimonyWallScreen> createState() => _TestimonyWallScreenState();
}

class _TestimonyWallScreenState extends State<TestimonyWallScreen> {
  final _api = TestimonyApiClient();
  List<Testimony> _items = [];
  bool _loading = true;
  bool _disabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cachedEnabled = _api.cachedEnabled;
    final cachedItems = _api.cachedTestimonies;
    if (cachedEnabled != null || cachedItems != null) {
      _disabled = cachedEnabled == false;
      _items = cachedItems ?? const [];
      _loading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(silent: true));
    } else {
      _load();
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      _error = null;
    }
    try {
      final enabled = await _api.isEnabled();
      if (!enabled) {
        setState(() {
          _disabled = true;
          _items = [];
          _loading = false;
        });
        return;
      }
      final items = await _api.fetchTestimonies();
      if (!mounted) return;
      setState(() {
        _disabled = false;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is TestimonyApiException
            ? e.message
            : 'Unable to load testimonies right now.';
        _loading = false;
      });
    }
  }

  void _startSubmitFlow() {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) {
      _showGuestPrompt();
      return;
    }
    if (!user.isVerified) {
      showDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Verify your account'),
          content: const Text(
              'Please verify your email address before sharing a testimony.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Later'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              child: const Text('Update profile'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, UpdateUserProfile.routeName);
              },
            ),
          ],
        ),
      );
      return;
    }
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SubmitTestimonyScreen(api: _api)),
    ).then((created) {
      if (created == true) _load();
    });
  }

  void _showGuestPrompt() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Share your testimony'),
        content: const Text(
          'Sign in or create an account to share testimonies and thanksgiving moments with the church family. Every testimony is reviewed by the admin team before it appears publicly.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, LoginScreen.routeName);
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _TestimonyPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Testimonies & Thanksgiving')),
      floatingActionButton: _disabled
          ? null
          : FloatingActionButton.extended(
              onPressed: _startSubmitFlow,
              backgroundColor: const Color(0xFFFFB522),
              foregroundColor: const Color(0xFF0C2230),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Share'),
            ),
      body: RefreshIndicator(
        color: const Color(0xFFFFC857),
        onRefresh: _load,
        child: _body(colors),
      ),
    );
  }

  Widget _body(_TestimonyPalette colors) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_disabled) {
      return _StatePanel(
        icon: Icons.visibility_off_outlined,
        title: 'Testimonies are unavailable',
        message:
            'This church module is currently turned off by the admin team.',
        onRetry: _load,
      );
    }
    if (_error != null) {
      return _StatePanel(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load testimonies',
        message: _error!,
        onRetry: _load,
      );
    }
    if (_items.isEmpty) {
      return _StatePanel(
        icon: Icons.auto_awesome_rounded,
        title: 'No approved testimonies yet',
        message:
            'When testimonies are approved by the admin team, they will appear here for the church family.',
        onRetry: _load,
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
      itemBuilder: (context, index) => _TestimonyCard(item: _items[index]),
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemCount: _items.length,
    );
  }
}

class SubmitTestimonyScreen extends StatefulWidget {
  const SubmitTestimonyScreen({super.key, required this.api});

  final TestimonyApiClient api;

  @override
  State<SubmitTestimonyScreen> createState() => _SubmitTestimonyScreenState();
}

class _SubmitTestimonyScreenState extends State<SubmitTestimonyScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _audioPath;
  int _audioSeconds = 0;
  bool _anonymous = true;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const VoiceRecordingDialog(
        maxDuration: 120,
        title: 'Record Testimony',
      ),
    );
    if (result == null) return;
    setState(() {
      _audioPath = result['path'] as String?;
      _audioSeconds = result['duration'] as int? ?? 0;
    });
  }

  Future<void> _setAnonymousPreference(bool value) async {
    if (value) {
      setState(() => _anonymous = true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Share with your name?'),
        content: const Text(
          'If you turn anonymous off, other users will be able to know who shared this testimony.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Keep anonymous'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Share with my name'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _anonymous = false);
    }
  }

  Future<void> _submit() async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (user == null) return;
    if (title.isEmpty || body.isEmpty) {
      Alerts.show(context, 'Testimony required',
          'Please add a title and write your testimony before submitting.');
      return;
    }
    if ((_audioPath ?? '').isNotEmpty &&
        (_audioSeconds <= 0 || _audioSeconds > 120)) {
      Alerts.show(context, 'Audio testimony',
          'Audio testimonies must be between 1 and 120 seconds.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.api.submit(
        user: user,
        title: title,
        body: body,
        anonymous: _anonymous,
        audioPath: _audioPath,
        audioDuration: _audioSeconds,
      );
      if (!mounted) return;
      await Alerts.show(context, 'Submitted for approval',
          'Thank you for sharing. Your testimony will appear after admin approval.');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      Alerts.show(context, 'Unable to submit',
          e is TestimonyApiException ? e.message : 'Please try again shortly.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _TestimonyPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Share Testimony'),
        actions: [
          IconButton(
            onPressed: _submitting ? null : _submit,
            tooltip: 'Submit testimony',
            icon: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _HeroPanel(colors: colors),
          const SizedBox(height: 18),
          _FieldCard(
            child: Column(
              children: [
                TextField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Testimony title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _body,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Tell the story',
                    prefixIcon: Icon(Icons.auto_awesome_rounded),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _record,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB522),
                        foregroundColor: const Color(0xFF0C2230),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.mic_rounded),
                      label: Text(_audioPath == null
                          ? 'Record audio'
                          : 'Audio attached (${_audioSeconds}s)'),
                    ),
                    if (_audioPath != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Remove audio',
                        onPressed: () => setState(() {
                          _audioPath = null;
                          _audioSeconds = 0;
                        }),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _AnonymousChoiceCard(
                  value: _anonymous,
                  onChanged: _setAnonymousPreference,
                  colors: colors,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB522),
                      foregroundColor: const Color(0xFF0C2230),
                      disabledBackgroundColor:
                          const Color(0xFFFFB522).withValues(alpha: 0.62),
                      disabledForegroundColor:
                          const Color(0xFF0C2230).withValues(alpha: 0.72),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0C2230),
                            ),
                          )
                        : const Icon(Icons.verified_rounded),
                    label: Text(_submitting
                        ? 'Submitting testimony...'
                        : 'Submit for review'),
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

class _TestimonyCard extends StatefulWidget {
  const _TestimonyCard({required this.item});

  final Testimony item;

  @override
  State<_TestimonyCard> createState() => _TestimonyCardState();
}

class _TestimonyCardState extends State<_TestimonyCard> {
  VideoPlayerController? _controller;
  bool _loadingAudio = false;
  bool _playing = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final url = widget.item.audioUrl;
    if (url == null || url.isEmpty) return;
    if (_playing) {
      await _controller?.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }

    setState(() => _loadingAudio = true);
    try {
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      final path = await _downloadRemoteAudio(url);
      final controller = VideoPlayerController.file(File(path));
      _controller = controller;
      await controller.initialize();

      controller.addListener(() {
        if (!mounted) return;
        final completed =
            controller.value.position >= controller.value.duration &&
                controller.value.duration > Duration.zero;
        setState(() {
          _playing = controller.value.isPlaying;
          _loadingAudio = controller.value.isBuffering;
        });
        if (completed && controller.value.isPlaying) {
          controller.pause();
          controller.seekTo(Duration.zero);
          setState(() => _playing = false);
        }
      });

      await controller.play();
      if (mounted) {
        setState(() {
          _playing = true;
          _loadingAudio = false;
        });
      }
    } catch (e) {
      debugPrint('Testimony audio playback failed: $e');
      if (mounted)
        Alerts.show(
            context, 'Playback error', 'Unable to play this testimony audio.');
    }
    if (mounted) setState(() => _loadingAudio = false);
  }

  Future<String> _downloadRemoteAudio(String url) async {
    final dir = Directory(
      '${(await getApplicationSupportDirectory()).path}/testimony_audio_cache',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _trimAudioCache(dir);

    final cached = await _findCachedAudio(dir, url);
    if (cached != null) return cached.path;

    final response = await Dio().get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'audio/*'},
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Downloaded testimony audio file is empty.');
    }

    final extension = _audioExtensionFromHeaders(response.headers) ??
        _audioExtensionFromUrl(url) ??
        'wav';
    final file =
        File('${dir.path}/testimony_audio_${url.hashCode.abs()}.$extension');
    final projectedSize = await _directorySize(dir) + bytes.length;
    if (projectedSize > _maxAudioCacheBytes) {
      await _trimAudioCache(dir, requiredFreeBytes: bytes.length);
    }

    if ((await _directorySize(dir) + bytes.length) > _maxAudioCacheBytes) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/testimony_audio_${url.hashCode.abs()}.$extension',
      );
      await tempFile.writeAsBytes(bytes, flush: true);
      return tempFile.path;
    }

    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static const int _maxAudioCacheBytes = 200 * 1024 * 1024;

  Future<File?> _findCachedAudio(Directory dir, String url) async {
    final prefix = 'testimony_audio_${url.hashCode.abs()}.';
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && entity.uri.pathSegments.last.startsWith(prefix)) {
        if (await entity.length() > 0) return entity;
      }
    }
    return null;
  }

  Future<void> _trimAudioCache(
    Directory dir, {
    int requiredFreeBytes = 0,
  }) async {
    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) files.add(entity);
    }

    var total = 0;
    final fileStats = <_CachedTestimonyAudioFile>[];
    for (final file in files) {
      try {
        final stat = await file.stat();
        total += stat.size;
        fileStats.add(_CachedTestimonyAudioFile(file, stat.size, stat.changed));
      } catch (_) {}
    }

    final target = _maxAudioCacheBytes - requiredFreeBytes;
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
    if (contentType.contains('wav') || contentType.contains('wave')) {
      return 'wav';
    }
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
    final colors = _TestimonyPalette.of(context);
    final item = widget.item;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.22 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CardGraphicPainter())),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(url: item.avatar, anonymous: item.isAnonymous),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.identity,
                            style: TextStyle(
                                color: colors.text,
                                fontWeight: FontWeight.w900,
                                fontSize: 16)),
                        if ((item.countryOfResidence ?? '').isNotEmpty)
                          Text(
                              '${item.countryFlag ?? '🌍'} ${item.countryOfResidence}',
                              style:
                                  TextStyle(color: colors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified_rounded, color: Color(0xFFFFB522)),
                ],
              ),
              const SizedBox(height: 16),
              Text(item.title,
                  style: TextStyle(
                      color: colors.text,
                      fontSize: 20,
                      height: 1.12,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(item.body,
                  style: TextStyle(
                      color: colors.body, fontSize: 15, height: 1.48)),
              if ((item.audioUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _toggle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C2230),
                    foregroundColor: Colors.white,
                  ),
                  icon: _loadingAudio
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : Icon(_playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                  label: Text(_loadingAudio
                      ? 'Preparing audio...'
                      : (_playing
                          ? 'Pause audio testimony'
                          : 'Play audio testimony')),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AnonymousChoiceCard extends StatelessWidget {
  const _AnonymousChoiceCard({
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final _TestimonyPalette colors;

  @override
  Widget build(BuildContext context) {
    final accent = value ? const Color(0xFFFFB522) : const Color(0xFF0C2230);
    final surface = value
        ? const Color(0xFFFFB522).withValues(alpha: colors.isDark ? 0.16 : 0.13)
        : colors.background;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: value
                ? const Color(0xFFFFB522)
                : colors.border.withValues(alpha: colors.isDark ? 0.9 : 1),
            width: value ? 1.8 : 1.2,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFB522)
                        .withValues(alpha: colors.isDark ? 0.14 : 0.2),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                value ? Icons.visibility_off_rounded : Icons.person_rounded,
                color: value ? const Color(0xFF0C2230) : Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Share anonymously',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ),
                      if (value) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB522),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'ON',
                            style: TextStyle(
                              color: Color(0xFF0C2230),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value
                        ? 'Anonymous is on. People will not know you submitted this testimony.'
                        : "Turn this on if you don't want people to know you submitted this testimony.",
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Transform.scale(
              scale: 1.08,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF0C2230),
                activeTrackColor: const Color(0xFFFFB522),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: colors.isDark
                    ? Colors.white.withValues(alpha: 0.24)
                    : const Color(0xFFC8D1D6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CachedTestimonyAudioFile {
  const _CachedTestimonyAudioFile(this.file, this.size, this.changed);

  final File file;
  final int size;
  final DateTime changed;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.anonymous});

  final String? url;
  final bool anonymous;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url ?? '';
    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFFFFC857).withValues(alpha: 0.18),
      backgroundImage: imageUrl.isEmpty || anonymous
          ? null
          : CachedNetworkImageProvider(imageUrl),
      child: imageUrl.isEmpty || anonymous
          ? const Icon(Icons.person_outline_rounded, color: Color(0xFF0C2230))
          : null,
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.colors});

  final _TestimonyPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C2230), Color(0xFF123D35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC857), size: 34),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Share what God has done. Your testimony will be reviewed before it appears on the wall.',
              style: TextStyle(
                  color: Colors.white,
                  height: 1.4,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = _TestimonyPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = _TestimonyPalette.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 90),
        Icon(icon, size: 70, color: const Color(0xFFFFB522)),
        const SizedBox(height: 18),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: colors.text, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted, fontSize: 15, height: 1.45)),
        const SizedBox(height: 18),
        Center(
          child: ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}

class _CardGraphicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFFFC857).withValues(alpha: 0.11);
    canvas.drawCircle(Offset(size.width * 0.94, size.height * 0.05), 86, paint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.18), 54, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TestimonyPalette {
  const _TestimonyPalette({
    required this.isDark,
    required this.background,
    required this.card,
    required this.text,
    required this.body,
    required this.muted,
    required this.border,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color text;
  final Color body;
  final Color muted;
  final Color border;

  static _TestimonyPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _TestimonyPalette(
      isDark: isDark,
      background: isDark ? const Color(0xFF071720) : const Color(0xFFF4F8FA),
      card: isDark ? const Color(0xFF102532) : Colors.white,
      text: isDark ? Colors.white : MyColors.primary,
      body: isDark
          ? Colors.white.withValues(alpha: 0.82)
          : const Color(0xFF243944),
      muted: isDark ? Colors.white60 : const Color(0xFF60707A),
      border: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : const Color(0xFFE8EEF2),
    );
  }
}
