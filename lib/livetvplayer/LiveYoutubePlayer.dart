import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/LiveStreams.dart';

class LiveYoutubePlayer extends StatefulWidget {
  final LiveStreams media;
  final double? aspectRatio;
  LiveYoutubePlayer({Key? key, required this.media, this.aspectRatio})
      : super(key: key);

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<LiveYoutubePlayer>
    with WidgetsBindingObserver {
  YoutubePlayerController? _controller;
  String? _videoId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _videoId = _extractYoutubeId(widget.media.streamUrl);
    if (_videoId != null && _videoId!.trim().isNotEmpty) {
      _controller = YoutubePlayerController(
        initialVideoId: _videoId!,
        flags: YoutubePlayerFlags(
          mute: false,
          autoPlay: true,
          disableDragSeek: false,
          loop: false,
          isLive: _isLiveUrl(widget.media.streamUrl),
          forceHD: false,
          enableCaption: true,
        ),
      );
    }
  }

  @override
  void deactivate() {
    // Pauses video while navigating to next page.
    _controller?.pause();
    super.deactivate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(
        child: Text(
          'This livestream link is not a direct YouTube video.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return YoutubePlayer(
      controller: _controller!,
      aspectRatio: widget.aspectRatio ?? 16 / 9,
      showVideoProgressIndicator: true,
      bottomActions: <Widget>[
        const SizedBox(width: 14.0),
        CurrentPosition(),
        const SizedBox(width: 8.0),
        ProgressBar(isExpanded: true),
        RemainingDuration(),
        const PlaybackSpeedButton(),
      ],
    );
  }

  String? _extractYoutubeId(String? value) {
    final source = value?.trim() ?? '';
    if (source.isEmpty) return null;

    // 1. If it's a raw 11-character YouTube ID
    final rawIdRegExp = RegExp(r'^[A-Za-z0-9_-]{11}$');
    if (rawIdRegExp.hasMatch(source)) {
      return source;
    }

    // 2. Try matching various YouTube URL patterns
    final urlRegExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?|shorts|live)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/ ]{11})',
      caseSensitive: false,
    );

    final match = urlRegExp.firstMatch(source);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    // Fallback: search for any 11-char pattern that looks like a YouTube ID
    final fallbackRegExp =
        RegExp(r'[^A-Za-z0-9_-]([A-Za-z0-9_-]{11})(?:[^A-Za-z0-9_-]|$)');
    final fallbackMatch = fallbackRegExp.firstMatch(source);
    if (fallbackMatch != null) {
      return fallbackMatch.group(1);
    }

    return null;
  }

  bool _isLiveUrl(String? value) {
    final source = value?.toLowerCase() ?? '';
    return source.contains('/live') || source.contains('@');
  }
}
