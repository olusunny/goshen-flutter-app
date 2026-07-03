import '../utils/ApiUrl.dart';
import 'LiveStreams.dart';

class Media {
  final int? id;
  int? commentsCount, likesCount, previewDuration, duration, viewsCount;
  final String? category, title, coverPhoto, mediaType, videoType;
  final String? description, downloadUrl, streamUrl;
  final String? dateInserted;
  final bool? canPreview, canDownload, isFree, http;
  bool? userLiked;

  Media(
      {this.id,
      this.category,
      this.title,
      this.coverPhoto,
      this.mediaType,
      this.videoType,
      this.description,
      this.downloadUrl,
      this.canPreview,
      this.canDownload,
      this.isFree,
      this.userLiked,
      this.http,
      this.duration,
      this.commentsCount,
      this.likesCount,
      this.previewDuration,
      this.streamUrl,
      this.viewsCount,
      this.dateInserted});

  static const String BOOKMARKS_TABLE = "bookmarks";
  static const String PLAYLISTS_TABLE = "media_playlists";
  static final bookmarkscolumns = [
    "id",
    "category",
    "title",
    "coverPhoto",
    "mediaType",
    "videoType",
    "description",
    "downloadUrl",
    "canPreview",
    "canDownload",
    "isFree",
    "userLiked",
    "http",
    "duration",
    "commentsCount",
    "likesCount",
    "previewDuration",
    "streamUrl",
    "viewsCount"
  ];
  static final playlistscolumns = [
    "id",
    "playlistId",
    "category",
    "title",
    "coverPhoto",
    "mediaType",
    "videoType",
    "description",
    "downloadUrl",
    "canPreview",
    "canDownload",
    "isFree",
    "userLiked",
    "http",
    "duration",
    "commentsCount",
    "likesCount",
    "previewDuration",
    "streamUrl",
    "viewsCount"
  ];

  factory Media.fromJson(Map<String, dynamic> json) {
    //print(json);
    int id = int.parse(json['id'].toString());
    return Media(
        id: id,
        category: json['category'] as String?,
        title: json['title'] as String?,
        coverPhoto: _resolveUrl(json['cover_photo'] as String?),
        mediaType: json['type'] as String?,
        videoType: json['video_type'] as String?,
        description: json['description'] as String?,
        downloadUrl: _resolveUrl(json['download_url'] as String?),
        canPreview: int.parse(json['can_preview'].toString()) == 0,
        canDownload: int.parse(json['can_download'].toString()) == 0,
        isFree: int.parse(json['is_free'].toString()) == 0,
        userLiked:
            bool.fromEnvironment(json['user_liked'].toString().toLowerCase()),
        http: true,
        duration: int.parse(json['duration'].toString()),
        commentsCount: int.parse(json['comments_count'].toString()),
        likesCount: int.parse(json['likes_count'].toString()),
        previewDuration: int.parse(json['preview_duration'].toString()),
        streamUrl: _resolveMediaSource(
          json['stream'] as String?,
          json['video_type'] as String?,
        ),
        viewsCount: int.parse(json['views_count'].toString()),
        dateInserted: json['dateInserted'] as String?);
  }

  static String? _resolveUrl(String? value) {
    if (value == null || value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return '${ApiUrl.BASEURL.substring(0, ApiUrl.BASEURL.length - 1)}$value';
    }
    return '${ApiUrl.BASEURL}$value';
  }

  static String? _resolveMediaSource(String? value, String? videoType) {
    if (value == null || value.isEmpty) return value;
    if (_isYoutube(value, videoType)) {
      return value;
    }
    if (videoType == 'youtube_video' ||
        videoType == 'vimeo_video' ||
        videoType == 'dailymotion_video') {
      return value;
    }
    return _resolveUrl(value);
  }

  static bool _isYoutube(String? value, String? videoType) {
    final type = videoType?.toLowerCase().trim() ?? '';
    if (type.contains('youtube')) return true;
    final url = value?.trim() ?? '';
    final urlLower = url.toLowerCase();
    if (urlLower.contains('youtube.com/') || urlLower.contains('youtu.be/'))
      return true;
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(url)) return true;
    return false;
  }

  factory Media.fromMap(Map<String, dynamic> data) {
    return Media(
        id: data['id'],
        category: data['category'],
        title: data['title'],
        coverPhoto: data['coverPhoto'],
        mediaType: data['mediaType'],
        videoType: data['videoType'],
        description: data['description'],
        downloadUrl: data['downloadUrl'],
        canPreview: int.parse(data['canPreview'].toString()) == 0,
        canDownload: int.parse(data['canDownload'].toString()) == 0,
        isFree: int.parse(data['isFree'].toString()) == 0,
        userLiked: int.parse(data['userLiked'].toString()) == 0,
        http: int.parse(data['http'].toString()) == 0,
        duration: data['duration'],
        commentsCount: data['commentsCount'],
        likesCount: data['likesCount'],
        previewDuration: data['previewDuration'],
        streamUrl: data['streamUrl'],
        viewsCount: data['viewsCount']);
  }

  Map<String, dynamic> toMap() => {
        "id": id,
        "category": category,
        "title": title,
        "coverPhoto": coverPhoto,
        "mediaType": mediaType,
        "videoType": videoType,
        "description": description,
        "downloadUrl": downloadUrl,
        "canPreview": canPreview,
        "canDownload": canDownload,
        "isFree": isFree,
        "userLiked": userLiked,
        "http": http,
        "duration": duration,
        "commentsCount": commentsCount,
        "likesCount": likesCount,
        "previewDuration": previewDuration,
        "streamUrl": streamUrl,
        "viewsCount": viewsCount
      };

  factory Media.fromLiveStream(LiveStreams stream) {
    return Media(
      id: stream.id,
      title: stream.title ?? '',
      description: stream.description ?? '',
      streamUrl: stream.streamUrl ?? '',
      videoType: (stream.type?.toString().toLowerCase().contains('youtube') ??
                  false) ||
              (stream.streamUrl?.toLowerCase().contains('youtube.com/') ??
                  false) ||
              (stream.streamUrl?.toLowerCase().contains('youtu.be/') ?? false)
          ? 'youtube_video'
          : 'm3u8_video',
      mediaType: 'video',
      coverPhoto:
          'https://images.unsplash.com/photo-1518495973542-4542c06a5843',
      canDownload: false,
      canPreview: false,
      isFree: true,
      http: true,
      userLiked: false,
      likesCount: 0,
      commentsCount: 0,
      duration: 0,
      viewsCount: 0,
      category: 'Livestream',
    );
  }
}
