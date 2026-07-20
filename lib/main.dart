import 'dart:async';

import 'package:churchapp_flutter/firebase_options.dart';
import 'package:churchapp_flutter/i18n/strings.g.dart';
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:provider/provider.dart';
import 'providers/AppStateManager.dart';
import 'package:flutter/services.dart';
import './providers/translate_provider.dart';
import './utils/my_colors.dart';
import 'package:flutter/cupertino.dart';
import 'MyApp.dart';
import './providers/BibleModel.dart';
import './providers/BookmarksModel.dart';
import './providers/PlaylistsModel.dart';
import './providers/AudioPlayerModel.dart';
import './providers/HymnsBookmarksModel.dart';
import './providers/DownloadsModel.dart';
import './providers/NotesProvider.dart';
import './providers/HomeProvider.dart';
import './wallet_security/wallet_security_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './screens/OnboardingPage.dart';
import './screens/HomePage.dart';
import 'package:isolated_download_manager/isolated_download_manager.dart';
import 'package:just_audio_background/just_audio_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();
  await _initializeFirebase();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: MyColors.primaryDark,
      statusBarBrightness: Brightness.light));

  Future<Widget> getFirstScreen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool("user_seen_onboarding_page") == null ||
        prefs.getBool("user_seen_onboarding_page") == false) {
      return new OnboardingPage();
    } else {
      return HomePage();
    }
  }

  runApp(
    TranslationProvider(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppStateManager()),
          ChangeNotifierProvider(create: (_) => BookmarksModel()),
          ChangeNotifierProvider(create: (_) => PlaylistsModel()),
          ChangeNotifierProvider(create: (_) => AudioPlayerModel()),
          ChangeNotifierProvider(create: (_) => DownloadsModel()),
          ChangeNotifierProvider(create: (_) => HymnsBookmarksModel()),
          ChangeNotifierProvider(create: (_) => NotesProvider()),
          ChangeNotifierProvider(create: (_) => BibleModel()),
          ChangeNotifierProvider(create: (_) => HomeProvider()),
          ChangeNotifierProvider(create: (_) => TranslateProvider()),
          ChangeNotifierProvider(create: (_) => WalletSecurityController()),
        ],
        child: FutureBuilder<Widget>(
          future: getFirstScreen(), //returns bool
          builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return MyApp(defaultHome: snapshot.data);
            } else {
              return Center(child: CupertinoActivityIndicator());
            }
          },
        ),
      ),
    ),
  );

  // Download and audio background services are not needed to draw the home
  // screen. Start them after the first frame so cold starts stay responsive.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeDeferredServices());
  });
}

Future<void> _initializeDeferredServices() async {
  try {
    await DownloadManager.instance.init(
      isolates: 2,
    );
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      notificationColor: MyColors.primary,
    );
  } catch (error) {
    // These are optional at launch and will be initialized again by their
    // feature flows if necessary. Never block the home screen on them.
    print('Deferred app services could not initialize: $error');
  }
}

Future<void> _initializeFirebase() async {
  try {
    if (firebase_core.Firebase.apps.isEmpty) {
      await firebase_core.Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on firebase_core.FirebaseException catch (error) {
    if (error.code != 'duplicate-app') {
      rethrow;
    }
  }
}
