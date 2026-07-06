import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../features/fundraising/fundraising_api.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';
import '../models/Userdata.dart';
import '../models/Media.dart';
import '../models/Radios.dart';
import '../models/LiveStreams.dart';
import '../utils/inbox_read_store.dart';
import '../service/MoreMenuPreloadService.dart';

class HomeProvider with ChangeNotifier {
  final Map<String, dynamic> data = {
    "sliders": [],
    "update_banners": [],
    "website": "",
    "livestream": {},
    "radios": {},
    "image1": "",
    "image2": "",
    "image3": "",
    "image4": "",
    "image5": "",
    "image6": "",
    "facebook_page": "",
    "youtube_page": "",
    "tiktok_page": "",
    "instagram_page": "",
    "telegram_page": "",
    "mixlr_page": "",
    "whatsapp_page": "",
    "twitter_page": "",
    "verse_of_day": null,
    "prayer_requests_count": 0,
    "prayer_request_avatars": [],
    "testimonies_enabled": false,
    "testimonies_count": 0,
    "goshen_retreat_enabled": false,
    "fundraising_enabled": false,
    "prayer_points_enabled": true,
    "interactive_prayer_wall_enabled": true,
    "hymns_enabled": true,
    "devotionals_enabled": true,
    "verse_of_day_enabled": true,
    "transportation_arrangements_enabled": true,
    "church_groups_enabled": true,
    "dynamic_forms_enabled": true,
    "goshen_quiz_enabled": true,
    "goshen_wallet_withdrawals_enabled": true,
    "goshen_wallet_auto_topup_enabled": true,
    "branches_enabled": true,
    "mobile_phone_otp_login_enabled": false,
    "inbox": 0,
    "inbox_latest_ids": [],
  };

  //List<Comments> _items = [];
  bool isError = false;
  Userdata? userdata;
  bool isLoading = true;
  Future<void>? _fetchFuture;

  void loadItems({Userdata? user}) {
    print("Initializing home fragment");
    fetchItems(user: user);
  }

  Future<void> fetchItems({
    Userdata? user,
    bool force = false,
  }) {
    if (user != null) {
      userdata = user;
    }
    if (!force && _fetchFuture != null) {
      return _fetchFuture!;
    }

    _fetchFuture = _fetchItems().whenComplete(() {
      _fetchFuture = null;
    });
    return _fetchFuture!;
  }

  Future<void> _fetchItems() async {
    try {
      final dio = Dio();
      // Adding an interceptor to enable caching.

      final response = await dio.post(
        ApiUrl.DISCOVER,
        data: jsonEncode({
          "data": {
            "email": userdata == null ? "null" : userdata!.email,
            "version": "v2"
          }
        }),
      );

      if (response.statusCode == 200) {
        // If the server did return a 200 OK response,
        // then parse the JSON.
        isLoading = false;
        isError = false;

        dynamic res = decodeApiResponse(response.data);
        print(res);
        data['sliders'] = parseSliderMedia(res, "slider_media");
        data['update_banners'] = parseSliderMedia(res, "update_banners");
        data['website'] = res['website_url'] ?? "";
        data['livestream'] = parseLiveStreams(res);
        data['radios'] = parseRadio(res);
        data['image1'] = res['image_one'];
        data['image2'] = res['image_one'];
        data['image3'] = res['image_three'];
        data['image4'] = res['image_four'];
        data['image5'] = res['image_five'];
        data['image6'] = res['image_six'];
        data['facebook_page'] = res['facebook_page'] ?? "";
        data['youtube_page'] = res['youtube_page'] ?? "";
        data['tiktok_page'] = res['tiktok_page'] ?? "";
        data['instagram_page'] = res['instagram_page'] ?? "";
        data['telegram_page'] = res['telegram_page'] ?? "";
        data['mixlr_page'] = res['mixlr_page'] ?? "";
        data['whatsapp_page'] = res['whatsapp_page'] ?? "";
        data['twitter_page'] = res['twitter_page'] ?? "";
        data['mobile_phone_otp_login_enabled'] =
            _readBool(res['mobile_phone_otp_login_enabled']);
        data['prayer_points_enabled'] =
            _readBool(res['prayer_points_enabled'], fallback: true);
        data['interactive_prayer_wall_enabled'] =
            _readBool(res['interactive_prayer_wall_enabled'], fallback: true);
        data['hymns_enabled'] = _readBool(res['hymns_enabled'], fallback: true);
        data['devotionals_enabled'] =
            _readBool(res['devotionals_enabled'], fallback: true);
        data['verse_of_day_enabled'] =
            _readBool(res['verse_of_day_enabled'], fallback: true);
        data['transportation_arrangements_enabled'] = _readBool(
            res['transportation_arrangements_enabled'],
            fallback: true);
        data['church_groups_enabled'] =
            _readBool(res['church_groups_enabled'], fallback: true);
        data['dynamic_forms_enabled'] =
            _readBool(res['dynamic_forms_enabled'], fallback: true);
        data['goshen_quiz_enabled'] =
            _readBool(res['goshen_quiz_enabled'], fallback: true);
        data['goshen_wallet_withdrawals_enabled'] =
            _readBool(res['goshen_wallet_withdrawals_enabled'], fallback: true);
        data['goshen_wallet_auto_topup_enabled'] =
            _readBool(res['goshen_wallet_auto_topup_enabled'], fallback: true);
        data['branches_enabled'] =
            _readBool(res['branches_enabled'], fallback: true);
        data['verse_of_day'] =
            data['verse_of_day_enabled'] == true ? res['verse_of_day'] : null;
        data['prayer_requests_count'] = res['prayer_requests_count'] ?? 0;
        data['prayer_request_avatars'] = res['prayer_request_avatars'] ?? [];
        data['testimonies_enabled'] = res['testimonies_enabled'] == true;
        data['testimonies_count'] = res['testimonies_count'] ?? 0;
        data['goshen_retreat_enabled'] = await _fetchGoshenRetreatFlag(dio);
        data['fundraising_enabled'] =
            _readBool(res['fundraising_enabled'], fallback: true) &&
                await FundraisingApi(dio: dio).hasActiveCampaign();
        data['inbox_latest_ids'] = (res['inbox_latest_ids'] as List?) ?? [];
        data['inbox'] =
            await InboxReadStore.unreadCount(data['inbox_latest_ids'] as List);
        MoreMenuPreloadService.instance.warmQuietly(
          user: userdata,
          homeData: data,
        );
        print(data);
        notifyListeners();
      } else {
        // If the server did not return a 200 OK response,
        // then throw an exception.
        setFetchError();
      }
    } catch (exception) {
      // I get no exception here
      print(exception);
      setFetchError();
    }
  }

  Future<bool> _fetchGoshenRetreatFlag(Dio dio) async {
    try {
      final response = await dio.get(ApiUrl.GOSHEN_RETREAT_STATUS);
      if (response.statusCode != 200) return false;

      final decoded = decodeApiResponse(response.data);
      if (decoded is Map) {
        final value = decoded['enabled'];
        return value == true || '$value' == '1';
      }
    } catch (_) {}

    return false;
  }

  static Radios parseRadio(dynamic res) {
    return Radios.fromJson(res["radios"] ?? {});
  }

  static LiveStreams parseLiveStreams(dynamic res) {
    return LiveStreams.fromJson(res["livestream"] ?? {});
  }

  static List<Media> parseSliderMedia(dynamic res, String key) {
    final raw = res[key];
    if (raw == null) return [];
    final parsed = raw.cast<Map<String, dynamic>>();
    return parsed.map<Media>((json) => Media.fromJson(json)).toList();
  }

  setFetchError() {
    isError = true;
    isLoading = false;
    notifyListeners();
  }

  static bool _readBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final text = value.toString().toLowerCase().trim();
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }
}
