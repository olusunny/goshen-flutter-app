import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:churchapp_flutter/models/Bible.dart';
import 'package:churchapp_flutter/models/Categories.dart';
import 'package:churchapp_flutter/models/Downloads.dart';
import 'package:churchapp_flutter/models/Events.dart';
import 'package:churchapp_flutter/models/Hymns.dart';
import 'package:churchapp_flutter/models/Inbox.dart';
import 'package:churchapp_flutter/models/Notes.dart';
import 'package:churchapp_flutter/models/Playlists.dart';
import 'package:flutter_quill/flutter_quill.dart';
import './notes/NewNoteScreen.dart';
import './notes/NotesEditorScreen.dart';
import './models/Userdata.dart';
import './models/GoshenWallet.dart';
import './features/fundraising/fundraising_screen.dart';
import './features/counseling/counseling_screen.dart';
import './models/LiveStreams.dart';
import './screens/BibleTranslator.dart';
import './screens/AudioScreen.dart';
import 'package:flutter/material.dart';
import './screens/BibleScreen.dart';
import './i18n/strings.g.dart';
import 'package:provider/provider.dart';
import './screens/HomePage.dart';
import './utils/TextStyles.dart';
import 'package:flutter/cupertino.dart';
import './screens/PlaylistsScreen.dart';
import './screens/BookmarkScreen.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import './socials/UserProfileScreen.dart';
import './providers/AudioPlayerModel.dart';
import './screens/BibleVersionsScreen.dart';
import './screens/HymnsViewerScreen.dart';
import 'socials/UpdateUserProfile.dart';
import './screens/BibleSearchScreen.dart';
import './screens/InboxListScreen.dart';
import './screens/BibleVerseCompare.dart';
import './screens/CategoriesScreen.dart';
import './screens/EventsViewerScreen.dart';
import './screens/InboxViewerScreen.dart';
import './socials/Settings.dart';
import './screens/HymnsListScreen.dart';
import './screens/BookmarkedHymnsListScreen.dart';
import './providers/AppStateManager.dart';
import './screens/AddPlaylistScreen.dart';
import './screens/PlaylistMediaScreen.dart';
import 'notes/NotesListScreen.dart';
import './screens/ColoredHighightedVerses.dart';
import './screens/SearchScreen.dart';
import './screens/CategoriesMediaScreen.dart';
import './screens/BranchesScreen.dart';
import './screens/EventsListScreen.dart';
import './screens/DevotionalScreen.dart';
import './audio_player/player_page.dart';
import './video_player/VideoPlayer.dart';
import './livetvplayer/LivestreamsPlayer.dart';
import './screens/Downloader.dart';
import './screens/DynamicFormsScreen.dart';
import './auth/LoginScreen.dart';
import './auth/PhoneOtpLoginScreen.dart';
import './audio_player/radio_player.dart';
import './auth/RegisterScreen.dart';
import './screens/VideoScreen.dart';
import './auth/ForgotPasswordScreen.dart';
import './auth/VerifyEmailScreen.dart';
import './screens/PastorsScreen.dart';
import './screens/GroupsScreen.dart';
import './screens/ManageGroupsScreen.dart';
import './screens/GalleryScreen.dart';
import './screens/GoshenExperienceScreen.dart';
import './screens/GoshenPaymentReturnScreen.dart';
import './screens/GoshenQuizScreen.dart';
import './screens/GoshenRetreatScreen.dart';
import './screens/GoshenWalletScreen.dart';
import './screens/GoshenWalletTransferScreen.dart';
import './screens/MoreMenuScreen.dart';
import './models/ScreenArguements.dart';
import './service/Firebase.dart';
import './models/Media.dart';
import './providers/events.dart';
import './models/UserEvents.dart';
import './screens/WebViewScreen.dart';
import './screens/DonationAccountsScreen.dart';
import './screens/AboutUsScreen.dart';
import './screens/ContactUsScreen.dart';
import './screens/SuggestionScreen.dart';
import './screens/TransportationArrangementsScreen.dart';
import './prayers/prayer_community_screen.dart';
import './prayers/prayer_points_screen.dart';
import './testimonies/testimony_wall_screen.dart';
import './wallet_security/wallet_security_controller.dart';
import './wallet_security/wallet_security_guard.dart';
import './utils/goshen_payment_return_link.dart';
import './features/prayer_session_attendance/prayer_session_attendance_link.dart';
import './features/prayer_session_attendance/prayer_session_attendance_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({
    Key? key,
    required Widget? defaultHome,
  })  : _defaultHome = defaultHome,
        super(key: key);
  final Widget? _defaultHome;

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late AppStateManager appStateManager;
  AppLifecycleState? state;
  final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey(debugLabel: "Main Navigator");
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _appLinkSubscription;
  String? _lastHandledPaymentLink;

  List<Media?> _mediaPlaylistFromArguments(
    List<Object?>? rawItems,
    Media? fallback,
  ) {
    final playlist = <Media?>[];

    for (final item in rawItems ?? const <Object?>[]) {
      if (item is Media) {
        playlist.add(item);
      }
    }

    if (playlist.isEmpty && fallback != null) {
      playlist.add(fallback);
    }

    return playlist;
  }

  navigateMedia(Media media) {
    print("push notification media = " + media.title!);
    List<Media?> mediaList = [];
    mediaList.add(media);
    if (media.mediaType!.toLowerCase() == "audio") {
      print("audio media = " + media.title!);
      Provider.of<AudioPlayerModel>(context, listen: false)
          .preparePlaylist(mediaList, media);
      navigatorKey.currentState!.pushNamed(PlayPage.routeName);
    } else {
      print("video media = " + media.title!);

      navigatorKey.currentState!.pushNamed(VideoPlayer.routeName,
          arguments: ScreenArguements(
            position: 0,
            items: media,
            itemsList: mediaList,
          ));
    }
  }

  navigateLivestreams(LiveStreams liveStreams) {
    navigatorKey.currentState!.pushNamed(LivestreamsPlayer.routeName,
        arguments: ScreenArguements(
          items: liveStreams,
        ));
  }

  navigateInbox(Inbox inbox) {
    //navigatorKey.currentState.pushNamed(InboxListScreenState.routeName);
    navigatorKey.currentState!.pushNamed(InboxViewerScreen.routeName,
        arguments: ScreenArguements(
          position: 0,
          items: inbox,
          itemsList: [],
        ));
  }

  navigateEvents(Events events) {
    //navigatorKey.currentState.pushNamed(InboxListScreenState.routeName);
    navigatorKey.currentState!.pushNamed(EventsViewerScreen.routeName,
        arguments: ScreenArguements(
          position: 0,
          items: events,
          itemsList: [],
        ));
  }

  navigateDevotional(Map<String, dynamic> data) {
    navigatorKey.currentState!.pushNamed(
      DevotionalScreen.routeName,
      arguments: data,
    );
  }

  @override
  void initState() {
    Firebase(
      navigateMedia,
      navigateInbox,
      navigateLivestreams,
      navigateEvents,
      navigateDevotional,
      navigatePrayerSessionAttendance,
    ).init();
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPaymentLinks();
    eventBus.fire(OnAppStateChanged("active"));
    eventBus.on<OnAppOffline>().listen((event) {
      print("App offline event called");
      print("please store = " + event.items.toString());
    });
  }

  @override
  void dispose() {
    print("widget is disposed");
    WidgetsBinding.instance.removeObserver(this);
    _appLinkSubscription?.cancel();
    //Provider.of<AudioPlayerModel>(context, listen: false).cleanUpResources();
    super.dispose();
  }

  Future<void> _initPaymentLinks() async {
    _appLinks = AppLinks();
    try {
      final initialUri = await _appLinks!.getInitialLink();
      _handleIncomingPaymentLink(initialUri);
    } catch (error) {
      debugPrint('Goshen payment deep-link init failed: $error');
    }

    _appLinkSubscription = _appLinks!.uriLinkStream.listen(
      _handleIncomingPaymentLink,
      onError: (error) {
        debugPrint('Goshen payment deep-link stream failed: $error');
      },
    );
  }

  void _handleIncomingPaymentLink(Uri? uri) {
    if (uri == null) return;
    final attendanceLink = parsePrayerSessionAttendanceLink(uri);
    if (attendanceLink != null) {
      navigatePrayerSessionAttendance();
      return;
    }
    final paymentReturn = parseGoshenPaymentReturnLink(uri);
    if (paymentReturn == null) return;

    final linkKey = uri.toString();
    if (_lastHandledPaymentLink == linkKey) return;
    _lastHandledPaymentLink = linkKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) {
            final screen = GoshenPaymentReturnScreen(
              success: paymentReturn.success,
              wallet: paymentReturn.wallet,
              flow: paymentReturn.flow,
            );
            return paymentReturn.wallet
                ? WalletSecurityGate(child: screen)
                : screen;
          },
        ),
      );
    });
  }

  Future<void> navigatePrayerSessionAttendance() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = await appStateManager.ensureUserDataLoaded();
      if (user == null || user.activated != 0 || !mounted) return;
      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => PrayerSessionAttendanceScreen(user: user),
      ));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appLifecycleState) async {
    state = appLifecycleState;
    Provider.of<WalletSecurityController>(context, listen: false)
        .handleLifecycleState(appLifecycleState);
    print("Current app state = " + appLifecycleState.toString());
    print(":::::::");
    switch (state) {
      case null:
        break;
      case AppLifecycleState.paused:
        eventBus.fire(OnAppStateChanged("idle"));
        break;
      case AppLifecycleState.resumed:
        eventBus.fire(OnAppStateChanged("active"));
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    appStateManager = Provider.of<AppStateManager>(context);
    final platform = Theme.of(context).platform;
    return RefreshConfiguration(
      footerTriggerDistance: 15,
      dragSpeedRatio: 0.91,
      headerBuilder: () => MaterialClassicHeader(),
      footerBuilder: () => ClassicFooter(),
      enableLoadingWhenNoData: false,
      shouldFooterFollowWhenNotFull: (state) {
        // If you want load more with noMoreData state ,may be you should return false
        return false;
      },
      //autoLoad: true,
      child: MaterialApp(
        theme: appStateManager.themeData,
        navigatorKey: navigatorKey,
        title: 'App',
        localizationsDelegates: const [
          FlutterQuillLocalizations.delegate,
        ],
        home: appStateManager.isLoadingTheme
            ? Container(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(height: 10),
                        Text(t.appname,
                            style: TextStyles.medium(context).copyWith(
                                fontFamily: "serif",
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 30)),
                        Container(height: 12),
                        Text(t.initializingapp,
                            style: TextStyles.body1(context)
                                .copyWith(color: Colors.grey[500])),
                        Container(height: 50),
                        CupertinoActivityIndicator(
                          radius: 20,
                        )
                      ],
                    ),
                  ),
                ),
              )
            : widget._defaultHome,
        debugShowCheckedModeBanner: false,
        onGenerateRoute: (settings) {
          if (settings.name == AddPlaylistScreen.routeName) {
            // Cast the arguments to the correct type: ScreenArguments.
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return AddPlaylistScreen(
                  media: args!.items as Media?,
                );
              },
            );
          }

          if (settings.name == PlaylistMediaScreen.routeName) {
            // Cast the arguments to the correct type: ScreenArguments.
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return PlaylistMediaScreen(
                  playlists: args!.items as Playlists?,
                );
              },
            );
          }

          if (settings.name == CategoriesMediaScreen.routeName) {
            // Cast the arguments to the correct type: ScreenArguments.
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return CategoriesMediaScreen(
                  categories: args!.items as Categories?,
                );
              },
            );
          }

          if (settings.name == VideoPlayer.routeName) {
            // Cast the arguments to the correct type: ScreenArguments.
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                final media = args!.items as Media?;
                return VideoPlayer(
                  media: media,
                  mediaList: _mediaPlaylistFromArguments(
                    args.itemsList,
                    media,
                  ),
                );
              },
            );
          }

          if (settings.name == BibleVerseCompare.routeName) {
            // Cast the arguments to the correct type: ScreenArguments.
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return BibleVerseCompare(
                  bible: args!.items as Bible?,
                );
              },
            );
          }

          if (settings.name == UserProfileScreen.routeName) {
            // Cast the arguments to the correct type: ScreenArguments.
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return UserProfileScreen(
                  user: args?.items as Userdata?,
                );
              },
            );
          }

          if (settings.name == ProfileDetailsScreen.routeName) {
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return ProfileDetailsScreen(
                  user: args?.items as Userdata?,
                );
              },
            );
          }

          if (settings.name == BibleTranslator.routeName) {
            // Cast the arguments to the correct type: ScreenArguments.
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return BibleTranslator(
                  bible: args!.items as Bible?,
                );
              },
            );
          }

          if (settings.name == WebViewScreen.routeName) {
            // Cast the arguments to the correct type: ScreenArguments.
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return WebViewScreen(
                  url: args!.url!,
                  title: args.title!,
                );
              },
            );
          }

          if (settings.name == HymnsViewerScreen.routeName) {
            // Cast the arguments to the correct type: ScreenArguments.
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return HymnsViewerScreen(
                  hymns: args!.items as Hymns?,
                );
              },
            );
          }

          if (settings.name == LivestreamsPlayer.routeName) {
            // Cast the arguments to the correct type: ScreenArguments.
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return LivestreamsPlayer(
                    liveStreams: args!.items as LiveStreams?);
              },
            );
          }

          if (settings.name == CategoriesScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return CategoriesScreen();
              },
            );
          }

          if (settings.name == SettingsScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const SettingsScreen();
              },
            );
          }

          if (settings.name == ColoredHighightedVerses.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return ColoredHighightedVerses();
              },
            );
          }

          if (settings.name == BibleSearchScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return BibleSearchScreen();
              },
            );
          }

          if (settings.name == BookmarksScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return BookmarksScreen();
              },
            );
          }

          if (settings.name == PlaylistsScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return PlaylistsScreen();
              },
            );
          }

          if (settings.name == BranchesScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return BranchesScreen();
              },
            );
          }

          if (settings.name == EventsListScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return EventsListScreen();
              },
            );
          }

          if (settings.name == InboxListScreenState.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return InboxListScreenState();
              },
            );
          }

          if (settings.name == NotesListScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return NotesListScreen();
              },
            );
          }

          if (settings.name == BookmarkedHymnsListScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return BookmarkedHymnsListScreen();
              },
            );
          }

          if (settings.name == BibleScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return BibleScreen();
              },
            );
          }

          if (settings.name == DonationAccountsScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const DonationAccountsScreen();
              },
            );
          }

          if (settings.name == DynamicFormsScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const DynamicFormsScreen();
              },
            );
          }

          if (settings.name == FundraisingScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const FundraisingScreen();
              },
            );
          }

          if (settings.name == CounselingScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const CounselingScreen();
              },
            );
          }

          if (settings.name == AboutUsScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const AboutUsScreen();
              },
            );
          }

          if (settings.name == AboutUsScreen.termsRouteName) {
            return MaterialPageRoute(
              builder: (context) {
                return const AboutUsScreen(type: 'terms', title: 'Terms');
              },
            );
          }

          if (settings.name == AboutUsScreen.privacyRouteName) {
            return MaterialPageRoute(
              builder: (context) {
                return const AboutUsScreen(type: 'privacy', title: 'Privacy');
              },
            );
          }

          if (settings.name == SuggestionScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const SuggestionScreen();
              },
            );
          }

          if (settings.name == ContactUsScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const ContactUsScreen();
              },
            );
          }

          if (settings.name == TransportationArrangementsScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const TransportationArrangementsScreen();
              },
            );
          }

          if (settings.name == GroupsScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const GroupsScreen();
              },
            );
          }

          if (settings.name == ManageGroupsScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const ManageGroupsScreen();
              },
            );
          }

          if (settings.name == GalleryScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const GalleryScreen();
              },
            );
          }

          if (settings.name == MoreMenuScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const MoreMenuScreen();
              },
            );
          }

          if (settings.name == GoshenRetreatScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const GoshenRetreatScreen();
              },
            );
          }

          if (settings.name == GoshenMyRegistrationScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const GoshenMyRegistrationScreen();
              },
            );
          }

          if (settings.name == GoshenPaymentReturnScreen.routeName) {
            final args = settings.arguments;
            final success = args is Map
                ? args['success'] == true
                : args is bool
                    ? args
                    : true;
            final wallet = args is Map && args['wallet'] == true;
            final flow = args is Map
                ? _paymentReturnFlowFromArgument(args['flow'])
                : null;
            return MaterialPageRoute(
              builder: (context) {
                final screen = GoshenPaymentReturnScreen(
                  success: success,
                  wallet: wallet,
                  flow: flow,
                );
                return (flow == GoshenPaymentReturnFlow.wallet || wallet)
                    ? WalletSecurityGate(child: screen)
                    : screen;
              },
            );
          }

          if (settings.name == GoshenWalletScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const WalletSecurityGate(
                  child: GoshenWalletScreen(),
                );
              },
            );
          }

          if (settings.name == GoshenWalletTransferScreen.routeName) {
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return WalletSecurityGate(
                  requireFreshVerification: true,
                  child: GoshenWalletTransferScreen(
                    initialWallet: args?.items as GoshenWallet?,
                  ),
                );
              },
            );
          }

          if (settings.name == GoshenWalletWithdrawalScreen.routeName) {
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return WalletSecurityGate(
                  requireFreshVerification: true,
                  child: GoshenWalletWithdrawalScreen(
                    initialWallet: args?.items as GoshenWallet?,
                  ),
                );
              },
            );
          }

          if (settings.name == GoshenWalletActivityDetailScreen.routeName) {
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            final entry = args?.items as GoshenWalletLedgerEntry?;
            if (entry == null) {
              return MaterialPageRoute(
                builder: (context) => const GoshenWalletScreen(),
              );
            }
            return MaterialPageRoute(
              builder: (context) {
                return WalletSecurityGate(
                  child: GoshenWalletActivityDetailScreen(entry: entry),
                );
              },
            );
          }

          if (settings.name == GoshenExperienceScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const GoshenExperienceScreen();
              },
            );
          }

          if (settings.name == GoshenQuizScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const GoshenQuizScreen();
              },
            );
          }

          if (settings.name == UpdateUserProfile.routeName) {
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return UpdateUserProfile(
                  check: args?.check ?? false,
                );
              },
            );
          }

          if (settings.name == EventsViewerScreen.routeName) {
            // Cast the arguments to the correct type: ScreenArguments.
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return EventsViewerScreen(
                  events: args!.items as Events?,
                );
              },
            );
          }

          if (settings.name == InboxViewerScreen.routeName) {
            // Cast the arguments to the correct type: ScreenArguments.
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return InboxViewerScreen(
                  inbox: args!.items as Inbox?,
                );
              },
            );
          }

          if (settings.name == HymnsListScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return HymnsListScreen();
              },
            );
          }

          if (settings.name == BibleVersionsScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return BibleVersionsScreen();
              },
            );
          }

          if (settings.name == DevotionalScreen.routeName) {
            final args = settings.arguments;
            String? devotionalId;
            String? devotionalDate;
            if (args is Map) {
              devotionalId = '${args['id'] ?? args['devotional_id'] ?? ''}';
              devotionalDate = '${args['date'] ?? ''}';
              if (devotionalId.trim().isEmpty) devotionalId = null;
              if (devotionalDate.trim().isEmpty) devotionalDate = null;
            }
            return MaterialPageRoute(
              builder: (context) {
                return DevotionalScreen(
                  devotionalId: devotionalId,
                  initialDate: devotionalDate,
                );
              },
            );
          }

          if (settings.name == VideoScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return VideoScreen();
              },
            );
          }

          if (settings.name == AudioScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return AudioScreen();
              },
            );
          }

          if (settings.name == PrayerCommunityScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return PrayerCommunityScreen();
              },
            );
          }

          if (settings.name == PrayerPointsScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const PrayerPointsScreen();
              },
            );
          }

          if (settings.name == TestimonyWallScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const TestimonyWallScreen();
              },
            );
          }

          if (settings.name == NotesEditorScreen.routeName) {
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (context) {
                  return NotesEditorScreen(
                    notes: args.items as Notes?,
                  );
                },
              );
            }
            return MaterialPageRoute(
              builder: (context) {
                return NotesEditorScreen();
              },
            );
          }

          if (settings.name == NewNotesScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return NewNotesScreen();
              },
            );
          }

          if (settings.name == SearchScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return SearchScreen();
              },
            );
          }

          if (settings.name == LoginScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return LoginScreen();
              },
            );
          }

          if (settings.name == PhoneOtpLoginScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const PhoneOtpLoginScreen();
              },
            );
          }

          if (settings.name == RegisterScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return RegisterScreen();
              },
            );
          }

          if (settings.name == ForgotPasswordScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return ForgotPasswordScreen();
              },
            );
          }

          if (settings.name == VerifyEmailScreen.routeName) {
            final args = settings.arguments as VerifyEmailArgs;
            return MaterialPageRoute(
              builder: (context) {
                return VerifyEmailScreen(
                  email: args.email,
                  password: args.password,
                );
              },
            );
          }

          if (settings.name == PastorsScreen.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return const PastorsScreen();
              },
            );
          }

          if (settings.name == PlayPage.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return PlayPage();
              },
            );
          }

          if (settings.name == RadioPlayer.routeName) {
            return MaterialPageRoute(
              builder: (context) {
                return RadioPlayer();
              },
            );
          }

          if (settings.name == Downloader.routeName) {
            // Cast the arguments to the correct type: ScreenArguments.
            final ScreenArguements? args =
                settings.arguments as ScreenArguements?;
            return MaterialPageRoute(
              builder: (context) {
                return Downloader(
                    downloads: args?.items as Downloads?, platform: platform);
              },
            );
          }

          return MaterialPageRoute(
            builder: (context) {
              return HomePage();
            },
          );
        },
      ),
    );
  }

  GoshenPaymentReturnFlow? _paymentReturnFlowFromArgument(Object? value) {
    if (value is GoshenPaymentReturnFlow) return value;
    if (value is! String) return null;

    return switch (value) {
      'wallet' => GoshenPaymentReturnFlow.wallet,
      'giving' => GoshenPaymentReturnFlow.giving,
      'retreat' || 'checkout' || 'payment' => GoshenPaymentReturnFlow.retreat,
      _ => null,
    };
  }
}
