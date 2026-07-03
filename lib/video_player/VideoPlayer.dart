import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/MediaPopupMenu.dart';
import '../providers/AppStateManager.dart';
import '../screens/AddPlaylistScreen.dart';
import '../i18n/strings.g.dart';
import '../models/ScreenArguements.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'dart:math' as math;
import '../utils/TextStyles.dart';
import '../models/Downloads.dart';
import '../screens/Downloader.dart';
import '../utils/my_colors.dart';
import '../models/Media.dart';
import '../screens/EmptyListScreen.dart';
import '../widgets/VideoItemTile.dart';
import '../utils/Utility.dart';
import '../models/Userdata.dart';
import '../providers/MediaPlayerModel.dart';
import '../video_player/YoutubePlayer.dart';
import '../widgets/Banneradmob.dart';
import '../widgets/ShortsOverlay.dart';

class VideoPlayer extends StatefulWidget {
  static const routeName = "/videoplayer";
  VideoPlayer({this.media, this.mediaList});
  final Media? media;
  final List<Media?>? mediaList;

  @override
  State<StatefulWidget> createState() {
    return _VideoPlayerState();
  }
}

class _VideoPlayerState extends State<VideoPlayer>
    with TickerProviderStateMixin {
  Userdata? userdata;
  List<Media?> playlist = [];
  bool expand1 = false;
  late AnimationController controller1;
  Animation<double>? animation1, animation1View;
  BetterPlayerController? _betterPlayerController;
  Media? currentMedia;
  Future<BetterPlayerController?>? reloadController;
  bool _isPortraitVideo = false;

  @override
  void initState() {
    print(widget.media!.streamUrl!);
    userdata = Provider.of<AppStateManager>(context, listen: false).userdata;
    controller1 = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    animation1 = Tween(begin: 0.0, end: 180.0).animate(controller1);
    animation1View = CurvedAnimation(parent: controller1, curve: Curves.linear);

    playlist =
        Utility.removeCurrentMediaFromList(widget.mediaList!, widget.media);
    currentMedia = widget.media;
    _isPortraitVideo = _isYoutubeShorts(currentMedia);
    print("streamUrl = " + currentMedia!.streamUrl!);
    if (!_isYoutube(currentMedia)) {
      reloadController = playVideoStream();
    }
    super.initState();
  }

  playVideoItem(Media media) {
    setState(() {
      _isPortraitVideo = _isYoutubeShorts(media);
      playlist = Utility.removeCurrentMediaFromList(widget.mediaList!, media);
      currentMedia = media;
      if (_betterPlayerController != null) {
        _betterPlayerController?.pause();
      }

      if (currentMedia!.videoType == "mp4_video" ||
          currentMedia!.videoType == "video_link" ||
          currentMedia!.videoType == "mpd_video" ||
          currentMedia!.videoType == "m3u8_video") {
        if (!_isYoutube(currentMedia)) {
          reloadController = playVideoStream();
        }
      }
    });
  }

  bool _isYoutubeShorts(Media? media) {
    if (media == null) return false;
    final url = (media.streamUrl ?? '').toLowerCase();
    return url.contains('shorts') || url.contains('/shorts/');
  }

  Future<BetterPlayerController?> playVideoStream() async {
    BetterPlayerDataSource betterPlayerDataSource = BetterPlayerDataSource(
        //videoExtension: "mp4",
        //headers: {"contenttype": "video/mp4"},
        //videoFormat: BetterPlayerVideoFormat.other,
        BetterPlayerDataSourceType.network,
        currentMedia!.streamUrl!);
    _betterPlayerController = new BetterPlayerController(
        BetterPlayerConfiguration(
          aspectRatio: _isPortraitVideo ? 9 / 16 : 16 / 9,
          fit: _isPortraitVideo ? BoxFit.cover : BoxFit.contain,
          autoDetectFullscreenDeviceOrientation: true,
          autoDetectFullscreenAspectRatio: true,

          //controlsConfiguration: BetterPlayerControlsConfiguration(),
          placeholder: CachedNetworkImage(
            imageUrl: currentMedia!.coverPhoto!,
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
          autoPlay: Provider.of<AppStateManager>(context, listen: false)
              .autoPlayVideos,
          allowedScreenSleep: false,

          // showControlsOnInitialize: true,
        ),
        betterPlayerDataSource: betterPlayerDataSource);
    _betterPlayerController!.addEventsListener((event) {
      if (!mounted) return;
      print("Better player event: ${event.betterPlayerEventType}");
      if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
        final size = _betterPlayerController?.videoPlayerController?.value.size;
        if (size != null) {
          final aspect = size.width / size.height;
          print("BetterPlayer Initialized: aspect = $aspect, size = $size");
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

  void togglePanel1() {
    if (!expand1) {
      controller1.forward();
    } else {
      controller1.reverse();
    }
    expand1 = !expand1;
  }

  @override
  void dispose() {
    controller1.stop();
    controller1.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MediaPlayerModel(userdata, widget.media),
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
                title: Text(t.videomessages),
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
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: Colors.black,
                        child: Center(
                          child: buildVideoContainer(currentMedia!),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: ShortsOverlay(
                        media: currentMedia!,
                        onToggleLayout: () {
                          setState(() {
                            _isPortraitVideo = false;
                            if (!_isYoutube(currentMedia)) {
                              reloadController = playVideoStream();
                            }
                          });
                        },
                        isLive: false,
                      ),
                    ),
                  ],
                ),
              )
            : SafeArea(
                child: Column(
                  children: <Widget>[
                    Container(
                      color: Colors.black,
                      width: double.infinity,
                      child: buildVideoContainer(currentMedia!),
                    ),
                    (playlist.length == 0)
                        ? Expanded(
                            child: Column(
                              children: <Widget>[
                                getInfoContainer(),
                                Expanded(
                                  child: EmptyListScreen(
                                    message: t.emptyplaylist,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Expanded(
                            child: ListView.builder(
                              itemCount: playlist.length + 1,
                              scrollDirection: Axis.vertical,
                              padding: EdgeInsets.all(3),
                              itemBuilder: (BuildContext context, int index) {
                                if (index == 0) {
                                  return getInfoContainer();
                                }
                                return VideoItemTile(
                                  onclick: playVideoItem,
                                  object: playlist[index - 1]!,
                                );
                              },
                            ),
                          ),
                    Banneradmob(),
                  ],
                ),
              ),
      ),
    );
  }

  bool _isYoutube(Media? media) {
    if (media == null) return false;
    final type = media.videoType?.toLowerCase().trim() ?? '';
    if (type.contains('youtube')) return true;
    final url = media.streamUrl?.trim() ?? '';
    final urlLower = url.toLowerCase();
    if (urlLower.contains('youtube.com/') || urlLower.contains('youtu.be/'))
      return true;
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(url)) return true;
    return false;
  }

  Widget buildVideoContainer(Media currentMedia) {
    if (_isYoutube(currentMedia)) {
      return YoutubeVideoPlayer(
        media: currentMedia,
        aspectRatio: _isPortraitVideo ? 9 / 16 : 16 / 9,
        key: UniqueKey(),
      );
    }

    if (currentMedia.videoType == "mp4_video" ||
        currentMedia.videoType == "video_link" ||
        currentMedia.videoType == "mpd_video" ||
        currentMedia.videoType == "m3u8_video") {
      return FutureBuilder<BetterPlayerController?>(
        future: reloadController,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          } else {
            return BetterPlayer(controller: snapshot.data!);
          }
        },
      );
    } else {
      return Container(
        child: Text("Not yet Supported"),
      );
    }
  }

  Widget getInfoContainer() {
    return Container(
      padding: EdgeInsets.fromLTRB(15, 15, 15, 0),
      // height: 500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            alignment: Alignment.centerLeft,
            //height: 50,
            child: Stack(
              children: <Widget>[
                InkWell(
                  onTap: () {
                    togglePanel1();
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 5, 30, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(currentMedia!.title!,
                          maxLines: 3,
                          style: TextStyles.headline(context).copyWith(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Transform.rotate(
                    angle: animation1!.value * math.pi / 180,
                    child: IconButton(
                      icon: Icon(Icons.expand_more),
                      onPressed: () {
                        togglePanel1();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 0),
          SizeTransition(
            sizeFactor: animation1View!,
            child: Text(currentMedia!.description!,
                maxLines: 5,
                style: TextStyles.subhead(context).copyWith(
                  fontSize: 17,
                  color: MyColors.grey_90,
                )),
          ),
          Divider(),
          Container(height: 10),
          MediaCommentsLikesContainer(
              key: UniqueKey(), context: context, currentMedia: currentMedia),
          Divider(),
          Container(height: 5),
        ],
      ),
    );
  }
}

class MediaCommentsLikesContainer extends StatefulWidget {
  const MediaCommentsLikesContainer({
    Key? key,
    required this.context,
    required this.currentMedia,
  }) : super(key: key);

  final BuildContext context;
  final Media? currentMedia;

  @override
  _MediaCommentsLikesContainerState createState() =>
      _MediaCommentsLikesContainerState();
}

class _MediaCommentsLikesContainerState
    extends State<MediaCommentsLikesContainer> {
  @override
  void initState() {
    Provider.of<MediaPlayerModel>(context, listen: false)
        .setMediaLikesCommentsCount(widget.currentMedia!);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaPlayerModel>(
      builder: (context, mediaPlayerModel, child) {
        return Container(
          height: 50,
          margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              InkWell(
                onTap: () {
                  mediaPlayerModel
                      .likePost(mediaPlayerModel.isLiked! ? "unlike" : "like");
                },
                child: Row(children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 0, 0, 6),
                    child: FaIcon(FontAwesomeIcons.thumbsUp,
                        size: 28,
                        color: mediaPlayerModel.isLiked!
                            ? Colors.pink
                            : Colors.grey[500]!),
                  ),
                  mediaPlayerModel.likesCount == 0
                      ? Container()
                      : Text(mediaPlayerModel.likesCount.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          )),
                ]),
              ),
              InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AddPlaylistScreen.routeName,
                    arguments: ScreenArguements(
                        position: 0, items: widget.currentMedia),
                  );
                },
                child:
                    Icon(Icons.playlist_add, size: 28, color: Colors.grey[600]),
              ),
              Visibility(
                visible: widget.currentMedia!.videoType != "youtube_video",
                child: InkWell(
                  onTap: () {
                    Downloads downloads =
                        Downloads.mapCurrentDownloadMedia(widget.currentMedia!);
                    Navigator.pushNamed(context, Downloader.routeName,
                        arguments: ScreenArguements(
                          position: 0,
                          items: downloads,
                        ));
                  },
                  child: Icon(Icons.file_download,
                      size: 28, color: Colors.grey[600]),
                ),
              ),
              InkWell(
                  onTap: () {
                    ShareFile.share(widget.currentMedia!);
                  },
                  child: Icon(Icons.share, size: 28, color: Colors.grey[600])),
            ],
          ),
        );
      },
    );
  }
}
