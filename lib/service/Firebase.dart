import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:churchapp_flutter/models/Events.dart';

import '../models/Inbox.dart';
import '../models/LiveStreams.dart';
import '../utils/ApiUrl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/Media.dart';
import '../utils/my_colors.dart';
import '../providers/events.dart';
import '../models/UserEvents.dart';

var flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
  await Firebase.myBackgroundMessageHandler(message.data);
}

/// when app is in the foreground
Future<void> onTapNotification(NotificationResponse? response) async {}

class Firebase {
  late Function navigateMedia;
  late Function navigateInbox;
  late Function navigateLivestreams;
  late Function navigateEvents;
  static String appState = "idle";

  Firebase(
    Function navigateMedia,
    Function navigateInbox,
    Function navigateLivestreams,
    Function navigateEvents,
  ) {
    this.navigateMedia = navigateMedia;
    this.navigateLivestreams = navigateLivestreams;
    this.navigateInbox = navigateInbox;
    this.navigateEvents = navigateEvents;
  }

  //updated myBackgroundMessageHandler
  static Future<dynamic> myBackgroundMessageHandler(
      Map<String, dynamic> message) async {
    await handleNotificationMessages(message);
    return Future<void>.value();
  }

  void init() async {
    final InitializationSettings _initSettings = InitializationSettings(
        android: AndroidInitializationSettings("@mipmap/launcher_icon"),
        iOS: DarwinInitializationSettings());

    /// on did receive notification response = for when app is opened via notification while in foreground on android
    await flutterLocalNotificationsPlugin.initialize(_initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse? response) {
      print("NotificationResponse = " + response!.payload.toString());
      if (response.payload == null) return;
      onSelect(response.payload);
    });

    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()!
        .requestNotificationsPermission();

    FirebaseMessaging.onMessage.listen((message) async {
      print("onMessage: $message");
      await handleNotificationMessages(message.data);
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        print("Push Messaging token: $token");
        sendFirebaseTokenToServer(token);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString("firebase_token", token);
      }
    } catch (error) {
      // Firebase may be intentionally unconfigured in some deployments.
      // Push notifications should fail quietly instead of blocking app startup.
      print("Firebase token unavailable: $error");
    }

    /*final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

    _firebaseMessaging.configure(
      onBackgroundMessage: Platform.isIOS ? null : myBackgroundMessageHandler,
      onMessage: (message) async {
        print("onMessage: $message");
        handleNotificationMessages(message);
      },
      onLaunch: (message) async {
        print("onLaunch: $message");
      },
      onResume: (message) async {
        print("onResume: $message");
      },
    );

    _firebaseMessaging.getToken().then((String token) async {
      print("Push Messaging token: $token");
      sendFirebaseTokenToServer(token);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString("firebase_token", token);
    });*/
    initEvents();
  }

  static initEvents() async {
    eventBus.on<OnAppStateChanged>().listen((event) {
      appState = event.state;
      print("OnAppStateChanged event called = " + appState);
    });
  }

  static Future<void> handleNotificationMessages(
      Map<String, dynamic> message) async {
    print("myBackgroundMessageHandler message1: $message");
    var data = message;
    //['data'];
    /*if (data == null) {
      data = message;
    }*/
    print("myBackgroundMessageHandler message: $data");
    var action = data["action"];
    String? title = "";
    String? msg = "";
    if (action == "newMedia") {
      Map<String, dynamic> arts = json.decode(data['media']);
      Media articles = Media.fromJson(arts);
      title = articles.description;
      msg = articles.title;
    }

    if (action == "inbox") {
      Map<String, dynamic> arts = json.decode(data['inbox']);
      Inbox inbox = Inbox.fromJson(arts);
      title = inbox.title;
      msg = _stripHtml(inbox.message ?? data['message'] ?? '');
      eventBus.fire(const InboxNotificationsChanged());
    }

    if (action == "events") {
      Map<String, dynamic> arts = json.decode(data['events']);
      Events inbox = Events.fromJson(arts);
      title = inbox.title;
      msg = "New Events";
    }

    if (action == "livestream") {
      Map<String, dynamic> livestream = json.decode(data['livestream']);
      LiveStreams liveStreams = LiveStreams.fromJson(livestream);
      title = liveStreams.description;
      msg = liveStreams.title;
    }

    if (title != "" && msg != "") {
      BigTextStyleInformation bigTextStyleInformation =
          BigTextStyleInformation(msg!, contentTitle: title);
      final androidPlatformChannelSpecifics = await _androidNotificationDetails(
          data, bigTextStyleInformation, title);
      var platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: DarwinNotificationDetails(
              presentSound: true, presentAlert: true, presentBadge: true));

      flutterLocalNotificationsPlugin.show(
          102, title, msg, platformChannelSpecifics,
          payload: json.encode(message));
    }
  }

  static Future<AndroidNotificationDetails> _androidNotificationDetails(
    Map<String, dynamic> data,
    StyleInformation styleInformation,
    String? ticker,
  ) async {
    final toneUrl = '${data['tone_url'] ?? ''}'.trim();
    final toneEnabled = _readBool(data['tone_enabled']) && toneUrl.isNotEmpty;
    AndroidNotificationSound? sound;
    String channelId = 'churchapp';
    String channelName = 'churchapp';

    if (toneEnabled) {
      final uri = await _cachedToneUri(toneUrl);
      if (uri != null) {
        channelId = 'churchapp_tone_${toneUrl.hashCode.abs()}';
        channelName = '${data['tone_label'] ?? 'Church app alert'}';
        sound = UriAndroidNotificationSound(uri);
      }
    }

    return AndroidNotificationDetails(
      channelId,
      channelName,
      color: MyColors.primary,
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: styleInformation,
      ticker: ticker,
      playSound: true,
      sound: sound,
    );
  }

  static Future<String?> _cachedToneUri(String toneUrl) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final extension = toneUrl.split('?').first.split('.').last.toLowerCase();
      final safeExtension =
          ['mp3', 'wav', 'aac', 'm4a', 'ogg'].contains(extension)
              ? extension
              : 'mp3';
      final file = File(
          '${directory.path}/notification_tone_${toneUrl.hashCode.abs()}.$safeExtension');

      if (!await file.exists() || await file.length() == 0) {
        await Dio().download(toneUrl, file.path);
      }

      return Uri.file(file.path).toString();
    } catch (error) {
      print('Unable to cache notification tone: $error');
      return null;
    }
  }

  static bool _readBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    final text = value.toString().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes';
  }

  static String _stripHtml(dynamic value) {
    return value
        .toString()
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<String?> onSelect(String? itm) async {
    print("onSelectNotification $itm");
    Map<String, dynamic> message = json.decode(itm!);
    var data = message;
    //['data'];
    /*if (data == null) {
      data = message;
    }*/
    var action = data["action"];
    print("pushNotification = " + action);
    if (action == "newMedia") {
      Map<String, dynamic> arts = json.decode(data['media']);
      Media media = Media.fromJson(arts);
      navigateMedia(media);
    }
    if (action == "inbox") {
      Map<String, dynamic> arts = json.decode(data['inbox']);
      Inbox inbox = Inbox.fromJson(arts);
      navigateInbox(inbox);
    }

    if (action == "events") {
      Map<String, dynamic> arts = json.decode(data['events']);
      Events events = Events.fromJson(arts);
      navigateEvents(events);
    }

    if (action == "livestream") {
      Map<String, dynamic> livestream = json.decode(data['livestream']);
      LiveStreams liveStreams = LiveStreams.fromJson(livestream);
      navigateLivestreams(liveStreams);
    }

    return null;
  }

  sendFirebaseTokenToServer(String? token) async {
    bool? status = false;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final uploadedToken = prefs.getString("firebase_token_uploaded_to_server");
    if (uploadedToken != token && token != null && token.isNotEmpty) {
      status = false;
    } else if (prefs.getBool("token_sent_to_server") != null) {
      status = prefs.getBool("token_sent_to_server");
    }
    if (status == false) {
      print("Firebase token not yet sent to server");

      var data = {"token": token, "version": "v2"};
      print(data.toString());
      try {
        final response = await http.post(Uri.parse(ApiUrl.storeFcmToken),
            body: jsonEncode({"data": data}));
        if (response.statusCode == 200) {
          // If the server did return a 200 OK response,
          // then parse the JSON.
          print(response.body);
          Map<String, dynamic> res = json.decode(response.body);
          if (res["status"] == "ok") {
            prefs.setBool("token_sent_to_server", true);
            if (token != null && token.isNotEmpty) {
              prefs.setString("firebase_token_uploaded_to_server", token);
            }
          }
        }
      } catch (exception) {
        // I get no exception here
        print(exception);
      }
    } else {
      print("Firebase token sent to server");
    }
  }
}
