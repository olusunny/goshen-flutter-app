import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../utils/TextStyles.dart';
import '../utils/TimUtil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/Media.dart';
import '../widgets/MediaPopupMenu.dart';
import '../video_player/VideoPlayer.dart';
import '../models/ScreenArguements.dart';
import '../utils/Utility.dart';
import '../providers/AudioPlayerModel.dart';
import '../audio_player/player_page.dart';

class ItemTile extends StatefulWidget {
  final Media object;
  final List<Media> mediaList;
  final int index;

  const ItemTile({
    Key? key,
    required this.mediaList,
    required this.index,
    required this.object,
  }) : super(key: key);

  @override
  _ItemTileState createState() => _ItemTileState();
}

class _ItemTileState extends State<ItemTile> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (widget.object.mediaType!.toLowerCase() == "audio") {
          Provider.of<AudioPlayerModel>(context, listen: false).preparePlaylist(
              Utility.extractMediaByType(
                  widget.mediaList, widget.object.mediaType),
              widget.object);
          Navigator.of(context).pushNamed(PlayPage.routeName);
        } else {
          Navigator.pushNamed(context, VideoPlayer.routeName,
              arguments: ScreenArguements(
                position: 0,
                items: widget.object,
                itemsList: Utility.extractMediaByType(
                    widget.mediaList, widget.object.mediaType),
              ));
        }
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 118),
        padding: const EdgeInsets.fromLTRB(15, 8, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Card(
                    margin: EdgeInsets.all(0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    child: SizedBox(
                      height: 80,
                      width: 80,
                      child: CachedNetworkImage(
                        imageUrl: widget.object.coverPhoto!,
                        imageBuilder: (context, imageProvider) => Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(
                                    Colors.black12, BlendMode.darken)),
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
                    )),
                Container(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(5, 2, 0, 0),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                widget.object.category!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyles.caption(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              TimUtil.timeFormatter(widget.object.duration!),
                              style: TextStyles.caption(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(5, 0, 10, 0),
                        child: Text(
                          widget.object.title!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.subhead(context).copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: widget.object.viewsCount == 0
                                ? const SizedBox.shrink()
                                : Text(
                                    "${widget.object.viewsCount} view(s)",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyles.caption(context),
                                  ),
                          ),
                          MediaPopupMenu(widget.object, compact: true),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            Divider(
              height: 0.1,
              //color: Colors.grey.shade800,
            )
          ],
        ),
      ),
    );
  }
}
