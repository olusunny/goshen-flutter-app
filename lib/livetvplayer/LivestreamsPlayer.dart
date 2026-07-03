import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../models/LiveStreams.dart';
import '../models/Media.dart';
import '../providers/AppStateManager.dart';
import '../providers/MediaPlayerModel.dart';
import '../widgets/ShortsOverlay.dart';
import 'LiveYoutubePlayer.dart';

class LivestreamsPlayer extends StatefulWidget {
  static String routeName = "/livestreamsplayer";
  final LiveStreams? liveStreams;

  LivestreamsPlayer({Key? key, this.liveStreams}) : super(key: key);

  @override
  _VideoViewerScreenState createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<LivestreamsPlayer> {
  BetterPlayerController? _betterPlayerController;
  LiveStreams? currentMedia;
  Future<BetterPlayerController?>? reloadController;
  WebViewController? _webViewController;
  bool _isPortraitVideo = false;

  @override
  void initState() {
    currentMedia = widget.liveStreams;
    _isPortraitVideo = _isYoutubeShorts(currentMedia);

    if (_isHlsOrRtmp(currentMedia)) {
      reloadController = playVideoStream();
    } else if (_shouldUseWebView(currentMedia)) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(currentMedia!.streamUrl!));
    }
    super.initState();
  }

  bool _isYoutubeShorts(LiveStreams? stream) {
    if (stream == null) return false;
    final url = (stream.streamUrl ?? '').toLowerCase();
    return url.contains('shorts') || url.contains('/shorts/');
  }

  Future<BetterPlayerController?> playVideoStream() async {
    final isHls = _playbackType(currentMedia) == 'm3u8';
    BetterPlayerDataSource betterPlayerDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      currentMedia!.streamUrl!,
      liveStream: true,
      videoFormat: isHls ? BetterPlayerVideoFormat.hls : null,
    );
    _betterPlayerController = new BetterPlayerController(
        BetterPlayerConfiguration(
          aspectRatio: _isPortraitVideo ? 9 / 16 : 3 / 2,
          fit: _isPortraitVideo ? BoxFit.cover : BoxFit.contain,
          placeholder: CachedNetworkImage(
            imageUrl:
                "https://www.technocrazed.com/wp-content/uploads/2015/12/Landscape-wallpaper-36.jpg",
            imageBuilder: (context, imageProvider) => Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            placeholder: (context, url) =>
                Center(child: CupertinoActivityIndicator()),
            errorWidget: (context, url, error) => Center(
                child: Icon(
              Icons.error,
              color: Colors.grey,
            )),
          ),
          autoPlay: true,
          allowedScreenSleep: false,
        ),
        betterPlayerDataSource: betterPlayerDataSource);

    _betterPlayerController!.addEventsListener((event) {
      if (!mounted) return;
      if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
        final size = _betterPlayerController?.videoPlayerController?.value.size;
        if (size != null) {
          final aspect = size.width / size.height;
          print(
              "Live BetterPlayer Initialized: aspect = $aspect, size = $size");
          if (aspect < 1.0 && !_isPortraitVideo) {
            setState(() {
              _isPortraitVideo = true;
              reloadController = playVideoStream();
            });
          }
        }
      }
    });

    return _betterPlayerController;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildWidgetAlbumCoverBlur() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.rectangle,
        image: DecorationImage(
          image: NetworkImage(
              "https://www.technocrazed.com/wp-content/uploads/2015/12/Landscape-wallpaper-36.jpg"),
          fit: BoxFit.cover,
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10.0,
          sigmaY: 10.0,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.0),
          ),
        ),
      ),
    );
  }

  bool _isYoutube(LiveStreams? stream) {
    final type = _playbackType(stream);
    return type == 'youtube';
  }

  @override
  Widget build(BuildContext context) {
    final userdata =
        Provider.of<AppStateManager>(context, listen: false).userdata;
    final Media? currentMediaObj =
        currentMedia != null ? Media.fromLiveStream(currentMedia!) : null;

    return ChangeNotifierProvider(
      create: (context) => MediaPlayerModel(userdata, currentMediaObj),
      child: Scaffold(
        extendBodyBehindAppBar: _isPortraitVideo,
        appBar: _isPortraitVideo
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.screen_rotation,
                          color: Colors.white, size: 20),
                      onPressed: () {
                        setState(() {
                          _isPortraitVideo = false;
                          if (!_isYoutube(currentMedia)) {
                            reloadController = playVideoStream();
                          }
                        });
                      },
                    ),
                  ),
                ],
              )
            : AppBar(
                title: Text(widget.liveStreams?.title ?? 'Livestream'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.screen_rotation),
                    onPressed: () {
                      setState(() {
                        _isPortraitVideo = true;
                        if (!_isYoutube(currentMedia)) {
                          reloadController = playVideoStream();
                        }
                      });
                    },
                  ),
                ],
              ),
        body: _isPortraitVideo
            ? SafeArea(
                top: false,
                bottom: false,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: Container(
                        color: Colors.black,
                        child: Center(
                          child: buildVideoContainer(currentMedia),
                        ),
                      ),
                    ),
                    if (currentMediaObj != null)
                      Positioned.fill(
                        child: ShortsOverlay(
                          media: currentMediaObj,
                          onToggleLayout: () {
                            setState(() {
                              _isPortraitVideo = false;
                              if (!_isYoutube(currentMedia)) {
                                reloadController = playVideoStream();
                              }
                            });
                          },
                          isLive: true,
                        ),
                      ),
                  ],
                ),
              )
            : Stack(
                children: <Widget>[
                  _buildWidgetAlbumCoverBlur(),
                  Container(
                    height: double.infinity,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.5)
                      ],
                    )),
                  ),
                  Column(
                    children: <Widget>[
                      Expanded(child: buildVideoContainer(currentMedia)),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget buildVideoContainer(LiveStreams? currentMedia) {
    if (currentMedia == null || (currentMedia.streamUrl ?? '').isEmpty) {
      return const Center(child: Text('Livestream has not been configured.'));
    }

    final type = _playbackType(currentMedia);
    if (type == "m3u8" || type == "rtmp") {
      return FutureBuilder<BetterPlayerController?>(
        future: reloadController,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          } else {
            return _isPortraitVideo
                ? BetterPlayer(controller: snapshot.data!)
                : AspectRatio(
                    aspectRatio: 16 / 9,
                    child: BetterPlayer(
                      controller: snapshot.data!,
                    ),
                  );
          }
        },
      );
    } else if (type == "youtube") {
      return LiveYoutubePlayer(
        media: currentMedia,
        aspectRatio: _isPortraitVideo ? 9 / 16 : 16 / 9,
        key: UniqueKey(),
      );
    } else if (_webViewController != null) {
      return SafeArea(child: WebViewWidget(controller: _webViewController!));
    } else {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This livestream URL cannot be played in-app yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  String _playbackType(LiveStreams? stream) {
    final configured = stream?.type?.toLowerCase().trim() ?? '';
    final url = stream?.streamUrl?.trim() ?? '';
    final urlLower = url.toLowerCase();

    if (configured.contains('youtube') ||
        urlLower.contains('youtube.com/') ||
        urlLower.contains('youtu.be/') ||
        RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(url)) {
      return 'youtube';
    }
    if (configured == 'm3u8' || urlLower.contains('.m3u8')) return 'm3u8';
    if (configured == 'rtmp' || urlLower.startsWith('rtmp://')) return 'rtmp';
    return configured;
  }

  bool _isHlsOrRtmp(LiveStreams? stream) {
    final type = _playbackType(stream);
    return type == 'm3u8' || type == 'rtmp';
  }

  bool _shouldUseWebView(LiveStreams? stream) {
    final url = stream?.streamUrl?.toLowerCase().trim() ?? '';
    return url.startsWith('http://') || url.startsWith('https://');
  }
}
