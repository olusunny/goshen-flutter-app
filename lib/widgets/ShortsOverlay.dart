import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/Media.dart';
import '../providers/MediaPlayerModel.dart';
import '../screens/AddPlaylistScreen.dart';
import '../models/ScreenArguements.dart';
import '../models/Downloads.dart';
import '../screens/Downloader.dart';
import '../widgets/MediaPopupMenu.dart'; // For ShareFile

class ShortsOverlay extends StatefulWidget {
  final Media media;
  final VoidCallback onToggleLayout;
  final bool isLive;

  const ShortsOverlay({
    Key? key,
    required this.media,
    required this.onToggleLayout,
    this.isLive = false,
  }) : super(key: key);

  @override
  _ShortsOverlayState createState() => _ShortsOverlayState();
}

class _ShortsOverlayState extends State<ShortsOverlay> {
  bool _isDescExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaPlayerModel>(
      builder: (context, mediaPlayerModel, child) {
        // Fallback checks just in case
        final isLiked = mediaPlayerModel.isLiked ?? false;
        final likesCount = mediaPlayerModel.likesCount ?? 0;

        return Stack(
          children: [
            // Top Dark Gradient (AppBar Area)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Dark Gradient (Content Area)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 280,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Left Content: Title, Description, and Badges
            Positioned(
              bottom: 24,
              left: 16,
              right: 80, // Leave space for right vertical buttons
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badges Row
                  Row(
                    children: [
                      if (widget.isLive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "LIVE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.media.category ?? "Shorts",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility,
                                color: Colors.white70, size: 12),
                            SizedBox(width: 4),
                            Text(
                              "Shorts Mode",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Title Text
                  Text(
                    widget.media.title ?? "",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.80),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Collapsible/Expandable Description
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDescExpanded = !_isDescExpanded;
                      });
                    },
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Text(
                        widget.media.description ?? "",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.85),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: _isDescExpanded ? 10 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if ((widget.media.description ?? "").length > 60)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isDescExpanded = !_isDescExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _isDescExpanded ? "Show Less" : "...more",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Right Side Floating Vertical Action Buttons
            Positioned(
              bottom: 24,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Like / Thumbs Up Button
                  _buildVerticalButton(
                    icon: FaIcon(
                      FontAwesomeIcons.thumbsUp,
                      color: isLiked ? Colors.pinkAccent : Colors.white,
                      size: 24,
                    ),
                    label: likesCount == 0 ? "Like" : likesCount.toString(),
                    onTap: () {
                      mediaPlayerModel.likePost(isLiked ? "unlike" : "like");
                    },
                  ),

                  // Add to Playlist Button
                  _buildVerticalButton(
                    icon: const Icon(
                      Icons.playlist_add,
                      color: Colors.white,
                      size: 28,
                    ),
                    label: "Playlist",
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AddPlaylistScreen.routeName,
                        arguments:
                            ScreenArguements(position: 0, items: widget.media),
                      );
                    },
                  ),

                  // Download Button (only if supported and not YouTube)
                  if (_canDownload(widget.media))
                    _buildVerticalButton(
                      icon: const Icon(
                        Icons.file_download,
                        color: Colors.white,
                        size: 26,
                      ),
                      label: "Download",
                      onTap: () {
                        Downloads downloads =
                            Downloads.mapCurrentDownloadMedia(widget.media);
                        Navigator.pushNamed(
                          context,
                          Downloader.routeName,
                          arguments: ScreenArguements(
                            position: 0,
                            items: downloads,
                          ),
                        );
                      },
                    ),

                  // Share Button
                  _buildVerticalButton(
                    icon: const Icon(
                      Icons.share,
                      color: Colors.white,
                      size: 24,
                    ),
                    label: "Share",
                    onTap: () {
                      ShareFile.share(widget.media);
                    },
                  ),

                  // Toggle Aspect Ratio Button
                  _buildVerticalButton(
                    icon: const Icon(
                      Icons.screen_rotation,
                      color: Colors.white,
                      size: 24,
                    ),
                    label: "Landscape",
                    onTap: widget.onToggleLayout,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVerticalButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(child: icon),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                blurRadius: 4.0,
                color: Colors.black87,
                offset: Offset(1.0, 1.0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  bool _canDownload(Media media) {
    if (media.canDownload != true) return false;
    final url = (media.downloadUrl ?? media.streamUrl ?? '').trim();
    if (url.isEmpty) return false;

    final type = media.videoType?.toLowerCase().trim() ?? '';
    final urlLower = url.toLowerCase();
    if (type.contains('youtube') ||
        urlLower.contains('youtube.com/') ||
        urlLower.contains('youtu.be/') ||
        RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(url)) {
      return false;
    }

    return ![
      'youtube_video',
      'vimeo_video',
      'dailymotion_video',
    ].contains(media.videoType);
  }
}
