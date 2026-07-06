import 'dart:async';

import 'package:dio/dio.dart';

import '../features/fundraising/fundraising_api.dart';
import '../models/GoshenRetreat.dart';
import '../models/Userdata.dart';
import '../prayers/prayer_api_client.dart';
import '../testimonies/testimony_api_client.dart';
import 'DynamicFormApi.dart';
import 'GoshenExperienceApi.dart';
import 'GoshenRetreatApi.dart';
import 'GoshenWalletApi.dart';
import 'GivingStatusApi.dart';

class MoreMenuPreloadSnapshot {
  const MoreMenuPreloadSnapshot({
    required this.testimoniesEnabled,
    required this.goshenRetreatEnabled,
    required this.fundraisingEnabled,
    required this.prayerPointsEnabled,
    required this.interactivePrayerWallEnabled,
    required this.hymnsEnabled,
    required this.devotionalsEnabled,
    required this.churchGroupsEnabled,
    required this.dynamicFormsEnabled,
    required this.goshenQuizEnabled,
    required this.scannerManagerEnabled,
    required this.scannerConsoleEnabled,
    required this.warmedAt,
  });

  final bool testimoniesEnabled;
  final bool goshenRetreatEnabled;
  final bool fundraisingEnabled;
  final bool prayerPointsEnabled;
  final bool interactivePrayerWallEnabled;
  final bool hymnsEnabled;
  final bool devotionalsEnabled;
  final bool churchGroupsEnabled;
  final bool dynamicFormsEnabled;
  final bool goshenQuizEnabled;
  final bool scannerManagerEnabled;
  final bool scannerConsoleEnabled;
  final DateTime warmedAt;

  bool get isFresh =>
      DateTime.now().difference(warmedAt) < const Duration(minutes: 3);
}

class MoreMenuPreloadService {
  MoreMenuPreloadService._();

  static final MoreMenuPreloadService instance = MoreMenuPreloadService._();

  MoreMenuPreloadSnapshot? _snapshot;
  Future<MoreMenuPreloadSnapshot>? _inFlight;

  MoreMenuPreloadSnapshot? get snapshot => _snapshot;

  void warmQuietly({
    Userdata? user,
    Map<String, dynamic>? homeData,
    bool force = false,
  }) {
    unawaited(warm(user: user, homeData: homeData, force: force)
        .then<void>((_) {})
        .catchError((_) {}));
  }

  Future<MoreMenuPreloadSnapshot> warm({
    Userdata? user,
    Map<String, dynamic>? homeData,
    bool force = false,
  }) {
    final current = _snapshot;
    if (!force && current != null && current.isFresh) {
      return Future.value(current);
    }

    final active = _inFlight;
    if (!force && active != null) return active;

    _inFlight = _warm(user: user, homeData: homeData).whenComplete(() {
      _inFlight = null;
    });

    return _inFlight!;
  }

  Future<MoreMenuPreloadSnapshot> _warm({
    Userdata? user,
    Map<String, dynamic>? homeData,
  }) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ));

    var testimoniesEnabled = homeData?['testimonies_enabled'] == true ||
        _snapshot?.testimoniesEnabled == true;
    var goshenRetreatEnabled = homeData?['goshen_retreat_enabled'] == true ||
        _snapshot?.goshenRetreatEnabled == true;
    var fundraisingEnabled = homeData?['fundraising_enabled'] == true ||
        _snapshot?.fundraisingEnabled == true;
    var prayerPointsEnabled = _readModuleFlag(
        homeData, 'prayer_points_enabled', _snapshot?.prayerPointsEnabled);
    var interactivePrayerWallEnabled = _readModuleFlag(
        homeData,
        'interactive_prayer_wall_enabled',
        _snapshot?.interactivePrayerWallEnabled);
    var hymnsEnabled =
        _readModuleFlag(homeData, 'hymns_enabled', _snapshot?.hymnsEnabled);
    var devotionalsEnabled = _readModuleFlag(
        homeData, 'devotionals_enabled', _snapshot?.devotionalsEnabled);
    var churchGroupsEnabled = _readModuleFlag(
        homeData, 'church_groups_enabled', _snapshot?.churchGroupsEnabled);
    var dynamicFormsEnabled = _readModuleFlag(
        homeData, 'dynamic_forms_enabled', _snapshot?.dynamicFormsEnabled);
    var goshenQuizEnabled = _readModuleFlag(
        homeData, 'goshen_quiz_enabled', _snapshot?.goshenQuizEnabled);
    var scannerManagerEnabled = _snapshot?.scannerManagerEnabled ?? false;
    var scannerConsoleEnabled = _snapshot?.scannerConsoleEnabled ?? false;

    final testimonyApi = TestimonyApiClient(dio: dio);
    final retreatApi = GoshenRetreatApi(dio: dio);
    final fundraisingApi = FundraisingApi(dio: dio);

    final featureResults = await Future.wait<dynamic>([
      testimonyApi.isEnabled().catchError((_) => testimoniesEnabled),
      retreatApi.isEnabled().catchError((_) => goshenRetreatEnabled),
      fundraisingApi.hasActiveCampaign().catchError((_) => fundraisingEnabled),
    ]);

    testimoniesEnabled = featureResults[0] == true;
    goshenRetreatEnabled = featureResults[1] == true;
    fundraisingEnabled = featureResults[2] == true;

    GoshenScannerStatus? scannerStatus;
    if (goshenRetreatEnabled &&
        user != null &&
        (user.apiToken ?? '').trim().isNotEmpty) {
      try {
        scannerStatus = await retreatApi.fetchScannerStatus(user);
        scannerConsoleEnabled = _hasScannerConsoleAccess(scannerStatus);
        scannerManagerEnabled = scannerStatus.managerAllowed &&
            scannerStatus.scannerEnabled &&
            !scannerStatus.scannerSuspended;
      } catch (_) {}
    }

    final warmers = <Future<void>>[
      GivingStatusApi(dio: dio).fetchStatus().then((_) {}).catchError((_) {}),
      if (testimoniesEnabled)
        testimonyApi.fetchTestimonies().then((_) {}).catchError((_) {}),
      if (fundraisingEnabled)
        fundraisingApi.fetchActiveCampaign().then((_) {}).catchError((_) {}),
      if (dynamicFormsEnabled)
        DynamicFormApi(dio: dio)
            .fetchForms(user)
            .then((_) {})
            .catchError((_) {}),
      if (interactivePrayerWallEnabled)
        PrayerApiClient(dio: dio)
            .fetchPrayerFeed(user: user)
            .then((_) {})
            .catchError((_) {}),
      if (interactivePrayerWallEnabled)
        PrayerApiClient(dio: dio)
            .fetchActivePropheticDecree()
            .then((_) {})
            .catchError((_) {}),
    ];

    if (goshenRetreatEnabled) {
      warmers.add(retreatApi.fetchEvents().then((_) {}).catchError((_) {}));
      if (user != null && (user.apiToken ?? '').trim().isNotEmpty) {
        warmers.addAll([
          retreatApi.fetchMyRetreatData(user).then((_) {}).catchError((_) {}),
          GoshenWalletApi(dio: dio)
              .fetchWallet(user)
              .then((_) {})
              .catchError((_) {}),
          GoshenExperienceApi(dio: dio)
              .fetchSurveys(user)
              .then((_) {})
              .catchError((_) {}),
        ]);
      }
    }

    await Future.wait(warmers);

    final next = MoreMenuPreloadSnapshot(
      testimoniesEnabled: testimoniesEnabled,
      goshenRetreatEnabled: goshenRetreatEnabled,
      fundraisingEnabled: fundraisingEnabled,
      prayerPointsEnabled: prayerPointsEnabled,
      interactivePrayerWallEnabled: interactivePrayerWallEnabled,
      hymnsEnabled: hymnsEnabled,
      devotionalsEnabled: devotionalsEnabled,
      churchGroupsEnabled: churchGroupsEnabled,
      dynamicFormsEnabled: dynamicFormsEnabled,
      goshenQuizEnabled: goshenQuizEnabled,
      scannerManagerEnabled: scannerManagerEnabled,
      scannerConsoleEnabled: scannerConsoleEnabled,
      warmedAt: DateTime.now(),
    );
    _snapshot = next;
    return next;
  }

  bool _hasScannerConsoleAccess(GoshenScannerStatus status) {
    if (!status.enabled || !status.scannerEnabled) return false;
    if (status.allowed || status.managerAllowed) return true;

    final normalizedRoles = status.roles.map(
      (role) => role.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''),
    );
    return normalizedRoles.any(
      (role) => const {
        'eventscanner',
        'eventmanager',
        'superadmin',
      }.contains(role),
    );
  }

  bool _readModuleFlag(
    Map<String, dynamic>? data,
    String key,
    bool? previous,
  ) {
    final value = data?[key];
    if (value == null) return previous ?? true;
    if (value is bool) return value;
    final text = value.toString().toLowerCase().trim();
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }
}
