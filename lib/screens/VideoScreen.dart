import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/AppStateManager.dart';
import '../models/Media.dart';
import '../i18n/strings.g.dart';
import '../providers/VideoScreensModel.dart';
import '../screens/NoitemScreen.dart';
import '../models/ScreenArguements.dart';
import '../utils/Utility.dart';
import '../video_player/VideoPlayer.dart';

class VideoScreen extends StatefulWidget {
  static const routeName = "/videoscreen";
  VideoScreen();

  @override
  VideoScreenRouteState createState() => new VideoScreenRouteState();
}

class VideoScreenRouteState extends State<VideoScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => VideoScreensModel(
          Provider.of<AppStateManager>(context, listen: false).userdata),
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.videomessages),
        ),
        body: Padding(
          padding: EdgeInsets.only(top: 12),
          child: VideoScreenBody(),
        ),
      ),
    );
  }
}

class VideoScreenBody extends StatefulWidget {
  @override
  MediaScreenRouteState createState() => new MediaScreenRouteState();
}

class MediaScreenRouteState extends State<VideoScreenBody> {
  late VideoScreensModel mediaScreensModel;
  List<Media>? items;

  void _onRefresh() async {
    mediaScreensModel.loadItems();
  }

  void _onLoading() async {
    mediaScreensModel.loadMoreItems();
  }

  void _openVideo(Media media) {
    Navigator.pushNamed(
      context,
      VideoPlayer.routeName,
      arguments: ScreenArguements(
        position: 0,
        items: media,
        itemsList: Utility.extractMediaByType(items!, media.mediaType),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 0), () {
      Provider.of<VideoScreensModel>(context, listen: false).loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    mediaScreensModel = Provider.of<VideoScreensModel>(context);
    items = mediaScreensModel.mediaList;

    return SmartRefresher(
      enablePullDown: true,
      enablePullUp: true,
      header: WaterDropHeader(),
      footer: CustomFooter(
        builder: (BuildContext context, LoadStatus? mode) {
          Widget body;
          if (mode == LoadStatus.idle) {
            body = Text(t.pulluploadmore);
          } else if (mode == LoadStatus.loading) {
            body = CupertinoActivityIndicator();
          } else if (mode == LoadStatus.failed) {
            body = Text(t.loadfailedretry);
          } else if (mode == LoadStatus.canLoading) {
            body = Text(t.releaseloadmore);
          } else {
            body = Text(t.nomoredata);
          }
          return Container(
            height: 55.0,
            child: Center(child: body),
          );
        },
      ),
      controller: mediaScreensModel.refreshController,
      onRefresh: _onRefresh,
      onLoading: _onLoading,
      child: (mediaScreensModel.isError == true && items!.length == 0)
          ? NoitemScreen(
              title: t.oops, message: t.dataloaderror, onClick: _onRefresh)
          : GridView.builder(
              itemCount: items!.length,
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 0.68,
              ),
              itemBuilder: (BuildContext context, int index) {
                return _InstagramVideoTile(
                  media: items![index],
                  onTap: () => _openVideo(items![index]),
                );
              },
            ),
    );
  }
}

class _InstagramVideoTile extends StatelessWidget {
  const _InstagramVideoTile({
    required this.media,
    required this.onTap,
  });

  final Media media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = media.coverPhoto?.trim() ?? '';
    final views = media.viewsCount ?? 0;
    final title = media.title?.trim() ?? '';
    final category = media.category?.trim() ?? '';

    return InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: const Color(0xFF0C2230).withValues(alpha: 0.12),
            child: imageUrl.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.video_library_rounded,
                      color: Color(0xFF0C2230),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CupertinoActivityIndicator(radius: 10),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFF0C2230),
                      ),
                    ),
                  ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.02),
                  Colors.black.withValues(alpha: 0.14),
                  Colors.black.withValues(alpha: 0.78),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Color(0xFF0C2230),
                size: 19,
              ),
            ),
          ),
          Positioned(
            left: 7,
            right: 7,
            bottom: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.visibility_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      views.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
