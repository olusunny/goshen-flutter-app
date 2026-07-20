import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/SplashMedia.dart';
import '../service/SplashMediaService.dart';
import '../utils/my_colors.dart';

class ManagedSplashScreen extends StatefulWidget {
  ManagedSplashScreen({
    Key? key,
    required this.next,
    SplashMediaService? service,
  })  : service = service ?? SplashMediaService(),
        super(key: key);

  final Widget next;
  final SplashMediaService service;

  @override
  State<ManagedSplashScreen> createState() => _ManagedSplashScreenState();
}

class _ManagedSplashScreenState extends State<ManagedSplashScreen> {
  CachedSplashMedia? _cached;
  VideoPlayerController? _video;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _prepareSplash();
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _prepareSplash() async {
    final cached = await widget.service.loadCached();
    if (!mounted) return;

    if (cached != null) {
      setState(() {
        _cached = cached;
      });
      await _prepareVideoIfNeeded(cached);
    } else {
      await _prepareBundledVideo();
    }

    if (!mounted) return;
    unawaited(widget.service.refreshInBackground(current: cached));
    _scheduleFinish(_durationFor(cached?.config));
  }

  Future<void> _prepareVideoIfNeeded(CachedSplashMedia cached) async {
    if (cached.config.mediaType != SplashMediaType.video) return;

    try {
      final controller = VideoPlayerController.file(File(cached.localPath));
      await controller.initialize().timeout(const Duration(milliseconds: 1200));
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _video = controller);
    } catch (_) {
      await _prepareBundledVideo();
    }
  }

  Future<void> _prepareBundledVideo() async {
    try {
      final controller = VideoPlayerController.asset(
        SplashMediaService.bundledFallbackAsset,
      );
      await controller.initialize().timeout(const Duration(milliseconds: 1200));
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _video = controller);
    } catch (_) {}
  }

  void _scheduleFinish(Duration duration) {
    Timer(duration, () {
      if (!mounted || _done) return;
      setState(() => _done = true);
    });
  }

  Duration _durationFor(SplashMediaConfig? config) {
    final milliseconds = config?.durationMs;
    if (milliseconds != null && milliseconds >= 800 && milliseconds <= 10000) {
      return Duration(milliseconds: milliseconds);
    }
    return const Duration(
        milliseconds: SplashMediaService.bundledFallbackDurationMs);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      child: _done
          ? widget.next
          : Scaffold(
              key: const ValueKey('managed-splash'),
              backgroundColor: MyColors.primaryDark,
              body: SizedBox.expand(child: _buildMedia()),
            ),
    );
  }

  Widget _buildMedia() {
    final cached = _cached;
    if (cached != null && cached.config.mediaType == SplashMediaType.image) {
      return Image.file(
        File(cached.localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _brandFallback(),
      );
    }

    final video = _video;
    if (video != null && video.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: video.value.size.width,
          height: video.value.size.height,
          child: VideoPlayer(video),
        ),
      );
    }

    return _brandFallback();
  }

  Widget _brandFallback() {
    return Container(
      color: MyColors.primaryDark,
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/app_logo.png',
        width: 108,
        fit: BoxFit.contain,
      ),
    );
  }
}
