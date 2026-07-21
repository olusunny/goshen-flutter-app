import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/LoginScreen.dart';
import '../database/SQLiteDbProvider.dart';
import '../models/GoshenRetreat.dart';
import '../models/GoshenWallet.dart';
import '../models/Media.dart';
import '../models/ScreenArguements.dart';
import '../models/Userdata.dart';
import '../service/GoshenRetreatApi.dart';
import '../service/GoshenWalletApi.dart';
import '../socials/UpdateUserProfile.dart';
import '../utils/ApiUrl.dart';
import '../utils/member_profile_requirements.dart';
import '../video_player/VideoPlayer.dart';
import '../wallet_security/wallet_security_guard.dart';

class GoshenRetreatScreen extends StatefulWidget {
  const GoshenRetreatScreen({super.key});

  static const routeName = '/goshen-retreat';

  @override
  State<GoshenRetreatScreen> createState() => _GoshenRetreatScreenState();
}

class _GoshenRetreatScreenState extends State<GoshenRetreatScreen> {
  late Future<List<GoshenRetreatEvent>> _future;

  @override
  void initState() {
    super.initState();
    _future = _initialEventsFuture();
  }

  Future<List<GoshenRetreatEvent>> _loadEvents() async {
    final api = GoshenRetreatApi();
    if (!await api.isEnabled()) {
      throw const _GoshenRetreatDisabledException();
    }

    return api.fetchEvents();
  }

  Future<List<GoshenRetreatEvent>> _initialEventsFuture() {
    final api = GoshenRetreatApi();
    final cachedEvents = api.cachedEvents;
    if (api.cachedEnabled != false && cachedEvents != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _refresh(silent: true));
      return Future.value(cachedEvents);
    }

    return _loadEvents();
  }

  Future<void> _refresh({bool silent = false}) async {
    final next = _loadEvents();
    if (!silent) {
      setState(() {
        _future = next;
      });
    }
    try {
      final events = await next;
      if (mounted && silent) {
        setState(() {
          _future = Future.value(events);
        });
      }
    } catch (_) {
      if (!silent) rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _GoshenPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Goshen Retreat')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: const Color(0xFFFFC857),
          onRefresh: _refresh,
          child: FutureBuilder<List<GoshenRetreatEvent>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                if (snapshot.error is _GoshenRetreatDisabledException) {
                  return _GoshenEmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Goshen Retreat is not available',
                    message:
                        'This retreat module is currently turned off by the admin team.',
                    colors: colors,
                  );
                }

                return _GoshenEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Retreat details are unavailable',
                  message:
                      'Please check your connection and pull down to try again.',
                  colors: colors,
                );
              }

              final events = snapshot.data ?? const [];
              if (events.isEmpty) {
                return _GoshenEmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'No retreat edition is published yet',
                  message:
                      'Published Goshen Retreat editions will appear here once the admin makes them live.',
                  colors: colors,
                );
              }

              final featuredEvent = _featuredEvent(events);
              Future<void> openEvent(GoshenRetreatEvent event) async {
                final result = await Navigator.push<Object?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GoshenRetreatDetailScreen(event: event),
                  ),
                );
                if (result != null && mounted) {
                  _refresh();
                }
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                children: [
                  _GoshenHero(
                    event: featuredEvent,
                    colors: colors,
                    onTap: () => openEvent(featuredEvent),
                  ),
                  const SizedBox(height: 14),
                  _GoshenLandingDescription(
                    event: featuredEvent,
                    colors: colors,
                  ),
                  const SizedBox(height: 14),
                  _GoshenCountdown(
                    target: featuredEvent.countdownTarget,
                    colors: colors,
                  ),
                  if (featuredEvent.pastVideos.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _PastGoshenVideosSlider(
                      videos: featuredEvent.pastVideos,
                      colors: colors,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _GoshenDateCard(event: featuredEvent, colors: colors),
                  const SizedBox(height: 14),
                  _GoshenAddressCard(event: featuredEvent, colors: colors),
                  if (featuredEvent.inquiryPhone.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _GoshenInquiryCard(event: featuredEvent, colors: colors),
                  ],
                  const SizedBox(height: 14),
                  _GoshenShareActions(
                    event: featuredEvent,
                    colors: colors,
                  ),
                  const SizedBox(height: 14),
                  _MyRegistrationShortcut(colors: colors),
                  const SizedBox(height: 18),
                  ...events.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _RetreatEventCard(
                        event: event,
                        colors: colors,
                        onTap: () => openEvent(event),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class GoshenMyRegistrationScreen extends StatefulWidget {
  const GoshenMyRegistrationScreen({super.key});

  static const routeName = '/goshen-my-registration';

  @override
  State<GoshenMyRegistrationScreen> createState() =>
      _GoshenMyRegistrationScreenState();
}

class _GoshenMyRegistrationScreenState extends State<GoshenMyRegistrationScreen>
    with WidgetsBindingObserver {
  final GlobalKey<_MyGoshenRegistrationsState> _registrationKey =
      GlobalKey<_MyGoshenRegistrationsState>();
  bool _refreshingAfterPaymentReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _refreshingAfterPaymentReturn) {
      return;
    }

    _refreshingAfterPaymentReturn = true;
    Future<void>.delayed(const Duration(milliseconds: 700), () async {
      try {
        await _registrationKey.currentState?._reload(silent: true);
      } finally {
        _refreshingAfterPaymentReturn = false;
      }
    });
  }

  Future<void> _refresh() async {
    try {
      await _registrationKey.currentState?._reload();
    } catch (_) {
      // The child renders the error state; pull-to-refresh should still settle.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _GoshenPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('My Registration')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: const Color(0xFFFFC857),
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
            children: [
              _MyGoshenRegistrations(
                key: _registrationKey,
                colors: colors,
                refreshVersion: 0,
                showEmptyState: true,
                margin: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoshenRetreatDisabledException implements Exception {
  const _GoshenRetreatDisabledException();
}

GoshenRetreatEvent _featuredEvent(List<GoshenRetreatEvent> events) {
  final now = DateTime.now();
  final upcoming = events.where((event) {
    final target = event.countdownTarget;
    return target != null && !target.isBefore(now);
  }).toList()
    ..sort((a, b) => a.countdownTarget!.compareTo(b.countdownTarget!));

  return upcoming.isNotEmpty ? upcoming.first : events.first;
}

class GoshenRetreatDetailScreen extends StatelessWidget {
  const GoshenRetreatDetailScreen({super.key, required this.event});

  final GoshenRetreatEvent event;

  @override
  Widget build(BuildContext context) {
    final colors = _GoshenPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Retreat details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          _GoshenDetailHero(event: event, colors: colors),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Ticket types',
            icon: Icons.confirmation_number_outlined,
            colors: colors,
            child: event.ticketTypes.isEmpty
                ? Text(
                    'Ticket types will be published soon.',
                    style: TextStyle(color: colors.muted),
                  )
                : Column(
                    children: event.ticketTypes
                        .map((ticket) =>
                            _TicketRow(ticket: ticket, colors: colors))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 14),
          _RegistrationStatusNotice(event: event, colors: colors),
          _RegistrationManagerPanel(event: event, colors: colors),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB522),
              foregroundColor: const Color(0xFF0C2230),
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            onPressed: () {
              if (!event.registration.open) {
                _showNotice(
                  context,
                  'Registration closed',
                  event.registration.message,
                );
                return;
              }
              _openRegistrationSheet(context);
            },
            icon: const Icon(Icons.how_to_reg_rounded),
            label: Text(event.registration.open
                ? 'Start registration'
                : 'Registration closed'),
          ),
        ],
      ),
    );
  }

  Future<void> _openRegistrationSheet(BuildContext context) async {
    if (event.ticketTypes.isEmpty) {
      _showNotice(
        context,
        'Tickets are not ready',
        'Ticket types have not been published for this retreat edition yet.',
      );
      return;
    }

    final user = await SQLiteDbProvider.db.getUserData();
    if (user == null || (user.apiToken ?? '').trim().isEmpty) {
      _showLoginPrompt(context);
      return;
    }

    final missingProfileFields = _missingGoshenProfileFields(user);
    if (missingProfileFields.isNotEmpty) {
      if (!context.mounted) return;
      _showProfilePrompt(context, missingProfileFields);
      return;
    }

    if (!context.mounted) return;
    final shouldRefresh = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoshenRegistrationSheet(event: event, user: user),
    );

    if (shouldRefresh == true && context.mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showLoginPrompt(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign in required'),
        content: const Text(
          'Please sign in or create an account before registering for Goshen Retreat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, LoginScreen.routeName);
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  List<String> _missingGoshenProfileFields(Userdata user) {
    return missingGoshenProfileFields(
      memberType: user.memberType,
      title: user.profileTitle,
      name: user.name,
      email: user.email,
      phone: user.phone,
      gender: user.gender,
      maritalStatus: user.maritalStatus,
      countryOfResidence: user.countryOfResidence,
      stateCountyProvince: user.stateCountyProvince,
      address: user.address,
    );
  }

  void _showProfilePrompt(BuildContext context, List<String> fields) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Complete your profile'),
        content: Text(
          'Before registering for Goshen Retreat, please add your ${_joinFieldList(fields)}. This helps the retreat team prepare your ticket, payment record, and attendee support correctly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB522),
              foregroundColor: const Color(0xFF0C2230),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, UpdateUserProfile.routeName);
            },
            child: const Text('Update profile'),
          ),
        ],
      ),
    );
  }

  void _showNotice(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _RegistrationStatusNotice extends StatelessWidget {
  const _RegistrationStatusNotice({
    required this.event,
    required this.colors,
  });

  final GoshenRetreatEvent event;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    if (event.registration.open && !event.payInFullDiscount.available) {
      return const SizedBox.shrink();
    }

    final closed = !event.registration.open;
    final discountText = event.payInFullDiscount.available
        ? '${event.payInFullDiscount.label} is available for pay-in-full registrations during the active discount window.'
        : '';
    final message = closed ? event.registration.message : discountText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: closed ? const Color(0xFFFFF3E0) : const Color(0xFFEAF7F1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: closed ? const Color(0xFFFFB74D) : const Color(0xFF9AD5BA),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              closed ? Icons.lock_clock_rounded : Icons.local_offer_outlined,
              color: closed ? const Color(0xFF8A4B00) : const Color(0xFF14513F),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: closed
                      ? const Color(0xFF5B3500)
                      : const Color(0xFF14513F),
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationManagerPanel extends StatefulWidget {
  const _RegistrationManagerPanel({
    required this.event,
    required this.colors,
  });

  final GoshenRetreatEvent event;
  final _GoshenPalette colors;

  @override
  State<_RegistrationManagerPanel> createState() =>
      _RegistrationManagerPanelState();
}

class _RegistrationManagerPanelState extends State<_RegistrationManagerPanel> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Userdata?>(
      future: SQLiteDbProvider.db.getUserData(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (!_canManageRegistration(user)) return const SizedBox.shrink();

        final open = widget.event.registration.open;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _SectionCard(
            title: 'Registration control',
            icon: Icons.admin_panel_settings_outlined,
            colors: widget.colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  open
                      ? 'Registration is open for members.'
                      : widget.event.registration.message,
                  style: TextStyle(
                    color: widget.colors.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _toggle(user!, !open),
                  icon:
                      Icon(open ? Icons.lock_rounded : Icons.lock_open_rounded),
                  label: Text(_busy
                      ? 'Updating...'
                      : open
                          ? 'Close registration'
                          : 'Reopen registration'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggle(Userdata user, bool open) async {
    String reason = 'Registration has been closed by the event manager.';
    if (!open) {
      final controller = TextEditingController(text: reason);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Close registration?'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason shown in the app',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Close registration'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      reason = controller.text.trim().isEmpty ? reason : controller.text.trim();
    }

    setState(() => _busy = true);
    try {
      final updatedEvent = await GoshenRetreatApi().updateRegistrationStatus(
        user: user,
        event: widget.event,
        registrationOpen: open,
        reason: open ? null : reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(open ? 'Registration reopened.' : 'Registration closed.'),
        ),
      );
      Navigator.pop(context, updatedEvent);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

bool _canManageRegistration(Userdata? user) {
  if (user == null) return false;
  return user.canManageGoshenRegistrationTools;
}

String _joinFieldList(List<String> fields) {
  if (fields.isEmpty) return 'profile details';
  if (fields.length == 1) return fields.first;
  if (fields.length == 2) return '${fields.first} and ${fields.last}';
  return '${fields.take(fields.length - 1).join(', ')}, and ${fields.last}';
}

class _MyGoshenRegistrations extends StatefulWidget {
  const _MyGoshenRegistrations({
    super.key,
    required this.colors,
    required this.refreshVersion,
    this.showEmptyState = false,
    this.margin = const EdgeInsets.only(top: 18),
  });

  final _GoshenPalette colors;
  final int refreshVersion;
  final bool showEmptyState;
  final EdgeInsetsGeometry margin;

  @override
  State<_MyGoshenRegistrations> createState() => _MyGoshenRegistrationsState();
}

class _MyGoshenRegistrationsState extends State<_MyGoshenRegistrations> {
  late Future<_RegistrationSnapshot> _future;
  bool _convertingReferral = false;

  @override
  void initState() {
    super.initState();
    _future = _initialSnapshotFuture();
  }

  @override
  void didUpdateWidget(covariant _MyGoshenRegistrations oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) {
      _future = _load();
    }
  }

  Future<_RegistrationSnapshot> _load() async {
    final user = await SQLiteDbProvider.db.getUserData();
    if (user == null || (user.apiToken ?? '').trim().isEmpty) {
      return const _RegistrationSnapshot.signedOut();
    }

    final data = await GoshenRetreatApi().fetchMyRetreatData(user);
    return _RegistrationSnapshot(
      user: user,
      registrations: data.registrations,
      accommodationAllocations: data.accommodationAllocations,
      givingHistory: data.givingHistory,
      referralSummary: data.referralSummary,
      referralPoints: data.referralPoints,
    );
  }

  Future<_RegistrationSnapshot> _initialSnapshotFuture() async {
    final user = await SQLiteDbProvider.db.getUserData();
    if (user == null || (user.apiToken ?? '').trim().isEmpty) {
      return const _RegistrationSnapshot.signedOut();
    }

    final data = GoshenRetreatApi().cachedMyRetreatData(user);
    if (data == null) return _load();

    WidgetsBinding.instance.addPostFrameCallback((_) => _reload(silent: true));
    return _RegistrationSnapshot(
      user: user,
      registrations: data.registrations,
      accommodationAllocations: data.accommodationAllocations,
      givingHistory: data.givingHistory,
      referralSummary: data.referralSummary,
      referralPoints: data.referralPoints,
    );
  }

  Future<void> _reload({bool silent = false}) async {
    final next = _load();
    if (!silent) {
      setState(() {
        _future = next;
      });
    }
    try {
      final snapshot = await next;
      if (mounted && silent) {
        setState(() {
          _future = Future.value(snapshot);
        });
      }
    } catch (_) {
      if (!silent) rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return FutureBuilder<_RegistrationSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.showEmptyState
              ? _stateCard(
                  _RegistrationInlineState(
                    icon: Icons.hourglass_top_rounded,
                    title: 'Loading your registration',
                    message:
                        'Please wait while we load your bookings, tickets, and referral rewards.',
                    colors: colors,
                    loading: true,
                  ),
                )
              : const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return widget.showEmptyState
              ? _stateCard(
                  _RegistrationInlineState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load registration',
                    message: snapshot.error
                            ?.toString()
                            .replaceFirst('Exception: ', '') ??
                        'Please check your connection and try again.',
                    colors: colors,
                    action: FilledButton.icon(
                      style: _goldButtonStyle(),
                      onPressed: () => _reload(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ),
                )
              : const SizedBox.shrink();
        }

        final data = snapshot.data ?? const _RegistrationSnapshot.signedOut();
        final hasRetreatData = data.registrations.isNotEmpty ||
            data.accommodationAllocations.isNotEmpty ||
            data.givingHistory.isNotEmpty ||
            data.referralSummary.hasContent ||
            data.referralPoints.isNotEmpty;
        if (data.user == null) {
          return widget.showEmptyState
              ? _stateCard(
                  _RegistrationInlineState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Sign in to view registration',
                    message:
                        'Your Goshen bookings, tickets, accommodation, giving history, and referral rewards are linked to your member account.',
                    colors: colors,
                    action: FilledButton.icon(
                      style: _goldButtonStyle(),
                      onPressed: () =>
                          Navigator.pushNamed(context, LoginScreen.routeName),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Sign in'),
                    ),
                  ),
                )
              : const SizedBox.shrink();
        }

        if (!hasRetreatData) {
          return widget.showEmptyState
              ? _stateCard(
                  _RegistrationInlineState(
                    icon: Icons.confirmation_number_outlined,
                    title: 'No registration yet',
                    message:
                        'Your bookings, tickets, accommodation, giving history, and referral rewards will appear here after registration activity starts.',
                    colors: colors,
                    action: FilledButton.icon(
                      style: _goldButtonStyle(),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        GoshenRetreatScreen.routeName,
                      ),
                      icon: const Icon(Icons.event_available_rounded),
                      label: const Text('Open retreat page'),
                    ),
                  ),
                )
              : const SizedBox.shrink();
        }

        return Padding(
          padding: widget.margin,
          child: _SectionCard(
            title: 'My Registration',
            icon: Icons.confirmation_number_rounded,
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MemberRetreatOverview(
                  user: data.user!,
                  registrations: data.registrations,
                  accommodations: data.accommodationAllocations,
                  givingHistory: data.givingHistory,
                  referralSummary: data.referralSummary,
                  referralPoints: data.referralPoints,
                  colors: colors,
                ),
                if (data.referralSummary.hasContent ||
                    data.referralPoints.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ReferralSummaryCard(
                    summary: data.referralSummary,
                    points: data.referralPoints,
                    colors: colors,
                    converting: _convertingReferral,
                    onConvert: () => _convertReferralPoints(data.user!),
                  ),
                ],
                const SizedBox(height: 12),
                if (data.accommodationAllocations.isNotEmpty) ...[
                  _HistoryGroupHeader(
                    icon: Icons.home_work_outlined,
                    title: 'Accommodation',
                    colors: colors,
                  ),
                  const SizedBox(height: 8),
                  ...data.accommodationAllocations.map(
                    (allocation) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AccommodationAllocationCard(
                        allocation: allocation,
                        colors: colors,
                      ),
                    ),
                  ),
                ],
                if (data.registrations.isNotEmpty) ...[
                  _HistoryGroupHeader(
                    icon: Icons.receipt_long_rounded,
                    title: 'Registration history',
                    colors: colors,
                  ),
                  const SizedBox(height: 8),
                  ...data.registrations.map(
                    (registration) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RegistrationCard(
                        registration: registration,
                        user: data.user!,
                        colors: colors,
                        onRefresh: _reload,
                      ),
                    ),
                  ),
                ],
                if (data.givingHistory.isNotEmpty) ...[
                  _HistoryGroupHeader(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'Giving history',
                    colors: colors,
                  ),
                  const SizedBox(height: 8),
                  ...data.givingHistory.map(
                    (gift) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GivingHistoryCard(gift: gift, colors: colors),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stateCard(Widget child) {
    return Padding(
      padding: widget.margin,
      child: _SectionCard(
        title: 'My Registration',
        icon: Icons.confirmation_number_rounded,
        colors: widget.colors,
        child: child,
      ),
    );
  }

  ButtonStyle _goldButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: const Color(0xFFFFB522),
      foregroundColor: const Color(0xFF0C2230),
      minimumSize: const Size.fromHeight(48),
      textStyle: const TextStyle(fontWeight: FontWeight.w900),
    );
  }

  Future<void> _convertReferralPoints(Userdata user) async {
    if (_convertingReferral) return;

    setState(() => _convertingReferral = true);
    try {
      final data = await GoshenRetreatApi().convertReferralPointsToWallet(user);
      if (!mounted) return;
      final next = _RegistrationSnapshot(
        user: user,
        registrations: data.registrations,
        accommodationAllocations: data.accommodationAllocations,
        givingHistory: data.givingHistory,
        referralSummary: data.referralSummary,
        referralPoints: data.referralPoints,
      );
      setState(() {
        _future = Future.value(next);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Referral points converted to wallet funds.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _convertingReferral = false);
    }
  }
}

class _RegistrationInlineState extends StatelessWidget {
  const _RegistrationInlineState({
    required this.icon,
    required this.title,
    required this.message,
    required this.colors,
    this.action,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final _GoshenPalette colors;
  final Widget? action;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB522).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Icon(icon, color: const Color(0xFFE1A63B), size: 32),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.muted,
            fontSize: 13,
            height: 1.38,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          action!,
        ],
      ],
    );
  }
}

class _RegistrationSnapshot {
  const _RegistrationSnapshot({
    required this.user,
    required this.registrations,
    required this.accommodationAllocations,
    required this.givingHistory,
    required this.referralSummary,
    required this.referralPoints,
  });

  const _RegistrationSnapshot.signedOut()
      : user = null,
        registrations = const [],
        accommodationAllocations = const [],
        givingHistory = const [],
        referralSummary = const GoshenReferralSummary.empty(),
        referralPoints = const [];

  final Userdata? user;
  final List<GoshenRegistration> registrations;
  final List<GoshenAccommodationAllocation> accommodationAllocations;
  final List<GoshenGivingRecord> givingHistory;
  final GoshenReferralSummary referralSummary;
  final List<GoshenReferralPointEntry> referralPoints;
}

class _MemberRetreatOverview extends StatelessWidget {
  const _MemberRetreatOverview({
    required this.user,
    required this.registrations,
    required this.accommodations,
    required this.givingHistory,
    required this.referralSummary,
    required this.referralPoints,
    required this.colors,
  });

  final Userdata user;
  final List<GoshenRegistration> registrations;
  final List<GoshenAccommodationAllocation> accommodations;
  final List<GoshenGivingRecord> givingHistory;
  final GoshenReferralSummary referralSummary;
  final List<GoshenReferralPointEntry> referralPoints;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    final countedRegistrations =
        registrations.where((registration) => registration.countsInSummary);
    final paid = registrations.fold<double>(
      0,
      (sum, registration) =>
          registration.countsInSummary ? sum + registration.paidTotal : sum,
    );
    final total = countedRegistrations.fold<double>(
      0,
      (sum, registration) => sum + registration.total,
    );
    final tickets = countedRegistrations.fold<int>(
      0,
      (sum, registration) => sum + registration.tickets.length,
    );
    final currency = countedRegistrations
        .map((registration) => registration.currency.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final progress = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);
    final name = (user.name ?? '').trim().isEmpty
        ? 'Goshen member'
        : (user.name ?? '').trim();
    final email = (user.email ?? '').trim();
    final referralPointTotal = referralSummary.totalPoints > 0
        ? referralSummary.totalPoints
        : referralPoints.fold<int>(0, (sum, entry) => sum + entry.points);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: colors.isDark
            ? const LinearGradient(
                colors: [Color(0xFF0B202B), Color(0xFF123E36)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFFBFEFF), Color(0xFFEFF8F2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2230),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFFFB522),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email.isEmpty ? 'Signed in Goshen profile' : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: 'Member', colors: colors),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: colors.border,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB522)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            total <= 0
                ? 'Payment activity will appear after registration.'
                : '${currency.isEmpty ? '' : '$currency '}${_formatScreenMoney(paid)} paid of ${currency.isEmpty ? '' : '$currency '}${_formatScreenMoney(total)}',
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniMetric(
                icon: Icons.event_available_rounded,
                label: 'Bookings',
                value: '${countedRegistrations.length}',
                colors: colors,
              ),
              _MiniMetric(
                icon: Icons.confirmation_number_outlined,
                label: 'Tickets',
                value: '$tickets',
                colors: colors,
              ),
              _MiniMetric(
                icon: Icons.home_work_outlined,
                label: 'Rooms',
                value: '${accommodations.length}',
                colors: colors,
              ),
              if (givingHistory.isNotEmpty)
                _MiniMetric(
                  icon: Icons.volunteer_activism_outlined,
                  label: 'Gifts',
                  value: '${givingHistory.length}',
                  colors: colors,
                ),
              if (referralSummary.hasContent || referralPoints.isNotEmpty)
                _MiniMetric(
                  icon: Icons.group_add_outlined,
                  label: 'Referral pts',
                  value: '$referralPointTotal',
                  colors: colors,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReferralSummaryCard extends StatelessWidget {
  const _ReferralSummaryCard({
    required this.summary,
    required this.points,
    required this.colors,
    required this.converting,
    required this.onConvert,
  });

  final GoshenReferralSummary summary;
  final List<GoshenReferralPointEntry> points;
  final _GoshenPalette colors;
  final bool converting;
  final VoidCallback? onConvert;

  @override
  Widget build(BuildContext context) {
    final code = summary.code.trim();
    final canConvert = summary.canConvert && onConvert != null && !converting;
    final conversionHint = summary.conversionMessage.trim().isNotEmpty
        ? summary.conversionMessage.trim()
        : summary.availablePoints > 0
            ? 'Validated referral points can be converted to wallet funds when the backend conversion endpoint is available.'
            : 'Validated referral points will become wallet-convertible when eligible registrations are confirmed.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB522).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFB522).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2230),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: Color(0xFFFFB522),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Referral rewards',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      summary.availablePointsLabel,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: summary.canConvert ? 'Ready' : 'Tracking',
                colors: colors,
              ),
            ],
          ),
          if (code.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.badge_outlined,
                      color: const Color(0xFFE1A63B), size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your referral code',
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          code,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy referral code',
                    onPressed: () => _copyReferralCode(context, code),
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniMetric(
                icon: Icons.stars_outlined,
                label: 'Total',
                value: '${summary.totalPoints}',
                colors: colors,
              ),
              _MiniMetric(
                icon: Icons.pending_actions_outlined,
                label: 'Pending',
                value: '${summary.pendingPoints}',
                colors: colors,
              ),
              _MiniMetric(
                icon: Icons.verified_outlined,
                label: 'Validated',
                value: '${summary.validatedPoints}',
                colors: colors,
              ),
              _MiniMetric(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Wallet ready',
                value: '${summary.availablePoints}',
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            conversionHint,
            style: TextStyle(color: colors.muted, height: 1.35, fontSize: 12),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB522),
              foregroundColor: const Color(0xFF0C2230),
              minimumSize: const Size.fromHeight(46),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: canConvert ? onConvert : null,
            icon: converting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.account_balance_wallet_rounded),
            label: Text(
              converting
                  ? 'Converting...'
                  : summary.walletAmount > 0
                      ? 'Convert ${summary.walletAmountLabel}'
                      : 'Convert to wallet',
            ),
          ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 14),
            _HistoryGroupHeader(
              icon: Icons.list_alt_outlined,
              title: 'Referral point entries',
              colors: colors,
            ),
            const SizedBox(height: 8),
            ...points.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ReferralPointEntryRow(
                  entry: entry,
                  colors: colors,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReferralPointEntryRow extends StatelessWidget {
  const _ReferralPointEntryRow({
    required this.entry,
    required this.colors,
  });

  final GoshenReferralPointEntry entry;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(label: entry.statusLabel, colors: colors),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniMetric(
                icon: Icons.stars_outlined,
                label: 'Points',
                value: entry.pointsLabel,
                colors: colors,
              ),
              _MiniMetric(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: entry.dateLabel,
                colors: colors,
              ),
              if (entry.amountLabel.isNotEmpty)
                _MiniMetric(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Wallet',
                  value: entry.amountLabel,
                  colors: colors,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryGroupHeader extends StatelessWidget {
  const _HistoryGroupHeader({
    required this.icon,
    required this.title,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFE1A63B)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _GivingHistoryCard extends StatelessWidget {
  const _GivingHistoryCard({required this.gift, required this.colors});

  final GoshenGivingRecord gift;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB522).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFB522).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2230),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  color: Color(0xFFFFB522),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gift.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      gift.dateLabel,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: gift.statusLabel, colors: colors),
            ],
          ),
          const SizedBox(height: 12),
          _TicketMetaRow(
            icon: Icons.payments_outlined,
            label: 'Amount',
            value: gift.amountLabel,
            colors: colors,
          ),
          if (gift.paymentMethod.trim().isNotEmpty)
            _TicketMetaRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Method',
              value: gift.paymentMethod,
              colors: colors,
            ),
          if (gift.reference.trim().isNotEmpty)
            _TicketMetaRow(
              icon: Icons.tag_rounded,
              label: 'Reference',
              value: gift.reference,
              colors: colors,
            ),
          if (gift.anonymous)
            _TicketMetaRow(
              icon: Icons.visibility_off_outlined,
              label: 'Visibility',
              value: 'Anonymous gift',
              colors: colors,
            ),
        ],
      ),
    );
  }
}

class _AccommodationAllocationCard extends StatelessWidget {
  const _AccommodationAllocationCard({
    required this.allocation,
    required this.colors,
  });

  final GoshenAccommodationAllocation allocation;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    final extraDetails = allocation.attendeeVisibleDetails.entries
        .where((entry) => '${entry.value}'.trim().isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14513F).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF14513F).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF14513F),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.home_work_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accommodation assigned',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      allocation.eventName,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: allocation.statusLabel, colors: colors),
            ],
          ),
          const SizedBox(height: 12),
          _TicketMetaRow(
            icon: Icons.person_outline_rounded,
            label: 'Attendee',
            value: allocation.attendeeName.isEmpty
                ? 'Registered attendee'
                : allocation.attendeeName,
            colors: colors,
          ),
          _TicketMetaRow(
            icon: Icons.location_city_rounded,
            label: 'Location',
            value: allocation.locationLabel,
            colors: colors,
          ),
          if (allocation.ticketNumber.isNotEmpty)
            _TicketMetaRow(
              icon: Icons.confirmation_number_outlined,
              label: 'Ticket',
              value: allocation.ticketNumber,
              colors: colors,
            ),
          if (allocation.checkInNote.isNotEmpty)
            _TicketMetaRow(
              icon: Icons.info_outline_rounded,
              label: 'Check-in note',
              value: allocation.checkInNote,
              colors: colors,
            ),
          if (extraDetails.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...extraDetails.map(
              (entry) => _TicketMetaRow(
                icon: Icons.notes_rounded,
                label: entry.key.replaceAll('_', ' '),
                value: '${entry.value}',
                colors: colors,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GoshenScannerScreen extends StatefulWidget {
  const GoshenScannerScreen({super.key, required this.user});

  final Userdata user;

  @override
  State<GoshenScannerScreen> createState() => _GoshenScannerScreenState();
}

class _GoshenScannerScreenState extends State<GoshenScannerScreen> {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _manifestMaxAge = Duration(hours: 24);

  final TextEditingController _codeController = TextEditingController();
  late Future<GoshenScannerStats?> _statsFuture;
  GoshenScannerTicket? _ticket;
  List<GoshenScannerTicket> _cachedManifest = const [];
  List<GoshenOfflineCheckIn> _offlineQueue = const [];
  List<GoshenScannerTicket> _searchResults = const [];
  DateTime? _manifestSavedAt;
  DateTime? _manifestExpiresAt;
  int _dayNumber = 1;
  String _lookupMode = 'ticket';
  String _scannerMode = 'auto';
  GoshenScannerStatus? _scannerStatus;
  String? _scannerStatusError;
  bool _loading = false;
  bool _checkingIn = false;
  bool _manifestLoading = false;
  bool _syncingOffline = false;
  bool _scannerStatusLoading = true;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
    final cachedStatus = GoshenRetreatApi().cachedScannerStatus(widget.user);
    if (cachedStatus != null) {
      _scannerStatus = cachedStatus;
      _scannerStatusLoading = false;
    }
    _loadScannerStatus();
    _loadScannerMode();
    _loadCachedManifest();
    _loadOfflineQueue();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<GoshenScannerStats?> _loadStats() async {
    final api = GoshenRetreatApi();
    final events = api.cachedEvents ?? await api.fetchEvents();
    if (events.isEmpty) return null;

    return api.fetchScannerStats(
      user: widget.user,
      event: events.first,
    );
  }

  Future<void> _loadScannerStatus() async {
    setState(() {
      _scannerStatusLoading = true;
      _scannerStatusError = null;
    });
    try {
      final status = await GoshenRetreatApi().fetchScannerStatus(widget.user);
      if (!mounted) return;
      setState(() => _scannerStatus = status);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scannerStatus = null;
        _scannerStatusError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _scannerStatusLoading = false);
    }
  }

  bool get _scannerSuspended => _scannerStatus?.scannerSuspended == true;

  bool get _scannerGloballyDisabled =>
      _scannerStatus != null && _scannerStatus?.scannerEnabled != true;

  bool get _scannerActionsDisabled =>
      _scannerStatusLoading ||
      _scannerSuspended ||
      _scannerGloballyDisabled ||
      _scannerStatusError != null;

  String get _scannerBlockedTitle {
    if (_scannerStatusLoading) return 'Checking scanner access';
    if (_scannerSuspended) return 'Scanning suspended';
    if (_scannerGloballyDisabled) return 'Scanner is unavailable';
    return 'Scanner access unavailable';
  }

  String get _scannerBlockedMessage {
    if (_scannerStatusLoading) {
      return 'Please wait while your scanner access is verified.';
    }
    if (_scannerSuspended) {
      final reason = _scannerStatus?.scannerSuspensionReason.trim() ?? '';
      return reason.isEmpty
          ? 'Your scanner console is still visible, but ticket lookup, QR scanning, cache downloads, and check-in actions are paused by an admin.'
          : 'Your scanner console is still visible, but ticket lookup, QR scanning, cache downloads, and check-in actions are paused by an admin.\n\nReason: $reason';
    }
    if (_scannerGloballyDisabled) {
      return 'Ticket scanning is currently turned off by the admin team.';
    }
    return _scannerStatusError ??
        'Unable to confirm scanner access. Please check your connection and try again.';
  }

  Future<bool> _ensureScannerCanAct() async {
    if (!_scannerActionsDisabled) return true;
    await _showGoshenDialog(
      context,
      title: _scannerBlockedTitle,
      message: _scannerBlockedMessage,
    );
    return false;
  }

  String get _manifestPrefsKey =>
      'goshen_scanner_manifest_${widget.user.email ?? 'scanner'}';

  String get _offlineQueuePrefsKey =>
      'goshen_scanner_queue_${widget.user.email ?? 'scanner'}';

  String get _scannerModePrefsKey =>
      'goshen_scanner_mode_${widget.user.email ?? 'scanner'}';

  bool get _hasScannerCache =>
      _cachedManifest.isNotEmpty || _manifestSavedAt != null;

  bool get _manifestExpired {
    final savedAt = _manifestSavedAt;
    final expiresAt = _manifestExpiresAt;
    if (expiresAt != null) {
      return DateTime.now().isAfter(expiresAt);
    }
    if (savedAt == null) return false;
    return DateTime.now().difference(savedAt) > _manifestMaxAge;
  }

  Future<void> _loadScannerMode() async {
    final saved = await _secureStorage.read(key: _scannerModePrefsKey);
    if (!mounted) return;
    if (saved == 'auto' || saved == 'online' || saved == 'offline') {
      setState(() => _scannerMode = saved!);
    }
  }

  Future<void> _setScannerMode(String mode) async {
    if (mode != 'auto' && mode != 'online' && mode != 'offline') return;
    await _secureStorage.write(key: _scannerModePrefsKey, value: mode);
    if (!mounted) return;
    setState(() => _scannerMode = mode);
  }

  Future<void> _loadCachedManifest() async {
    final raw = await _secureStorage.read(key: _manifestPrefsKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final savedAt = DateTime.tryParse('${decoded['saved_at'] ?? ''}');
      final expiresAt = DateTime.tryParse('${decoded['expires_at'] ?? ''}');
      final tickets = ((decoded['tickets'] as List?) ?? const [])
          .map((item) =>
              GoshenScannerTicket.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (!mounted) return;
      setState(() {
        _cachedManifest = tickets;
        _manifestSavedAt = savedAt?.toLocal();
        _manifestExpiresAt = expiresAt?.toLocal();
      });
    } catch (_) {
      await _secureStorage.delete(key: _manifestPrefsKey);
    }
  }

  Future<void> _loadOfflineQueue() async {
    final raw = await _secureStorage.read(key: _offlineQueuePrefsKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final items = decoded
          .map((item) =>
              GoshenOfflineCheckIn.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.identifier.trim().isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() => _offlineQueue = items);
    } catch (_) {
      await _secureStorage.delete(key: _offlineQueuePrefsKey);
    }
  }

  Future<void> _saveOfflineQueue(List<GoshenOfflineCheckIn> items) async {
    await _secureStorage.write(
      key: _offlineQueuePrefsKey,
      value: jsonEncode(items.map((item) => item.toJson()).toList()),
    );
    if (!mounted) return;
    setState(() => _offlineQueue = items);
  }

  Future<void> _downloadManifest() async {
    if (!await _ensureScannerCanAct()) return;

    setState(() => _manifestLoading = true);
    try {
      final events = await GoshenRetreatApi().fetchEvents();
      if (events.isEmpty) {
        throw Exception(
            'No active retreat event is available for scanner cache.');
      }
      final manifest = await GoshenRetreatApi().fetchScannerManifestData(
        user: widget.user,
        event: events.first,
      );
      final tickets = manifest.tickets;
      final savedAt = manifest.generatedAt?.toLocal() ?? DateTime.now();
      final expiresAt = manifest.expiresAt?.toLocal() ??
          savedAt.add(Duration(
            seconds: manifest.ttlSeconds > 0
                ? manifest.ttlSeconds
                : _manifestMaxAge.inSeconds,
          ));
      await _secureStorage.write(
        key: _manifestPrefsKey,
        value: jsonEncode({
          'saved_at': savedAt.toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
          'ttl_seconds': manifest.ttlSeconds,
          'manifest_version': manifest.version,
          'tickets': tickets.map((ticket) => ticket.toJson()).toList(),
        }),
      );
      if (!mounted) return;
      setState(() {
        _cachedManifest = tickets;
        _manifestSavedAt = savedAt;
        _manifestExpiresAt = expiresAt;
      });
      await _showGoshenDialog(
        context,
        title: 'Scanner cache updated',
        message:
            '${tickets.length} ticket record(s) are now available for local lookup and offline queue mode. Refresh this cache within 24 hours of scanning.',
      );
    } catch (error) {
      if (!mounted) return;
      await _showGoshenDialog(
        context,
        title: 'Cache update failed',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _manifestLoading = false);
    }
  }

  GoshenScannerTicket? _findCachedTicket(String code) {
    if (_manifestExpired) return null;

    final normalized = code.toLowerCase().trim();
    if (normalized.isEmpty) return null;

    for (final ticket in _cachedManifest) {
      if (ticket.publicId.toLowerCase() == normalized ||
          ticket.ticketNumber.toLowerCase() == normalized) {
        return ticket;
      }
    }

    try {
      final decoded = jsonDecode(code);
      if (decoded is Map) {
        final ticketId = '${decoded['ticket'] ?? ''}'.toLowerCase();
        return _cachedManifest.firstWhere(
          (ticket) => ticket.publicId.toLowerCase() == ticketId,
        );
      }
    } catch (_) {
      // Plain ticket numbers are the normal manual fallback.
    }

    return null;
  }

  String _manifestLabel() {
    final savedAt = _manifestSavedAt;
    if (savedAt == null) return 'No local scanner cache yet';
    final hour = savedAt.hour % 12 == 0 ? 12 : savedAt.hour % 12;
    final minute = savedAt.minute.toString().padLeft(2, '0');
    final suffix = savedAt.hour >= 12 ? 'PM' : 'AM';
    final state = _manifestExpired ? 'expired' : 'ready';
    final expiresAt = _manifestExpiresAt;
    if (expiresAt == null) {
      return '${_cachedManifest.length} ticket(s), $state, updated $hour:$minute $suffix';
    }
    final expiryHour = expiresAt.hour % 12 == 0 ? 12 : expiresAt.hour % 12;
    final expiryMinute = expiresAt.minute.toString().padLeft(2, '0');
    final expirySuffix = expiresAt.hour >= 12 ? 'PM' : 'AM';
    return '${_cachedManifest.length} ticket(s), $state, expires $expiryHour:$expiryMinute $expirySuffix';
  }

  Future<bool> _ensureOfflineCacheReady() async {
    if (_manifestSavedAt == null || _cachedManifest.isEmpty) {
      await _showGoshenDialog(
        context,
        title: 'Offline cache required',
        message:
            'Download the scanner cache before using offline queue mode. This keeps offline check-in limited to known Goshen Retreat tickets.',
      );
      return false;
    }

    if (_manifestExpired) {
      await _showGoshenDialog(
        context,
        title: 'Scanner cache expired',
        message:
            'This offline scanner cache is more than 24 hours old. Please reconnect and download a fresh cache before saving offline check-ins.',
      );
      return false;
    }

    return true;
  }

  Future<void> _wipeScannerData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Wipe scanner data?'),
        content: Text(
          _offlineQueue.isEmpty
              ? 'This will remove the local scanner cache from this phone.'
              : 'This will remove the local scanner cache and ${_offlineQueue.length} pending offline check-in(s) from this phone. Only do this if the data is no longer needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Wipe data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _secureStorage.delete(key: _manifestPrefsKey);
    await _secureStorage.delete(key: _offlineQueuePrefsKey);
    if (!mounted) return;
    setState(() {
      _cachedManifest = const [];
      _offlineQueue = const [];
      _manifestSavedAt = null;
      _manifestExpiresAt = null;
      _ticket = null;
      _searchResults = const [];
    });
    await _showGoshenDialog(
      context,
      title: 'Scanner data wiped',
      message:
          'The local cache and pending offline queue have been removed from this phone.',
    );
  }

  Future<void> _scanQrCode() async {
    if (!await _ensureScannerCanAct()) return;

    while (mounted) {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const _GoshenQrScannerPage()),
      );
      final code = result?.trim() ?? '';
      if (code.isEmpty || !mounted) return;

      final continueScanning = await _processScannedQrCode(code);
      if (continueScanning != true || !mounted) return;
    }
  }

  Future<bool> _processScannedQrCode(String code) async {
    setState(() {
      _lookupMode = 'ticket';
      _loading = true;
      _checkingIn = true;
      _ticket = null;
      _searchResults = const [];
    });
    _codeController.text = code;

    try {
      if (_scannerMode == 'offline') {
        if (!await _ensureOfflineCacheReady()) return false;

        final cachedTicket = _findCachedTicket(code);
        if (cachedTicket == null) {
          await _showScanResult(
            title: 'Ticket not in cache',
            message:
                'This QR code is not available in the local scanner cache. Use online mode or refresh the cache.',
            success: false,
          );
          return mounted;
        }

        if (cachedTicket.days.isNotEmpty) {
          _dayNumber = cachedTicket.days.first.dayNumber;
        }
        setState(() => _ticket = cachedTicket);
        await _queueOfflineCheckIn(cachedTicket, code,
            showDialogOnSuccess: false);
        await _showScanResult(
          title: 'Saved for sync',
          message:
              '${cachedTicket.attendeeName} has been saved on this device. Sync pending check-ins when internet is available.',
        );
        return mounted;
      }

      final ticket = await GoshenRetreatApi().lookupTicket(
        user: widget.user,
        identifier: code,
      );
      if (!mounted) return false;

      if (ticket.days.isNotEmpty) {
        _dayNumber = ticket.days.first.dayNumber;
      }
      setState(() => _ticket = ticket);

      final result = await GoshenRetreatApi().checkInTicket(
        user: widget.user,
        identifier: code,
        dayNumber: _dayNumber,
      );
      if (!mounted) return false;

      final updated = result['data'] as GoshenScannerTicket;
      setState(() => _ticket = updated);

      await _showScanResult(
        title:
            result['duplicate'] == true ? 'Already checked in' : 'Checked in',
        message:
            '${updated.attendeeName} · ${result['message'] ?? 'Ticket check-in recorded.'}',
        success: result['duplicate'] != true,
      );
      return mounted;
    } catch (error) {
      if (!mounted) return false;

      await _showScanResult(
        title: 'Scan failed',
        message: error.toString().replaceFirst('Exception: ', ''),
        success: false,
      );
      return mounted;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _checkingIn = false;
        });
      }
    }
  }

  Future<void> _showScanResult({
    required String title,
    required String message,
    bool success = true,
  }) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 950),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            success ? const Color(0xFF14513F) : const Color(0xFF9F1D1D),
        content: Row(
          children: [
            Icon(
              success ? Icons.verified_rounded : Icons.warning_amber_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$title\n$message',
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 1050));
  }

  Future<void> _lookup() async {
    if (!await _ensureScannerCanAct()) return;

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      await _showGoshenDialog(
        context,
        title: 'Lookup text required',
        message: _lookupMode == 'ticket'
            ? 'Enter or paste the ticket number or QR payload first.'
            : 'Enter at least two characters or digits to search attendees.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (_lookupMode != 'ticket') {
        final matches = await GoshenRetreatApi().searchTickets(
          user: widget.user,
          query: code,
          lookupMode: _lookupMode,
        );
        if (!mounted) return;
        if (matches.length == 1) {
          _codeController.text = matches.first.publicId;
        }
        setState(() {
          _ticket = matches.length == 1 ? matches.first : null;
          _searchResults = matches;
          if (_ticket?.days.isNotEmpty == true) {
            _dayNumber = _ticket!.days.first.dayNumber;
          }
        });
        if (matches.isEmpty) {
          await _showGoshenDialog(
            context,
            title: 'No match found',
            message:
                'No Goshen Retreat ticket matched this ${_lookupMode == 'phone' ? 'phone search' : 'name search'}.',
          );
        }
        return;
      }

      final ticket = await GoshenRetreatApi().lookupTicket(
        user: widget.user,
        identifier: code,
      );
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _searchResults = const [];
        if (ticket.days.isNotEmpty) {
          _dayNumber = ticket.days.first.dayNumber;
        }
      });
    } catch (error) {
      if (!mounted) return;
      final cachedTicket = _findCachedTicket(code);
      if (cachedTicket != null) {
        setState(() {
          _ticket = cachedTicket;
          if (cachedTicket.days.isNotEmpty) {
            _dayNumber = cachedTicket.days.first.dayNumber;
          }
        });
        await _showGoshenDialog(
          context,
          title: 'Showing cached ticket',
          message:
              'Live lookup failed, so this ticket is shown from the local scanner cache. Connect to the internet before checking in.',
        );
        return;
      }

      setState(() => _ticket = null);
      await _showGoshenDialog(
        context,
        title: 'Ticket not found',
        message: _friendlyTicketLookupMessage(error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkIn() async {
    if (!await _ensureScannerCanAct()) return;

    final ticket = _ticket;
    final code = _codeController.text.trim();
    if (ticket == null || code.isEmpty) {
      await _showGoshenDialog(
        context,
        title: 'Lookup required',
        message: 'Please lookup a valid ticket before checking in.',
      );
      return;
    }

    setState(() => _checkingIn = true);
    try {
      if (_scannerMode == 'offline') {
        if (!await _ensureOfflineCacheReady()) return;
        await _queueOfflineCheckIn(ticket, code);
        return;
      }

      final result = await GoshenRetreatApi().checkInTicket(
        user: widget.user,
        identifier: code,
        dayNumber: _dayNumber,
      );
      if (!mounted) return;
      final updated = result['data'] as GoshenScannerTicket;
      setState(() => _ticket = updated);
      await _showGoshenDialog(
        context,
        title: result['duplicate'] == true
            ? 'Already checked in'
            : 'Check-in complete',
        message: '${result['message'] ?? 'Ticket check-in has been recorded.'}',
      );
    } catch (error) {
      if (!mounted) return;
      if (_scannerMode == 'online') {
        await _showGoshenDialog(
          context,
          title: 'Online check-in failed',
          message: _friendlyTicketLookupMessage(error),
        );
        return;
      }

      final shouldQueue = await _confirmOfflineQueue(
        _friendlyTicketLookupMessage(error),
      );
      if (shouldQueue == true) {
        if (!await _ensureOfflineCacheReady()) return;
        await _queueOfflineCheckIn(ticket, code);
      }
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Future<bool?> _confirmOfflineQueue(String errorMessage) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save for offline sync?'),
        content: Text(
          'Live check-in could not be completed right now.\n\n$errorMessage\n\nYou can save this check-in on this device and sync it when internet is available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save offline'),
          ),
        ],
      ),
    );
  }

  Future<void> _queueOfflineCheckIn(
    GoshenScannerTicket ticket,
    String identifier, {
    bool showDialogOnSuccess = true,
  }) async {
    final ineligible = ['cancelled', 'unpaid'].contains(ticket.status);
    if (ineligible) {
      await _showGoshenDialog(
        context,
        title: 'Cannot save offline',
        message: 'This ticket is not eligible for check-in.',
      );
      return;
    }

    final alreadyQueued = _offlineQueue.any((item) =>
        item.identifier == identifier && item.dayNumber == _dayNumber);
    if (alreadyQueued) {
      await _showGoshenDialog(
        context,
        title: 'Already saved',
        message: 'This ticket is already waiting for offline sync.',
      );
      return;
    }

    final item = GoshenOfflineCheckIn(
      localId: 'offline-${DateTime.now().microsecondsSinceEpoch}',
      identifier: identifier,
      dayNumber: _dayNumber,
      checkedInAt: DateTime.now(),
      attendeeName: ticket.attendeeName,
      ticketNumber: ticket.ticketNumber,
    );

    await _saveOfflineQueue([..._offlineQueue, item]);
    if (!mounted) return;
    if (!showDialogOnSuccess) return;

    await _showGoshenDialog(
      context,
      title: 'Saved offline',
      message:
          'This check-in is saved on this phone. Sync it when internet is available.',
    );
  }

  Future<void> _syncOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    if (!await _ensureScannerCanAct()) return;

    setState(() => _syncingOffline = true);
    try {
      final response = await GoshenRetreatApi().syncOfflineCheckIns(
        user: widget.user,
        items: _offlineQueue,
      );
      final results = ((response['results'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final syncedIds = results
          .where((item) => item['status'] == 'synced')
          .map((item) => '${item['local_id'] ?? ''}')
          .where((id) => id.isNotEmpty)
          .toSet();
      final remaining = _offlineQueue
          .where((item) => !syncedIds.contains(item.localId))
          .toList();
      await _saveOfflineQueue(remaining);
      if (!mounted) return;
      setState(() => _statsFuture = _loadStats());
      await _showGoshenDialog(
        context,
        title: 'Offline sync complete',
        message:
            '${response['synced'] ?? 0} synced, ${response['rejected'] ?? 0} rejected. ${remaining.length} item(s) remain on this phone.',
      );
    } catch (error) {
      if (!mounted) return;
      await _showGoshenDialog(
        context,
        title: 'Offline sync failed',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _syncingOffline = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _GoshenPalette.of(context);
    final ticket = _ticket;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Ticket scanner')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0C2230), Color(0xFF14513F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.qr_code_scanner_rounded,
                    color: Color(0xFFFFC857), size: 34),
                SizedBox(height: 14),
                Text(
                  'Goshen check-in',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Paste a ticket number or QR payload to verify the attendee before recording check-in.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_scannerStatusLoading ||
              _scannerActionsDisabled ||
              _scannerStatus?.managerAllowed == true) ...[
            _ScannerStatusNotice(
              title: _scannerBlockedTitle,
              message: _scannerStatus?.managerAllowed == true &&
                      !_scannerActionsDisabled
                  ? 'Your scanner console is active. Scanner managers can suspend or resume scanner devices from the More menu.'
                  : _scannerBlockedMessage,
              isBlocked: _scannerActionsDisabled,
              isLoading: _scannerStatusLoading,
              colors: colors,
              onRetry: _scannerStatusLoading ? null : _loadScannerStatus,
            ),
            const SizedBox(height: 16),
          ],
          _SectionCard(
            title: 'Offline readiness',
            icon: Icons.offline_bolt_outlined,
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _manifestLabel(),
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Download a minimal ticket manifest before the event. Offline cache expires after 24 hours and pending scans sync back to the server when internet returns.',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_manifestExpired) ...[
                  const SizedBox(height: 10),
                  _InlineNotice(
                    icon: Icons.warning_amber_rounded,
                    title: 'Cache expired',
                    message:
                        'This cache is expired. Download a fresh cache before using offline queue mode.',
                    colors: colors,
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (_manifestLoading || _scannerActionsDisabled)
                        ? null
                        : _downloadManifest,
                    icon: _manifestLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_for_offline_outlined),
                    label: Text(_manifestLoading
                        ? 'Updating scanner cache'
                        : 'Download scanner cache'),
                  ),
                ),
                if (_hasScannerCache || _offlineQueue.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _wipeScannerData,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Wipe local scanner data'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Scanner settings',
            icon: Icons.tune_rounded,
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose how this device should behave if internet is unstable.',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ScannerChoiceChip(
                      label: 'Auto',
                      selected: _scannerMode == 'auto',
                      colors: colors,
                      onSelected: () => _setScannerMode('auto'),
                    ),
                    _ScannerChoiceChip(
                      label: 'Online only',
                      selected: _scannerMode == 'online',
                      colors: colors,
                      onSelected: () => _setScannerMode('online'),
                    ),
                    _ScannerChoiceChip(
                      label: 'Offline queue',
                      selected: _scannerMode == 'offline',
                      colors: colors,
                      onSelected: () => _setScannerMode('offline'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_offlineQueue.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Pending offline check-ins',
              icon: Icons.sync_problem_rounded,
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_offlineQueue.length} check-in(s) waiting on this phone',
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._offlineQueue.take(3).map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${item.attendeeName.isEmpty ? item.ticketNumber : item.attendeeName} - Day ${item.dayNumber}',
                            style: TextStyle(
                              color: colors.muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  if (_offlineQueue.length > 3)
                    Text(
                      '+ ${_offlineQueue.length - 3} more',
                      style: TextStyle(
                        color: colors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_syncingOffline || _scannerActionsDisabled)
                          ? null
                          : _syncOfflineQueue,
                      icon: _syncingOffline
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_sync_rounded),
                      label: Text(_syncingOffline
                          ? 'Syncing check-ins'
                          : 'Sync pending check-ins'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          FutureBuilder<GoshenScannerStats?>(
            future: _statsFuture,
            builder: (context, snapshot) {
              final stats = snapshot.data;
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SectionCard(
                    title: 'Live retreat summary',
                    icon: Icons.analytics_outlined,
                    colors: colors,
                    child: LinearProgressIndicator(
                      backgroundColor: colors.innerCard,
                      color: const Color(0xFFFFB522),
                    ),
                  ),
                );
              }

              if (stats == null || snapshot.hasError) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ScannerStatsCard(stats: stats, colors: colors),
              );
            },
          ),
          _SectionCard(
            title: 'Lookup ticket',
            icon: Icons.confirmation_number_outlined,
            colors: colors,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ScannerChoiceChip(
                        label: 'Ticket',
                        selected: _lookupMode == 'ticket',
                        colors: colors,
                        onSelected: () => setState(() {
                          _lookupMode = 'ticket';
                          _ticket = null;
                          _searchResults = const [];
                        }),
                      ),
                      _ScannerChoiceChip(
                        label: 'Name',
                        selected: _lookupMode == 'name',
                        colors: colors,
                        onSelected: () => setState(() {
                          _lookupMode = 'name';
                          _ticket = null;
                          _searchResults = const [];
                        }),
                      ),
                      _ScannerChoiceChip(
                        label: 'Phone',
                        selected: _lookupMode == 'phone',
                        colors: colors,
                        onSelected: () => setState(() {
                          _lookupMode = 'phone';
                          _ticket = null;
                          _searchResults = const [];
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  minLines: 1,
                  maxLines: 3,
                  style: TextStyle(color: colors.text),
                  decoration: InputDecoration(
                    hintText: _lookupMode == 'ticket'
                        ? 'Ticket number, QR payload, or last 4 digits'
                        : _lookupMode == 'phone'
                            ? 'Search by attendee phone digits'
                            : 'Search by attendee name',
                    prefixIcon: Icon(_lookupMode == 'ticket'
                        ? Icons.qr_code_2_rounded
                        : _lookupMode == 'phone'
                            ? Icons.phone_outlined
                            : Icons.person_search_outlined),
                    filled: true,
                    fillColor: colors.innerCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                ),
                if (_searchResults.length > 1) ...[
                  const SizedBox(height: 12),
                  ..._searchResults.map(
                    (match) => _ScannerMatchTile(
                      ticket: match,
                      colors: colors,
                      onTap: () {
                        _codeController.text = match.publicId;
                        setState(() {
                          _ticket = match;
                          _lookupMode = 'ticket';
                          _searchResults = const [];
                          if (match.days.isNotEmpty) {
                            _dayNumber = match.days.first.dayNumber;
                          }
                        });
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_lookupMode == 'ticket') ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_loading || _scannerActionsDisabled)
                              ? null
                              : _scanQrCode,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Scan QR'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_loading || _scannerActionsDisabled)
                            ? null
                            : _lookup,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search_rounded),
                        label: Text(
                          _loading
                              ? 'Checking'
                              : _lookupMode == 'ticket'
                                  ? 'Lookup'
                                  : 'Search',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (ticket != null) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Ticket details',
              icon: Icons.verified_user_outlined,
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TicketMetaRow(
                    icon: Icons.badge_outlined,
                    label: 'Attendee',
                    value: ticket.attendeeName.isEmpty
                        ? 'Unnamed attendee'
                        : ticket.attendeeName,
                    colors: colors,
                  ),
                  _TicketMetaRow(
                    icon: Icons.event_available_outlined,
                    label: 'Event',
                    value: ticket.eventName,
                    colors: colors,
                  ),
                  _TicketMetaRow(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Ticket',
                    value: ticket.ticketNumber,
                    colors: colors,
                  ),
                  _TicketMetaRow(
                    icon: Icons.flag_outlined,
                    label: 'Status',
                    value: ticket.status.replaceAll('_', ' '),
                    colors: colors,
                  ),
                  const SizedBox(height: 10),
                  if (ticket.days.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: _dayNumber,
                      decoration: InputDecoration(
                        labelText: 'Check-in day',
                        filled: true,
                        fillColor: colors.innerCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: ticket.days
                          .map(
                            (day) => DropdownMenuItem<int>(
                              value: day.dayNumber,
                              child: Text(
                                day.title.isEmpty
                                    ? 'Day ${day.dayNumber}'
                                    : day.title,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _dayNumber = value);
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB522),
                        foregroundColor: const Color(0xFF0C2230),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: (_checkingIn || _scannerActionsDisabled)
                          ? null
                          : _checkIn,
                      icon: _checkingIn
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded),
                      label:
                          Text(_checkingIn ? 'Recording check-in' : 'Check in'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoshenQrScannerPage extends StatefulWidget {
  const _GoshenQrScannerPage();

  @override
  State<_GoshenQrScannerPage> createState() => _GoshenQrScannerPageState();
}

class _GoshenQrScannerPageState extends State<_GoshenQrScannerPage> {
  bool _handled = false;

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (value.isEmpty) return;

    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Goshen ticket'),
        backgroundColor: const Color(0xFF071720),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleCapture),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.78),
                    ],
                    stops: const [0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFFFB522), width: 3),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0C2230).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Text(
                'Place the Goshen Retreat QR code inside the frame. Valid tickets check in automatically and the scanner gets ready for the next attendee.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerStatusNotice extends StatelessWidget {
  const _ScannerStatusNotice({
    required this.title,
    required this.message,
    required this.isBlocked,
    required this.isLoading,
    required this.colors,
    this.onRetry,
  });

  final String title;
  final String message;
  final bool isBlocked;
  final bool isLoading;
  final _GoshenPalette colors;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final accent =
        isBlocked ? const Color(0xFFE24C4B) : const Color(0xFF2C9B88);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(13),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: accent,
                    ),
                  )
                : Icon(
                    isBlocked
                        ? Icons.pause_circle_filled_rounded
                        : Icons.verified_user_rounded,
                    color: accent,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: TextStyle(
                    color: colors.muted,
                    height: 1.35,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      onRetry?.call();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh access'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerChoiceChip extends StatelessWidget {
  const _ScannerChoiceChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final _GoshenPalette colors;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: const Color(0xFFFFB522),
      backgroundColor: colors.innerCard,
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF0C2230) : colors.text,
        fontWeight: FontWeight.w900,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
            color: selected ? const Color(0xFFFFB522) : colors.border),
      ),
    );
  }
}

class _ScannerMatchTile extends StatelessWidget {
  const _ScannerMatchTile({
    required this.ticket,
    required this.colors,
    required this.onTap,
  });

  final GoshenScannerTicket ticket;
  final _GoshenPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = ticket.attendeeName.trim().isEmpty
        ? 'Unnamed attendee'
        : ticket.attendeeName.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.innerCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB522).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.confirmation_number_outlined,
                    color: const Color(0xFF0C2230),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (ticket.ticketNumber.isNotEmpty)
                            ticket.ticketNumber,
                          if (ticket.ticketType.isNotEmpty) ticket.ticketType,
                          if (ticket.status.isNotEmpty)
                            ticket.status.replaceAll('_', ' '),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerStatsCard extends StatelessWidget {
  const _ScannerStatsCard({required this.stats, required this.colors});

  final GoshenScannerStats stats;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Live retreat summary',
      icon: Icons.analytics_outlined,
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stats.eventName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ScannerStatNumber(
                  label: 'Registered',
                  value: stats.registered,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScannerStatNumber(
                  label: 'Checked in',
                  value: stats.checkedIn,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScannerStatNumber(
                  label: 'Waiting',
                  value: stats.notYetCheckedIn,
                  colors: colors,
                ),
              ),
            ],
          ),
          if (stats.genderBreakdown.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ScannerBreakdownList(
              title: 'Gender',
              rows: stats.genderBreakdown,
              colors: colors,
            ),
          ],
          if (stats.ageGroupBreakdown.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ScannerBreakdownList(
              title: 'Age groups',
              rows: stats.ageGroupBreakdown,
              colors: colors,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScannerStatNumber extends StatelessWidget {
  const _ScannerStatNumber({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final int value;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.innerCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: colors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerBreakdownList extends StatelessWidget {
  const _ScannerBreakdownList({
    required this.title,
    required this.rows,
    required this.colors,
  });

  final String title;
  final List<GoshenScannerStatsRow> rows;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ...rows.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: TextStyle(
                      color: colors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${row.checkedIn}/${row.registered} in',
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RegistrationCard extends StatelessWidget {
  const _RegistrationCard({
    required this.registration,
    required this.user,
    required this.colors,
    required this.onRefresh,
  });

  final GoshenRegistration registration;
  final Userdata user;
  final _GoshenPalette colors;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final nextPayment = registration.installments
        .where((item) => !item.isPaid)
        .cast<GoshenInstallment?>()
        .firstWhere((item) => item != null, orElse: () => null);
    final payablePayment = registration.canPay ? nextPayment : null;
    final canUseWallet = registration.canPay &&
        !registration.isCancelled &&
        registration.balanceTotal > 0;
    final issuedQrCount = registration.tickets
        .where((ticket) => ticket.qrEncoded.trim().isNotEmpty)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.innerCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  registration.eventName,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusPill(label: registration.statusLabel, colors: colors),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Registered ${registration.createdLabel}',
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: registration.paymentProgress,
              minHeight: 8,
              backgroundColor: colors.card,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF14513F)),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniMetric(
                icon: Icons.payments_outlined,
                label: 'Total',
                value: registration.totalLabel,
                colors: colors,
              ),
              _MiniMetric(
                icon: Icons.verified_outlined,
                label: 'Paid',
                value: registration.paidLabel,
                colors: colors,
              ),
              _MiniMetric(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Balance',
                value: registration.balanceLabel,
                colors: colors,
              ),
              _MiniMetric(
                icon: Icons.groups_2_outlined,
                label: 'Attendees',
                value: '${registration.attendees.length}',
                colors: colors,
              ),
              _MiniMetric(
                icon: Icons.qr_code_2_rounded,
                label: 'QR',
                value: '$issuedQrCount/${registration.tickets.length}',
                colors: colors,
              ),
              if (payablePayment != null)
                _MiniMetric(
                  icon: Icons.schedule_rounded,
                  label: 'Due now',
                  value: payablePayment.amountLabel,
                  colors: colors,
                ),
              if (registration.canCancel)
                _MiniMetric(
                  icon: Icons.hourglass_bottom_rounded,
                  label: 'Pay before',
                  value: registration.paymentExpiryLabel,
                  colors: colors,
                ),
            ],
          ),
          if (registration.isCancelled &&
              registration.cancellationReason.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE53935).withValues(alpha: 0.16),
                ),
              ),
              child: Text(
                registration.cancellationReason.trim(),
                style: TextStyle(
                  color: colors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (registration.lines.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              registration.lines
                  .map((line) => '${line.quantity} x ${line.ticketType}')
                  .join(', '),
              style: TextStyle(
                color: colors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (registration.attendees.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: registration.attendees
                  .map(
                    (attendee) => _AttendeeSnapshotChip(
                      attendee: attendee,
                      colors: colors,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (registration.schedules.isNotEmpty) ...[
            const SizedBox(height: 14),
            _RegistrationSubsectionTitle(
              icon: Icons.schedule_rounded,
              title: 'Goshen Schedule Sessions',
              colors: colors,
            ),
            const SizedBox(height: 8),
            ...registration.schedules.map(
              (schedule) => _ScheduleRow(schedule: schedule, colors: colors),
            ),
          ],
          if (registration.installments.isNotEmpty ||
              registration.payments.isNotEmpty) ...[
            const SizedBox(height: 14),
            _RegistrationSubsectionTitle(
              icon: Icons.payments_outlined,
              title: 'Payment history',
              colors: colors,
            ),
            const SizedBox(height: 8),
            if (registration.installments.isNotEmpty)
              ...registration.installments.map(
                (installment) => _PaymentRecordHistoryRow(
                  installment: installment,
                  colors: colors,
                  onPayNow: installment.isPaid || !registration.canPay
                      ? null
                      : () => _startCheckout(context, installment),
                ),
              ),
            if (registration.payments.isNotEmpty) ...[
              if (registration.installments.isNotEmpty)
                const SizedBox(height: 6),
              ...registration.payments.map(
                (payment) => _PaymentHistoryRow(
                  payment: payment,
                  colors: colors,
                ),
              ),
            ],
          ],
          if (registration.tickets.isNotEmpty) ...[
            const SizedBox(height: 14),
            _RegistrationSubsectionTitle(
              icon: Icons.confirmation_number_outlined,
              title: 'Tickets and QR status',
              colors: colors,
            ),
            const SizedBox(height: 8),
            ...registration.tickets.map(
              (ticket) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TicketSummary(
                  ticket: ticket,
                  user: user,
                  colors: colors,
                ),
              ),
            ),
          ],
          if (canUseWallet) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF14513F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                onPressed: () => _payFromWallet(context),
                icon: const Icon(Icons.account_balance_wallet_rounded),
                label: Text('Pay from wallet · ${registration.balanceLabel}'),
              ),
            ),
          ],
          if (registration.canPay && !registration.isCancelled) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF14513F),
                  side: const BorderSide(color: Color(0xFF14513F)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                onPressed: () => _payWithVoucherCode(context),
                icon: const Icon(Icons.confirmation_number_outlined),
                label: const Text('Pay with voucher'),
              ),
            ),
          ],
          if (payablePayment != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB522),
                  foregroundColor: const Color(0xFF0C2230),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                onPressed: () => _startCheckout(context, payablePayment),
                icon: const Icon(Icons.lock_rounded),
                label: Text('Pay by card · ${payablePayment.amountLabel}'),
              ),
            ),
          ],
          if (registration.canCancel) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE53935),
                  side: const BorderSide(color: Color(0xFFE53935)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                onPressed: () => _confirmCancelRegistration(context),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel pending registration'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startCheckout(
    BuildContext context,
    GoshenInstallment installment,
  ) async {
    try {
      final checkout = await GoshenRetreatApi().checkoutPayment(
        registration: registration,
        payment: installment,
        user: user,
      );
      final url = '${checkout['checkout_url'] ?? ''}'.trim();
      if (url.isEmpty) {
        if (!context.mounted) return;
        _showGoshenDialog(
          context,
          title: 'Payment checkout unavailable',
          message:
              'The payment gateway is not configured with a checkout link yet. Please contact the retreat team.',
        );
        return;
      }

      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!context.mounted) return;
      if (!launched) {
        _showGoshenDialog(
          context,
          title: 'Could not open payment',
          message:
              'Please try again or contact support if your payment page does not open.',
        );
        return;
      }

      await _showGoshenDialog(
        context,
        title: 'Complete payment securely',
        message:
            'After completing payment, return to this screen and tap OK. We will refresh your registrations so your ticket and payment status can appear as soon as the gateway confirms it.',
      );
      await onRefresh();
    } catch (error) {
      if (!context.mounted) return;
      _showGoshenDialog(
        context,
        title: 'Payment could not start',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _payFromWallet(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pay from wallet?'),
          content: Text(
            'We will deduct ${registration.balanceLabel} from your Goshen wallet and issue your ticket immediately if your wallet balance is enough.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Pay now'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final verified = await WalletSecurityGuard.ensureWalletUnlocked(
        context,
        requireFreshVerification: true,
      );
      if (!verified) return;
      await GoshenRetreatApi().payBookingWithWallet(
        registration: registration,
        user: user,
      );
      if (!context.mounted) return;
      await _showGoshenDialog(
        context,
        title: 'Wallet payment complete',
        message:
            'Your Goshen Retreat registration has been paid from your wallet. Your ticket is now ready.',
      );
      await onRefresh();
    } catch (error) {
      if (!context.mounted) return;
      _showGoshenDialog(
        context,
        title: 'Wallet payment could not complete',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _payWithVoucherCode(BuildContext context) async {
    final controller = TextEditingController();
    final voucherCode = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pay with voucher'),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Voucher code',
              hintText: 'GSH-XXXX-XXXX-XXXX-XXXX',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Apply voucher'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (voucherCode == null || voucherCode.trim().isEmpty) return;

    try {
      await GoshenRetreatApi().payBookingWithVoucher(
        registration: registration,
        user: user,
        voucherCode: voucherCode,
      );
      if (!context.mounted) return;
      await _showGoshenDialog(
        context,
        title: 'Voucher payment complete',
        message:
            'Your Goshen Retreat registration has been paid with a voucher. Your ticket is now ready.',
      );
      await onRefresh();
    } catch (error) {
      if (!context.mounted) return;
      _showGoshenDialog(
        context,
        title: 'Voucher payment could not complete',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _confirmCancelRegistration(BuildContext context) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel pending registration?'),
          content: const Text(
            'This will cancel this unpaid Goshen Retreat registration. You can start a fresh registration later if you still want to attend.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep registration'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel registration'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true || !context.mounted) return;

    try {
      await GoshenRetreatApi().cancelBooking(
        registration: registration,
        user: user,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pending Goshen Retreat registration cancelled.'),
        ),
      );
      await onRefresh();
    } catch (error) {
      if (!context.mounted) return;
      _showGoshenDialog(
        context,
        title: 'Registration was not cancelled',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

class _RegistrationSubsectionTitle extends StatelessWidget {
  const _RegistrationSubsectionTitle({
    required this.icon,
    required this.title,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFE1A63B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentRecordHistoryRow extends StatelessWidget {
  const _PaymentRecordHistoryRow({
    required this.installment,
    required this.colors,
    this.onPayNow,
  });

  final GoshenInstallment installment;
  final _GoshenPalette colors;
  final VoidCallback? onPayNow;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        installment.isPaid ? installment.paidLabel : installment.dueLabel;
    final detailParts = [
      if (installment.paidAmount > 0) 'Paid ${installment.paidAmountLabel}',
      if (installment.paymentMethod.trim().isNotEmpty)
        installment.paymentMethod.trim(),
      if (installment.paymentReference.trim().isNotEmpty)
        installment.paymentReference.trim(),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: installment.isPaid
                  ? const Color(0xFF14513F).withValues(alpha: 0.14)
                  : const Color(0xFFFFB522).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              installment.isPaid
                  ? Icons.check_circle_outline_rounded
                  : Icons.schedule_rounded,
              size: 19,
              color: installment.isPaid
                  ? const Color(0xFF14513F)
                  : const Color(0xFFE1A63B),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  installment.displayLabel,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
                if (detailParts.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    detailParts.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                installment.amountLabel,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              _StatusPill(label: installment.statusLabel, colors: colors),
              if (onPayNow != null) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB522),
                    foregroundColor: const Color(0xFF0C2230),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onPressed: onPayNow,
                  icon: const Icon(Icons.lock_rounded, size: 15),
                  label: const Text('Pay now'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentHistoryRow extends StatelessWidget {
  const _PaymentHistoryRow({required this.payment, required this.colors});

  final GoshenPaymentRecord payment;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    final methodParts = [
      if (payment.method.trim().isNotEmpty) payment.method.trim(),
      if (payment.provider.trim().isNotEmpty) payment.provider.trim(),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14513F).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF14513F).withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            color: Color(0xFF14513F),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.amountLabel,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  payment.dateLabel,
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
                if (payment.reference.trim().isNotEmpty ||
                    methodParts.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (methodParts.isNotEmpty) methodParts.join(' · '),
                      if (payment.reference.trim().isNotEmpty)
                        payment.reference,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(label: payment.statusLabel, colors: colors),
        ],
      ),
    );
  }
}

class _AttendeeSnapshotChip extends StatelessWidget {
  const _AttendeeSnapshotChip({
    required this.attendee,
    required this.colors,
  });

  final GoshenAttendee attendee;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    final name = attendee.name.trim().isEmpty ? 'Attendee' : attendee.name;
    final work = [
      attendee.company.trim(),
      attendee.designation.trim(),
    ].where((value) => value.isNotEmpty).join(' · ');
    final label = [
      name,
      attendee.genderLabel,
      attendee.ageGroupLabel,
      attendee.freeChurchBusInterestLabel,
      attendee.volunteerDepartmentLabel,
      if (work.isNotEmpty) work,
    ].join(' · ');

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 88,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline_rounded,
            size: 16,
            color: Color(0xFFFFB522),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketSummary extends StatelessWidget {
  const _TicketSummary({
    required this.ticket,
    required this.user,
    required this.colors,
  });

  final GoshenTicket ticket;
  final Userdata user;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    final checkedIn = ticket.isCheckedIn;
    final statusColor =
        checkedIn ? const Color(0xFF11845B) : const Color(0xFFE1A63B);
    final statusMessage =
        checkedIn ? 'Checked in ${ticket.checkInLabel}' : 'Ready for check-in';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: checkedIn
            ? () => _showGoshenDialog(
                  context,
                  title: 'Ticket already checked in',
                  message:
                      'This ticket was checked in on ${ticket.checkInLabel}. The QR view is locked to prevent repeated use.',
                )
            : () => _showTicketDetails(context, ticket, user, colors),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.26),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      checkedIn
                          ? Icons.lock_rounded
                          : Icons.confirmation_number_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.ticketNumber.isEmpty
                              ? 'Ticket issued'
                              : ticket.ticketNumber,
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (ticket.attendeeName.isNotEmpty)
                              ticket.attendeeName,
                            if (ticket.ticketType.isNotEmpty) ticket.ticketType,
                            'Paid ${ticket.amountPaidLabel}',
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(label: ticket.qrStatusLabel, colors: colors),
                  const SizedBox(width: 6),
                  Icon(
                    checkedIn
                        ? Icons.lock_outline_rounded
                        : Icons.chevron_right_rounded,
                    color: checkedIn ? statusColor : colors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: checkedIn ? 0.14 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      checkedIn
                          ? Icons.verified_rounded
                          : Icons.schedule_rounded,
                      size: 18,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (checkedIn) ...[
                      const SizedBox(width: 8),
                      Text(
                        'QR locked',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _friendlyTicketLookupMessage(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '').trim();
  if (message.isEmpty ||
      message.contains('No query results for model') ||
      message.contains('Personal\\EventInstallments\\Models\\Ticket')) {
    return 'We could not find a Goshen Retreat ticket with that number. Please check the last four digits, enter the full ticket number, or scan the QR code again.';
  }

  return message;
}

Future<void> _showTicketDetails(
  BuildContext context,
  GoshenTicket ticket,
  Userdata user,
  _GoshenPalette colors,
) {
  final hostContext = context;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final code = ticket.qrEncoded.trim();
      return SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.84,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0C2230), Color(0xFF14513F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.confirmation_number_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.ticketNumber.isEmpty
                                  ? 'Issued ticket'
                                  : ticket.ticketNumber,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ticket.eventName.isEmpty
                                  ? 'Goshen Retreat ticket'
                                  : ticket.eventName,
                              style:
                                  TextStyle(color: colors.muted, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.innerCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        _TicketMetaRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Attendee',
                          value: ticket.attendeeName.isEmpty
                              ? 'Not specified'
                              : ticket.attendeeName,
                          colors: colors,
                        ),
                        _TicketMetaRow(
                          icon: Icons.local_activity_outlined,
                          label: 'Ticket type',
                          value: ticket.ticketType.isEmpty
                              ? 'Ticket'
                              : ticket.ticketType,
                          colors: colors,
                        ),
                        _TicketMetaRow(
                          icon: Icons.verified_rounded,
                          label: 'Status',
                          value: ticket.statusLabel,
                          colors: colors,
                        ),
                        _TicketMetaRow(
                          icon: Icons.payments_outlined,
                          label: 'Amount paid',
                          value: ticket.amountPaidLabel,
                          colors: colors,
                        ),
                        _TicketMetaRow(
                          icon: Icons.event_available_outlined,
                          label: 'Issued',
                          value: ticket.issuedLabel,
                          colors: colors,
                        ),
                        _TicketMetaRow(
                          icon: Icons.fact_check_outlined,
                          label: 'Check-in',
                          value: ticket.checkInLabel,
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB522).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFB522).withValues(alpha: 0.28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.qr_code_2_rounded,
                              color: Color(0xFFE1A63B),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                code.isEmpty
                                    ? 'QR code pending'
                                    : 'Secure QR code',
                                style: TextStyle(
                                  color: colors.text,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          code.isEmpty
                              ? 'This ticket has been issued, but the secure QR payload is not available yet. Please contact the retreat team before check-in.'
                              : 'Use this secure ticket code at check-in. You can copy it if a staff member asks for the code manually.',
                          style: TextStyle(color: colors.muted, height: 1.4),
                        ),
                        if (code.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE1A63B)
                                      .withValues(alpha: 0.32),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: code,
                                version: QrVersions.auto,
                                size: 190,
                                gapless: true,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF0C2230),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF0C2230),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Show this QR image at check-in. Staff may also ask for the secure code manually.',
                            style: TextStyle(
                              color: colors.muted,
                              height: 1.35,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: ticket.ticketNumber.isEmpty
                              ? null
                              : () => _copyTicketTextAndClose(
                                    sheetContext: context,
                                    feedbackContext: hostContext,
                                    ticket.ticketNumber,
                                    'Ticket number copied',
                                  ),
                          icon: const Icon(Icons.confirmation_number_outlined),
                          label: const Text('Copy ticket'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB522),
                            foregroundColor: const Color(0xFF0C2230),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          onPressed: code.isEmpty
                              ? null
                              : () => _copyTicketTextAndClose(
                                    sheetContext: context,
                                    feedbackContext: hostContext,
                                    code,
                                    'QR code copied',
                                  ),
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copy QR'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _TicketMetaRow extends StatelessWidget {
  const _TicketMetaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final String value;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFE1A63B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _copyTicketTextAndClose(
  String value,
  String message, {
  required BuildContext sheetContext,
  required BuildContext feedbackContext,
}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (sheetContext.mounted) {
    Navigator.pop(sheetContext);
  }
  if (!feedbackContext.mounted) return;
  ScaffoldMessenger.of(feedbackContext).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Future<void> _showGoshenDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final String value;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFE1A63B)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: colors.text,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.colors});

  final String label;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB522).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.text,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final String message;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFB522).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFFE1A63B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: TextStyle(color: colors.muted, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoshenRegistrationSheet extends StatefulWidget {
  const _GoshenRegistrationSheet({
    required this.event,
    required this.user,
  });

  final GoshenRetreatEvent event;
  final Userdata user;

  @override
  State<_GoshenRegistrationSheet> createState() =>
      _GoshenRegistrationSheetState();
}

class _GoshenRegistrationSheetState extends State<_GoshenRegistrationSheet> {
  late GoshenTicketType _ticketType;
  late int _quantity;
  late List<_AttendeeDraft> _attendees;
  Future<GoshenWallet?>? _walletFuture;
  bool _walletAccessGranted = false;
  bool _payWithWallet = false;
  bool _payWithVoucher = false;
  bool _ukPrivacyConsent = false;
  bool _applyPayInFullDiscount = true;
  bool _submitting = false;
  String _referralCode = '';
  String _voucherCode = '';
  Map<String, dynamic>? _pendingBooking;

  @override
  void initState() {
    super.initState();
    _ticketType = widget.event.ticketTypes.first;
    _quantity =
        _ticketType.minPerBooking.clamp(1, _ticketType.maxPerBooking).toInt();
    _attendees = [
      _AttendeeDraft(
        firstName: _fallbackFirstName(widget.user),
        lastName: _fallbackLastName(widget.user),
        email: widget.user.email ?? '',
        phone: widget.user.phone ?? '',
      ),
    ];
    _syncAttendees();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _GoshenPalette.of(context);
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final topSafeInset = media.viewPadding.top;
    final bottomSafeInset = media.viewPadding.bottom;
    final maxSheetHeight =
        media.size.height - topSafeInset - keyboardInset - 12;
    final ticketSubtotal = _ticketType.price * _quantity;
    final optionFees = _selectedOptionFeeTotal();
    final discount = _applyPayInFullDiscount
        ? widget.event.payInFullDiscount.amountFor(ticketSubtotal)
        : 0.0;
    final total = ((ticketSubtotal - discount) + optionFees)
        .clamp(0, ticketSubtotal + optionFees)
        .toDouble();

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxSheetHeight < 420
                ? media.size.height - keyboardInset
                : maxSheetHeight,
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, bottomSafeInset + 30),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.muted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Register for Goshen Retreat',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose your ticket, attendee count, and how you want to complete the full payment.',
                  style: TextStyle(color: colors.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SheetSelect<GoshenTicketType>(
                          label: 'Ticket type',
                          value: _ticketType,
                          values: widget.event.ticketTypes,
                          colors: colors,
                          text: (ticket) =>
                              '${ticket.name} · ${ticket.currency} ${ticket.price.toStringAsFixed(ticket.price == ticket.price.roundToDouble() ? 0 : 2)}',
                          onChanged: (ticket) {
                            if (ticket == null) return;
                            setState(() {
                              _ticketType = ticket;
                              _payWithWallet = false;
                              _payWithVoucher = false;
                              _quantity = _quantity
                                  .clamp(
                                    ticket.minPerBooking,
                                    ticket.maxPerBooking,
                                  )
                                  .toInt();
                              _syncAttendees();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _RegistrationPaymentChoice(
                          total: total,
                          currency: _ticketType.currency,
                          payWithWallet: _payWithWallet,
                          payWithVoucher: _payWithVoucher,
                          walletAccessGranted: _walletAccessGranted,
                          walletFuture: _walletFuture,
                          colors: colors,
                          onChanged: _selectPaymentMode,
                        ),
                        if (_payWithVoucher) ...[
                          const SizedBox(height: 12),
                          _SheetTextField(
                            initialValue: _voucherCode,
                            label: 'Voucher code',
                            colors: colors,
                            onChanged: (value) => _voucherCode = value,
                          ),
                        ],
                        if (widget.event.payInFullDiscount.available) ...[
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _applyPayInFullDiscount,
                            onChanged: (value) {
                              setState(() {
                                _applyPayInFullDiscount = value;
                                _payWithWallet = false;
                                _payWithVoucher = false;
                              });
                            },
                            title: Text(
                              widget.event.payInFullDiscount.label,
                              style: TextStyle(
                                color: colors.text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              widget.event.payInFullDiscount.description(
                                  _ticketType.currency, ticketSubtotal),
                              style: TextStyle(color: colors.muted),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _SheetTextField(
                          initialValue: _referralCode,
                          label: 'Referral code (optional)',
                          colors: colors,
                          onChanged: (value) => _referralCode = value,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.innerCard,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Attendees',
                                      style: TextStyle(
                                        color: colors.text,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add names for everyone covered by this registration.',
                                      style: TextStyle(
                                        color: colors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton.filledTonal(
                                onPressed:
                                    _quantity <= _ticketType.minPerBooking
                                        ? null
                                        : () => setState(() {
                                              _quantity--;
                                              _syncAttendees();
                                            }),
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '$_quantity',
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB522),
                                  foregroundColor: const Color(0xFF0C2230),
                                ),
                                onPressed:
                                    _quantity >= _ticketType.maxPerBooking
                                        ? null
                                        : () => setState(() {
                                              _quantity++;
                                              _syncAttendees();
                                            }),
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...List.generate(
                          _attendees.length,
                          (index) => Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _attendees.length - 1 ? 0 : 12,
                            ),
                            child: _AttendeeFields(
                              index: index,
                              attendee: _attendees[index],
                              registrationFields:
                                  widget.event.registrationFields,
                              currency: _ticketType.currency,
                              colors: colors,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _RegistrationConsentTile(
                          value: _ukPrivacyConsent,
                          onChanged: (value) =>
                              setState(() => _ukPrivacyConsent = value),
                          colors: colors,
                          title: 'Privacy consent',
                          subtitle:
                              'I agree that MFM Triumphant Church may process my registration, attendee, payment, ticket, and travel-support information for Goshen Retreat administration in line with UK data protection requirements.',
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Estimated total',
                        style: TextStyle(
                          color: colors.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${_ticketType.currency} ${total.toStringAsFixed(total == total.roundToDouble() ? 0 : 2)}',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (discount > 0) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Discount applied: ${_ticketType.currency} ${discount.toStringAsFixed(discount == discount.roundToDouble() ? 0 : 2)}',
                      style: TextStyle(
                        color: const Color(0xFF14513F),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                if (optionFees > 0) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Option fees: ${_ticketType.currency} ${_formatScreenMoney(optionFees)}',
                      style: TextStyle(
                        color: colors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB522),
                    foregroundColor: const Color(0xFF0C2230),
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(Icons.how_to_reg_rounded),
                  label: Text(
                      _submitting ? 'Starting registration...' : 'Continue'),
                ),
                SizedBox(height: bottomSafeInset > 0 ? 4 : 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final missingChoiceMessage = _missingAttendeeChoiceMessage();
    if (missingChoiceMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(missingChoiceMessage)),
      );
      return;
    }

    if (!_ukPrivacyConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the privacy consent to register.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final ticketSubtotal = _ticketType.price * _quantity;
      final optionFees = _selectedOptionFeeTotal();
      final discount = _applyPayInFullDiscount
          ? widget.event.payInFullDiscount.amountFor(ticketSubtotal)
          : 0.0;
      final total = ((ticketSubtotal - discount) + optionFees)
          .clamp(0, ticketSubtotal + optionFees)
          .toDouble();

      if (_payWithWallet) {
        final verified = await WalletSecurityGuard.ensureWalletUnlocked(
          context,
          requireFreshVerification: true,
        );
        if (!verified) return;
        final wallet = await _walletFuture;
        final walletCurrency = (wallet?.currency ?? '').trim().toUpperCase();
        final ticketCurrency = _ticketType.currency.trim().toUpperCase();
        if (wallet == null ||
            walletCurrency != ticketCurrency ||
            wallet.balance + 0.01 < total) {
          throw Exception(
            'Your wallet balance is not enough for this ticket. Please choose card payment or top up your wallet first.',
          );
        }
      }

      if (_payWithVoucher && _voucherCode.trim().isEmpty) {
        throw Exception('Please enter your Goshen voucher code.');
      }

      final booking = _pendingBooking ??
          await GoshenRetreatApi().startBooking(
            event: widget.event,
            ticketType: _ticketType,
            quantity: _quantity,
            user: widget.user,
            paymentMode: _payWithWallet
                ? 'wallet'
                : (_payWithVoucher ? 'voucher' : 'outright'),
            voucherCode: _payWithVoucher ? _voucherCode : '',
            freeChurchBusConsent: _attendees.any(
              (attendee) => attendee.freeChurchBusInterest == 'yes',
            ),
            ukPrivacyConsent: _ukPrivacyConsent,
            applyPayInFullDiscount: _applyPayInFullDiscount,
            fieldOptionFeeTotal: optionFees,
            fieldOptionFees: _selectedOptionFeesPayload(),
            referralCode: _referralCode,
            attendees: _attendees.map((attendee) => attendee.toJson()).toList(),
          );
      _pendingBooking = booking;
      if (!mounted) return;
      await _openCheckoutForBooking(context, booking);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.toLowerCase().contains('complete your member profile') ||
          message.toLowerCase().contains('complete profile')) {
        await _showGoshenDialog(
          context,
          title: 'Complete your profile',
          message:
              '$message\n\nOpen your profile page, add the missing details, then return to register.',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _missingAttendeeChoiceMessage() {
    for (var index = 0; index < _attendees.length; index += 1) {
      final attendee = _attendees[index];
      final attendeeLabel = 'Attendee ${index + 1}';
      for (final field in widget.event.registrationFields) {
        if (field.isRequired && attendee.fieldValue(field.key).trim().isEmpty) {
          return 'Please select ${field.label} for $attendeeLabel.';
        }
      }
    }

    return null;
  }

  Future<void> _selectPaymentMode(String mode) async {
    if (mode == 'card') {
      setState(() {
        _payWithWallet = false;
        _payWithVoucher = false;
      });
      return;
    }

    if (mode == 'voucher') {
      setState(() {
        _payWithWallet = false;
        _payWithVoucher = true;
      });
      return;
    }

    final verified = await WalletSecurityGuard.ensureWalletUnlocked(
      context,
      requireFreshVerification: true,
    );
    if (!verified || !mounted) return;

    final future = GoshenWalletApi()
        .fetchWallet(widget.user)
        .then<GoshenWallet?>((wallet) => wallet)
        .catchError((_) => null);
    setState(() {
      _walletAccessGranted = true;
      _walletFuture = future;
      _payWithWallet = false;
      _payWithVoucher = false;
    });

    final wallet = await future;
    if (!mounted) return;
    final ticketSubtotal = _ticketType.price * _quantity;
    final optionFees = _selectedOptionFeeTotal();
    final discount = _applyPayInFullDiscount
        ? widget.event.payInFullDiscount.amountFor(ticketSubtotal)
        : 0.0;
    final total = ((ticketSubtotal - discount) + optionFees)
        .clamp(0, ticketSubtotal + optionFees)
        .toDouble();
    final walletCurrency = (wallet?.currency ?? '').trim().toUpperCase();
    final ticketCurrency = _ticketType.currency.trim().toUpperCase();
    final walletEnough = wallet != null &&
        walletCurrency == ticketCurrency &&
        wallet.balance + 0.01 >= total;
    if (walletEnough) {
      setState(() {
        _payWithWallet = true;
        _payWithVoucher = false;
      });
      return;
    }
    await _showGoshenDialog(
      context,
      title: 'Wallet cannot pay this ticket',
      message:
          'Your wallet balance or currency is not enough for this ticket. Please choose card payment or top up your wallet first.',
    );
  }

  void _syncAttendees() {
    while (_attendees.length < _quantity) {
      _attendees.add(_AttendeeDraft());
    }
    if (_attendees.length > _quantity) {
      _attendees = _attendees.take(_quantity).toList();
    }
  }

  double _selectedOptionFeeTotal() {
    var total = 0.0;
    for (final attendee in _attendees) {
      for (final field in widget.event.registrationFields) {
        final option = _selectedOption(field, attendee.fieldValue(field.key));
        if (option != null) total += option.fee;
      }
    }
    return total;
  }

  List<Map<String, dynamic>> _selectedOptionFeesPayload() {
    final rows = <Map<String, dynamic>>[];
    for (var attendeeIndex = 0;
        attendeeIndex < _attendees.length;
        attendeeIndex += 1) {
      final attendee = _attendees[attendeeIndex];
      for (final field in widget.event.registrationFields) {
        final selectedValue = attendee.fieldValue(field.key);
        final option = _selectedOption(field, selectedValue);
        if (option == null || !option.hasFee) continue;
        rows.add({
          'attendee_index': attendeeIndex,
          'field_key': field.key,
          'field_label': field.label,
          'option_value': option.value,
          'option_label': option.label,
          'fee': option.fee,
          if (option.currency.trim().isNotEmpty) 'currency': option.currency,
        });
      }
    }
    return rows;
  }

  GoshenRegistrationFieldOption? _selectedOption(
    GoshenRegistrationField field,
    String value,
  ) {
    if (value.trim().isEmpty) return null;
    for (final option in field.options) {
      if (option.value == value) return option;
    }
    return null;
  }

  Future<void> _openCheckoutForBooking(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final registration = GoshenRegistration.fromJson(booking);
    GoshenInstallment? nextInstallment;
    for (final installment in registration.installments) {
      if (!installment.isPaid) {
        nextInstallment = installment;
        break;
      }
    }

    if (nextInstallment == null) {
      await _showGoshenDialog(
        context,
        title: 'Registration completed',
        message:
            'Your Goshen Retreat booking reference is ${registration.publicId}. Your ticket details will be available in your registrations.',
      );
      return;
    }

    final checkout = await GoshenRetreatApi().checkoutPayment(
      registration: registration,
      payment: nextInstallment,
      user: widget.user,
    );
    final url = '${checkout['checkout_url'] ?? ''}'.trim();
    if (url.isEmpty) {
      await _showGoshenDialog(
        context,
        title: 'Registration started',
        message:
            'Your Goshen Retreat booking reference is ${registration.publicId}. Payment checkout is not available yet, but you can complete payment later from your Goshen registrations.',
      );
      return;
    }

    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      await _showGoshenDialog(
        context,
        title: 'Could not open payment',
        message:
            'Your booking was created, but the payment page could not open. You can complete payment later from your Goshen registrations.',
      );
      return;
    }

    await _showGoshenDialog(
      context,
      title: 'Complete payment securely',
      message:
          'Your booking has been created. Complete payment in the secure checkout page, then return to the app and tap OK. We will refresh your registrations and show your ticket as soon as payment is confirmed.',
    );
  }

  String _fallbackFirstName(Userdata user) {
    final explicit = (user.firstName ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    final parts = (user.name ?? '').trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }

  String _fallbackLastName(Userdata user) {
    final explicit = (user.lastName ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    final parts = (user.name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }
}

class _RegistrationConsentTile extends StatelessWidget {
  const _RegistrationConsentTile({
    required this.value,
    required this.onChanged,
    required this.colors,
    required this.title,
    required this.subtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final _GoshenPalette colors;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.innerCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (checked) => onChanged(checked ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: const Color(0xFF14513F),
        title: Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: colors.muted, height: 1.35),
        ),
      ),
    );
  }
}

class _RegistrationPaymentChoice extends StatelessWidget {
  const _RegistrationPaymentChoice({
    required this.total,
    required this.currency,
    required this.payWithWallet,
    required this.payWithVoucher,
    required this.walletAccessGranted,
    required this.walletFuture,
    required this.colors,
    required this.onChanged,
  });

  final double total;
  final String currency;
  final bool payWithWallet;
  final bool payWithVoucher;
  final bool walletAccessGranted;
  final Future<GoshenWallet?>? walletFuture;
  final _GoshenPalette colors;
  final Future<void> Function(String value) onChanged;

  @override
  Widget build(BuildContext context) {
    final future = walletFuture;
    if (!walletAccessGranted || future == null) {
      return _buildChoices(
        walletEnough: false,
        walletButtonEnabled: true,
        walletButtonLabel: 'Unlock wallet',
        walletHint:
            'Unlock your wallet to check whether it can pay this ticket.',
      );
    }

    return FutureBuilder<GoshenWallet?>(
      future: walletFuture,
      builder: (context, snapshot) {
        final wallet = snapshot.data;
        final walletCurrency = (wallet?.currency ?? '').trim().toUpperCase();
        final ticketCurrency = currency.trim().toUpperCase();
        final walletMatches =
            wallet != null && walletCurrency == ticketCurrency;
        final walletEnough =
            walletMatches && (wallet.balance + 0.01) >= total && total > 0;
        final walletHint = wallet == null
            ? 'Wallet balance unavailable. You can still pay securely by card.'
            : !walletMatches
                ? 'Wallet currency ${wallet.currency} cannot pay a $currency ticket.'
                : walletEnough
                    ? 'Wallet balance: ${wallet.currency} ${_formatScreenMoney(wallet.balance)}'
                    : 'Wallet balance ${wallet.currency} ${_formatScreenMoney(wallet.balance)} is below this total.';

        return _buildChoices(
          walletEnough: walletEnough,
          walletButtonEnabled: walletEnough,
          walletButtonLabel: 'Pay from wallet',
          walletHint: walletHint,
        );
      },
    );
  }

  Widget _buildChoices({
    required bool walletEnough,
    required bool walletButtonEnabled,
    required String walletButtonLabel,
    required String walletHint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment option',
          style: TextStyle(
            color: colors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _PaymentChoiceButton(
                selected: !payWithWallet && !payWithVoucher,
                icon: Icons.credit_card_rounded,
                label: 'Pay by card',
                colors: colors,
                onTap: () {
                  onChanged('card');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PaymentChoiceButton(
                selected: payWithWallet,
                enabled: walletButtonEnabled,
                icon: Icons.account_balance_wallet_rounded,
                label: walletButtonLabel,
                colors: colors,
                onTap: () {
                  onChanged('wallet');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PaymentChoiceButton(
          selected: payWithVoucher,
          icon: Icons.confirmation_number_outlined,
          label: 'Pay with voucher',
          colors: colors,
          onTap: () {
            onChanged('voucher');
          },
        ),
        const SizedBox(height: 8),
        Text(
          walletHint,
          style: TextStyle(
            color: walletEnough ? const Color(0xFF14513F) : colors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PaymentChoiceButton extends StatelessWidget {
  const _PaymentChoiceButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.enabled = true,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String label;
  final _GoshenPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFFFB522) : colors.innerCard;
    final fg = selected ? const Color(0xFF0C2230) : colors.text;

    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? const Color(0xFFFFB522) : colors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendeeDraft {
  _AttendeeDraft({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
  });

  String firstName;
  String lastName;
  String email;
  String phone;
  String company = '';
  String designation = '';
  String gender = '';
  String ageGroup = '';
  String freeChurchBusInterest = '';
  String volunteerDepartment = '';
  final Map<String, String> customFields = {};

  String fieldValue(String key) {
    final canonicalKey = _attendeeFieldIdentity(key);
    if (customFields.containsKey(key)) return customFields[key] ?? '';
    if (customFields.containsKey(canonicalKey)) {
      return customFields[canonicalKey] ?? '';
    }

    return switch (canonicalKey) {
      'company' => company,
      'designation' => designation,
      'gender' => gender,
      'age_group' => ageGroup,
      'free_church_bus_interest' => freeChurchBusInterest,
      'volunteer_department' => volunteerDepartment,
      _ => '',
    };
  }

  void setFieldValue(String key, String value) {
    final canonicalKey = _attendeeFieldIdentity(key);
    customFields[key] = value;
    if (canonicalKey != key) {
      customFields[canonicalKey] = value;
    }

    switch (canonicalKey) {
      case 'company':
        company = value;
        break;
      case 'designation':
        designation = value;
        break;
      case 'gender':
        gender = value;
        break;
      case 'age_group':
        ageGroup = value;
        break;
      case 'free_church_bus_interest':
        freeChurchBusInterest = value;
        break;
      case 'volunteer_department':
        volunteerDepartment = value;
        break;
    }
  }

  Map<String, dynamic> toJson() {
    final fields = Map<String, String>.from(customFields);
    final data = <String, dynamic>{
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'company': company.trim(),
      'designation': designation.trim(),
      'gender': gender,
      'age_group': ageGroup,
      'free_church_bus_interest': freeChurchBusInterest,
      'volunteer_department': volunteerDepartment,
    };
    data.addAll(fields);
    data['custom_fields'] = fields;

    return data;
  }
}

String _attendeeFieldIdentity(String key) {
  final normalized = key
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  const aliases = {
    'age': 'age_group',
    'agegroup': 'age_group',
    'free_bus': 'free_church_bus_interest',
    'freechurchbus': 'free_church_bus_interest',
    'free_church_bus': 'free_church_bus_interest',
    'free_church_bus_consent': 'free_church_bus_interest',
    'church_bus': 'free_church_bus_interest',
    'bus_interest': 'free_church_bus_interest',
    'volunteer': 'volunteer_department',
    'volunteer_choice': 'volunteer_department',
    'volunteer_department_choice': 'volunteer_department',
  };
  return aliases[normalized] ?? normalized;
}

class _AttendeeFields extends StatelessWidget {
  const _AttendeeFields({
    required this.index,
    required this.attendee,
    required this.registrationFields,
    required this.currency,
    required this.colors,
    required this.onChanged,
  });

  final int index;
  final _AttendeeDraft attendee;
  final List<GoshenRegistrationField> registrationFields;
  final String currency;
  final _GoshenPalette colors;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 390;
    Widget responsivePair(Widget first, Widget second) {
      if (compact) {
        return Column(
          children: [
            first,
            const SizedBox(height: 10),
            second,
          ],
        );
      }

      return Row(
        children: [
          Expanded(child: first),
          const SizedBox(width: 10),
          Expanded(child: second),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.innerCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendee ${index + 1}',
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          responsivePair(
            _SheetTextField(
              initialValue: attendee.firstName,
              label: 'First name',
              colors: colors,
              onChanged: (value) => attendee.firstName = value,
            ),
            _SheetTextField(
              initialValue: attendee.lastName,
              label: 'Last name',
              colors: colors,
              onChanged: (value) => attendee.lastName = value,
            ),
          ),
          const SizedBox(height: 10),
          _SheetTextField(
            initialValue: attendee.email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            colors: colors,
            onChanged: (value) => attendee.email = value,
          ),
          const SizedBox(height: 10),
          _SheetTextField(
            initialValue: attendee.phone,
            label: 'Phone',
            keyboardType: TextInputType.phone,
            colors: colors,
            onChanged: (value) => attendee.phone = value,
          ),
          ...registrationFields.map(
            (field) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _RegistrationFieldControl(
                field: field,
                value: attendee.fieldValue(field.key),
                currency: currency,
                colors: colors,
                onChanged: (value) {
                  attendee.setFieldValue(field.key, value);
                  onChanged();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationFieldControl extends StatelessWidget {
  const _RegistrationFieldControl({
    required this.field,
    required this.value,
    required this.currency,
    required this.colors,
    required this.onChanged,
  });

  final GoshenRegistrationField field;
  final String value;
  final String currency;
  final _GoshenPalette colors;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = field.isRequired ? '${field.label} *' : field.label;

    if (field.isSelect) {
      final values = field.options.map((option) => option.value).toList();
      final safeValue = values.contains(value)
          ? value
          : (values.contains('') ? '' : (values.isEmpty ? '' : values.first));

      return _SheetSelect<String>(
        label: label,
        value: safeValue,
        values: values.isEmpty ? [''] : values,
        text: (optionValue) => field.options
            .firstWhere(
              (option) => option.value == optionValue,
              orElse: () => GoshenRegistrationFieldOption(
                label: optionValue.isEmpty ? 'Please Select' : optionValue,
                value: optionValue,
                imagePath: '',
                imageUrl: '',
                colorHex: '',
                fee: 0,
                feeLabel: '',
                currency: '',
              ),
            )
            .labelWithFee(currency),
        onChanged: (next) => onChanged(next ?? ''),
        colors: colors,
      );
    }

    if (field.isImageSelect || field.isColorSelect) {
      return _RegistrationOptionGrid(
        field: field,
        value: value,
        currency: currency,
        colors: colors,
        onChanged: onChanged,
      );
    }

    return _SheetTextField(
      initialValue: value,
      label: label,
      maxLines: field.isTextArea ? 3 : 1,
      colors: colors,
      onChanged: onChanged,
    );
  }
}

class _RegistrationOptionGrid extends StatefulWidget {
  const _RegistrationOptionGrid({
    required this.field,
    required this.value,
    required this.currency,
    required this.colors,
    required this.onChanged,
  });

  final GoshenRegistrationField field;
  final String value;
  final String currency;
  final _GoshenPalette colors;
  final ValueChanged<String> onChanged;

  @override
  State<_RegistrationOptionGrid> createState() =>
      _RegistrationOptionGridState();
}

class _RegistrationOptionGridState extends State<_RegistrationOptionGrid> {
  late String _value = widget.value;

  @override
  void didUpdateWidget(covariant _RegistrationOptionGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.field.options
        .where((option) => option.value.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.field.isRequired
              ? '${widget.field.label} *'
              : widget.field.label,
          style: TextStyle(
            color: widget.colors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final selected = option.value == _value;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() => _value = option.value);
                widget.onChanged(option.value);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 132,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFFB522).withValues(alpha: 0.14)
                      : widget.colors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFFB522)
                        : widget.colors.border,
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (option.imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: option.imageUrl,
                          height: 74,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (option.colorHex.isNotEmpty)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _colorFromHex(option.colorHex),
                          shape: BoxShape.circle,
                          border: Border.all(color: widget.colors.border),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      option.labelWithFee(widget.currency),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.initialValue,
    required this.label,
    required this.colors,
    required this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String initialValue;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;
  final _GoshenPalette colors;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: colors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFFB522), width: 1.4),
        ),
      ),
    );
  }
}

class _SheetSelect<T> extends StatelessWidget {
  const _SheetSelect({
    required this.label,
    required this.value,
    required this.values,
    required this.text,
    required this.onChanged,
    required this.colors,
  });

  final String label;
  final T? value;
  final List<T> values;
  final String Function(T value) text;
  final ValueChanged<T?> onChanged;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                text(item),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: colors.innerCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
    );
  }
}

class _GoshenHero extends StatelessWidget {
  const _GoshenHero({
    required this.event,
    required this.colors,
    required this.onTap,
  });

  final GoshenRetreatEvent event;
  final _GoshenPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: colors.isDark ? 0.24 : 0.1),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GoshenFeatureImage(
                imageUrl: event.featureImageUrl,
                aspectRatio: 16 / 9,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                fallbackIcon: Icons.church_rounded,
                child: Stack(
                  children: [
                    const Positioned(
                      left: 16,
                      top: 16,
                      child: _GoldPill(text: 'Next retreat'),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: _DarkPill(
                        icon: event.registration.open
                            ? Icons.lock_open_rounded
                            : Icons.lock_clock_rounded,
                        text: event.registration.open
                            ? 'Registration open'
                            : 'Registration closed',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name.isEmpty ? 'Goshen Retreat' : event.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 25,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 17,
                          color: colors.muted,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Tap for tickets and registration details',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoshenLandingDescription extends StatelessWidget {
  const _GoshenLandingDescription({
    required this.event,
    required this.colors,
  });

  final GoshenRetreatEvent event;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    final description = event.description.trim().isEmpty
        ? 'Register for the next retreat edition, review schedules, tickets, and payment options.'
        : event.description.trim();

    return _SectionCard(
      title: 'About Goshen Retreat',
      icon: Icons.church_outlined,
      colors: colors,
      child: Text(
        description,
        style: TextStyle(
          color: colors.muted,
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GoshenShareActions extends StatefulWidget {
  const _GoshenShareActions({
    required this.event,
    required this.colors,
  });

  final GoshenRetreatEvent event;
  final _GoshenPalette colors;

  @override
  State<_GoshenShareActions> createState() => _GoshenShareActionsState();
}

class _GoshenShareActionsState extends State<_GoshenShareActions> {
  late Future<_GoshenShareProfile> _profileFuture;
  bool _includeReferralCode = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadShareProfile();
  }

  Future<_GoshenShareProfile> _loadShareProfile() async {
    final user = await SQLiteDbProvider.db.getUserData();
    if (user == null || (user.apiToken ?? '').trim().isEmpty) {
      return const _GoshenShareProfile.signedOut();
    }

    final api = GoshenRetreatApi();
    final cachedData = api.cachedMyRetreatData(user);
    if (cachedData != null) {
      return _GoshenShareProfile.signedIn(
        referralCode: cachedData.referralSummary.code,
      );
    }

    try {
      final data = await api.fetchMyRetreatData(user);
      return _GoshenShareProfile.signedIn(
        referralCode: data.referralSummary.code,
      );
    } catch (_) {
      return const _GoshenShareProfile.signedIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Share Goshen Retreat',
      icon: Icons.ios_share_rounded,
      colors: widget.colors,
      child: FutureBuilder<_GoshenShareProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final profile =
              snapshot.data ?? const _GoshenShareProfile.signedOut();
          final referralCode =
              _includeReferralCode ? profile.referralCode.trim() : '';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReferralShareHelper(colors: widget.colors),
              const SizedBox(height: 12),
              _buildReferralChoice(profile, snapshot.connectionState),
              const SizedBox(height: 14),
              _buildShareButtons(referralCode),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReferralChoice(
    _GoshenShareProfile profile,
    ConnectionState connectionState,
  ) {
    if (connectionState == ConnectionState.waiting) {
      return Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.colors.muted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Checking your referral code...',
              style: TextStyle(
                color: widget.colors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    if (profile.hasReferralCode) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _includeReferralCode,
        activeColor: const Color(0xFFFFB522),
        title: Text(
          'Include my referral code',
          style: TextStyle(
            color: widget.colors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          'Adds "${profile.referralCode.trim()}" to the share message.',
          style: TextStyle(
            color: widget.colors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        onChanged: (value) => setState(() => _includeReferralCode = value),
      );
    }

    final message = profile.signedIn
        ? 'Your referral code appears on the My Registration page under Referral rewards.'
        : 'Members can sign in and find their referral code on the My Registration page.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.badge_outlined,
          color: Color(0xFFE1A63B),
          size: 20,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: widget.colors.muted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShareButtons(String referralCode) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 360;
        final shareButton = FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFB522),
            foregroundColor: const Color(0xFF0C2230),
            minimumSize: const Size.fromHeight(48),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
          onPressed: () => _shareGoshenEvent(
            context,
            widget.event,
            referralCode: referralCode,
          ),
          icon: const Icon(Icons.share_rounded),
          label: Text(
            referralCode.isEmpty ? 'Share invitation' : 'Share with code',
          ),
        );
        final copyButton = OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.colors.text,
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: widget.colors.border),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
          onPressed: () => _copyGoshenEventLink(context, widget.event),
          icon: const Icon(Icons.link_rounded),
          label: const Text('Copy link'),
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              shareButton,
              const SizedBox(height: 10),
              copyButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: shareButton),
            const SizedBox(width: 10),
            Expanded(child: copyButton),
          ],
        );
      },
    );
  }
}

class _MyRegistrationShortcut extends StatelessWidget {
  const _MyRegistrationShortcut({required this.colors});

  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'My Registration',
      icon: Icons.confirmation_number_rounded,
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'View your bookings, tickets, accommodation, giving history, and referral rewards on a focused page.',
            style: TextStyle(
              color: colors.muted,
              fontSize: 14,
              height: 1.42,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB522),
              foregroundColor: const Color(0xFF0C2230),
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: () => Navigator.pushNamed(
                context, GoshenMyRegistrationScreen.routeName),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open My Registration'),
          ),
        ],
      ),
    );
  }
}

class _GoshenShareProfile {
  const _GoshenShareProfile({
    required this.signedIn,
    required this.referralCode,
  });

  const _GoshenShareProfile.signedOut()
      : signedIn = false,
        referralCode = '';

  const _GoshenShareProfile.signedIn({this.referralCode = ''})
      : signedIn = true;

  final bool signedIn;
  final String referralCode;

  bool get hasReferralCode => referralCode.trim().isNotEmpty;
}

class _ReferralShareHelper extends StatelessWidget {
  const _ReferralShareHelper({required this.colors});

  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFFFB522).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.savings_outlined,
            color: Color(0xFFE1A63B),
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            'Invite friends and family to register. Valid referral points can be converted to Goshen wallet cash after eligible registrations are confirmed.',
            style: TextStyle(
              color: colors.muted,
              fontSize: 14,
              height: 1.42,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoshenDateCard extends StatelessWidget {
  const _GoshenDateCard({
    required this.event,
    required this.colors,
  });

  final GoshenRetreatEvent event;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Date',
      icon: Icons.calendar_month_outlined,
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.dateLabel,
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (event.schedules.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...event.schedules.map(
              (schedule) => _ScheduleRow(schedule: schedule, colors: colors),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoshenAddressCard extends StatelessWidget {
  const _GoshenAddressCard({
    required this.event,
    required this.colors,
  });

  final GoshenRetreatEvent event;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    final venueName = event.venueName.trim();
    final venueAddress = event.venueAddress.trim();
    final hasAddress = venueName.isNotEmpty || venueAddress.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: hasAddress ? () => _openGoshenAddress(context, event) : null,
        child: _SectionCard(
          title: 'Address',
          icon: Icons.location_on_outlined,
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasAddress)
                Text(
                  'Venue details will be announced.',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else ...[
                if (venueName.isNotEmpty)
                  Text(
                    venueName,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 17,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (venueName.isNotEmpty && venueAddress.isNotEmpty)
                  const SizedBox(height: 8),
                if (venueAddress.isNotEmpty)
                  Text(
                    venueAddress,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 15,
                      height: 1.42,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      color: Color(0xFFE1A63B),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Open in maps',
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.muted,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GoshenInquiryCard extends StatelessWidget {
  const _GoshenInquiryCard({
    required this.event,
    required this.colors,
  });

  final GoshenRetreatEvent event;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    final phone = event.inquiryPhone.trim();
    if (phone.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _callGoshenInquiry(context, phone),
        child: _SectionCard(
          title: 'Retreat inquiry',
          icon: Icons.call_outlined,
          colors: colors,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  phone,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB522),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phone_in_talk_outlined,
                      color: Color(0xFF0C2230),
                      size: 18,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Call',
                      style: TextStyle(
                        color: Color(0xFF0C2230),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoshenDetailHero extends StatelessWidget {
  const _GoshenDetailHero({
    required this.event,
    required this.colors,
  });

  final GoshenRetreatEvent event;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.24 : 0.1),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GoshenFeatureImage(
            imageUrl: event.featureImageUrl,
            aspectRatio: 16 / 9,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            fallbackIcon: Icons.church_rounded,
            child: Stack(
              children: [
                const Positioned(
                  left: 16,
                  top: 16,
                  child: _GoldPill(text: 'Goshen Retreat'),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: _DarkPill(
                    icon: Icons.calendar_month_outlined,
                    text: event.dateLabel,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name.isEmpty ? 'Goshen Retreat' : event.name,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 28,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  event.description.isEmpty
                      ? 'Register, manage your payment, and prepare for the retreat.'
                      : event.description,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 15,
                    height: 1.42,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                _IconLine(
                  icon: Icons.calendar_month_outlined,
                  text: event.dateLabel,
                  color: colors.text,
                ),
                const SizedBox(height: 10),
                _IconLine(
                  icon: Icons.location_on_outlined,
                  text: event.venueAddress.isNotEmpty
                      ? '${event.venueName}\n${event.venueAddress}'
                      : event.venueName.isEmpty
                          ? 'Venue details will be announced'
                          : event.venueName,
                  color: colors.text,
                ),
                const SizedBox(height: 16),
                _GoshenCountdown(
                  target: event.countdownTarget,
                  colors: colors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoshenFeatureImage extends StatelessWidget {
  const _GoshenFeatureImage({
    required this.imageUrl,
    required this.aspectRatio,
    required this.borderRadius,
    required this.fallbackIcon,
    this.child,
  });

  final String imageUrl;
  final double aspectRatio;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _absoluteMediaUrl(imageUrl);
    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (resolvedUrl.isEmpty)
              _GoshenImageFallback(icon: fallbackIcon)
            else
              CachedNetworkImage(
                imageUrl: resolvedUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => _GoshenImageFallback(
                  icon: fallbackIcon,
                  loading: true,
                ),
                errorWidget: (_, __, ___) =>
                    _GoshenImageFallback(icon: fallbackIcon),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.62),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

class _GoshenImageFallback extends StatelessWidget {
  const _GoshenImageFallback({
    required this.icon,
    this.loading = false,
  });

  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C2230), Color(0xFF14513F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: loading
            ? const CircularProgressIndicator(color: Color(0xFFFFC857))
            : Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.34),
                size: 82,
              ),
      ),
    );
  }
}

class _GoshenCountdown extends StatefulWidget {
  const _GoshenCountdown({
    required this.target,
    required this.colors,
  });

  final DateTime? target;
  final _GoshenPalette colors;

  @override
  State<_GoshenCountdown> createState() => _GoshenCountdownState();
}

class _GoshenCountdownState extends State<_GoshenCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant _GoshenCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    if (widget.target == null || !widget.target!.isAfter(DateTime.now())) {
      return;
    }
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    if (target == null) {
      return _CountdownShell(
        colors: widget.colors,
        title: 'Countdown',
        child: Text(
          'Dates will be announced soon.',
          style: TextStyle(
            color: widget.colors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final now = DateTime.now();
    var remaining = target.difference(now);
    final active = !remaining.isNegative;
    if (!active) remaining = Duration.zero;
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);

    return _CountdownShell(
      colors: widget.colors,
      title: active ? 'Retreat starts in' : 'Retreat date reached',
      child: Row(
        children: [
          _CountdownItem(
            value: days.toString(),
            label: 'Days',
            colors: widget.colors,
          ),
          const SizedBox(width: 8),
          _CountdownItem(
            value: hours.toString().padLeft(2, '0'),
            label: 'Hours',
            colors: widget.colors,
          ),
          const SizedBox(width: 8),
          _CountdownItem(
            value: minutes.toString().padLeft(2, '0'),
            label: 'Mins',
            colors: widget.colors,
          ),
        ],
      ),
    );
  }
}

class _CountdownShell extends StatelessWidget {
  const _CountdownShell({
    required this.colors,
    required this.title,
    required this.child,
  });

  final _GoshenPalette colors;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.innerCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                color: Color(0xFFE1A63B),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CountdownItem extends StatelessWidget {
  const _CountdownItem({
    required this.value,
    required this.label,
    required this.colors,
  });

  final String value;
  final String label;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFFE1A63B),
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PastGoshenVideosSlider extends StatelessWidget {
  const _PastGoshenVideosSlider({
    required this.videos,
    required this.colors,
  });

  final List<GoshenRetreatPastVideo> videos;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * 0.72)
        .clamp(220.0, 320.0)
        .toDouble();
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final height = (320 + ((textScale - 1) * 72)).clamp(320.0, 380.0);

    return _SectionCard(
      title: 'Past Goshen videos',
      icon: Icons.play_circle_outline_rounded,
      colors: colors,
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: videos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return SizedBox(
              width: width,
              child: _PastVideoCard(
                video: videos[index],
                colors: colors,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PastVideoCard extends StatelessWidget {
  const _PastVideoCard({
    required this.video,
    required this.colors,
  });

  final GoshenRetreatPastVideo video;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    final title = video.title.trim().isEmpty
        ? 'Goshen Retreat message'
        : video.title.trim();

    return Material(
      color: colors.innerCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openGoshenVideo(context, video),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GoshenFeatureImage(
                imageUrl: video.thumbnailUrl,
                aspectRatio: 16 / 9,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                fallbackIcon: Icons.smart_display_rounded,
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 10,
                      bottom: 10,
                      child: _DarkPill(
                        icon: Icons.play_circle_outline_rounded,
                        text: 'Play in app',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 15,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (video.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          video.description.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 12,
                            height: 1.28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.smart_display_outlined,
                            color: Color(0xFFE1A63B),
                            size: 18,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Play in app',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetreatEventCard extends StatelessWidget {
  const _RetreatEventCard({
    required this.event,
    required this.colors,
    required this.onTap,
  });

  final GoshenRetreatEvent event;
  final _GoshenPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: colors.isDark ? 0.22 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC857).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_outlined,
                      color: Color(0xFFE1A63B),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 20,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          event.dateLabel,
                          style: TextStyle(
                            color: colors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: colors.muted),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _InfoChip(
                    icon: Icons.local_activity_outlined,
                    text: event.priceLabel,
                    colors: colors,
                  ),
                  _InfoChip(
                    icon: Icons.location_on_outlined,
                    text: event.venueName.isEmpty
                        ? 'Venue pending'
                        : event.venueName,
                    colors: colors,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.colors,
    required this.child,
  });

  final String title;
  final IconData icon;
  final _GoshenPalette colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFE1A63B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.schedule, required this.colors});

  final GoshenRetreatSchedule schedule;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return _CompactRow(
      title:
          schedule.title.isEmpty ? 'Day ${schedule.dayNumber}' : schedule.title,
      subtitle: schedule.timeLabel,
      trailing: schedule.capacity == null ? null : '${schedule.capacity} seats',
      colors: colors,
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.colors});

  final GoshenTicketType ticket;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return _CompactRow(
      title: ticket.name,
      subtitle: 'Min ${ticket.minPerBooking} · Max ${ticket.maxPerBooking}',
      trailing:
          '${ticket.currency} ${ticket.price.toStringAsFixed(ticket.price == ticket.price.roundToDouble() ? 0 : 2)}',
      colors: colors,
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.title,
    required this.subtitle,
    required this.colors,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String? trailing;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.innerCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (trailing != null && trailing!.trim().isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              trailing!,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFE1A63B),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
    required this.colors,
  });

  final IconData icon;
  final String text;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: colors.innerCard,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFE1A63B)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFFFC857), size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoldPill extends StatelessWidget {
  const _GoldPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC857).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFC857),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GoshenEmptyState extends StatelessWidget {
  const _GoshenEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final String message;
  final _GoshenPalette colors;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 74, color: const Color(0xFFE1A63B)),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.text,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.muted, height: 1.45),
        ),
      ],
    );
  }
}

String _absoluteMediaUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '';

  final uri = Uri.tryParse(raw);
  if (uri != null && uri.hasScheme) return raw;
  if (raw.startsWith('//')) return 'https:$raw';

  final base = ApiUrl.BASEURL.endsWith('/')
      ? ApiUrl.BASEURL.substring(0, ApiUrl.BASEURL.length - 1)
      : ApiUrl.BASEURL;
  if (raw.startsWith('/')) return '$base$raw';
  return '$base/$raw';
}

void _openGoshenVideo(
  BuildContext context,
  GoshenRetreatPastVideo video,
) {
  final source = video.youtubeUrl.trim().isNotEmpty
      ? video.youtubeUrl.trim()
      : video.videoId.trim();
  if (source.isEmpty) {
    _showGoshenSnack(
      context,
      'This Goshen video is not playable yet.',
    );
    return;
  }

  final title = video.title.trim().isEmpty
      ? 'Goshen Retreat message'
      : video.title.trim();
  final media = Media(
    id: 0,
    category: 'Goshen Retreat',
    title: title,
    coverPhoto: _absoluteMediaUrl(video.thumbnailUrl),
    mediaType: 'video',
    videoType: 'youtube_video',
    description: video.description,
    downloadUrl: source,
    canPreview: true,
    canDownload: false,
    isFree: true,
    userLiked: false,
    http: true,
    duration: 0,
    commentsCount: 0,
    likesCount: 0,
    previewDuration: 0,
    streamUrl: source,
    viewsCount: 0,
    dateInserted: '',
  );

  Navigator.pushNamed(
    context,
    VideoPlayer.routeName,
    arguments: ScreenArguements(
      position: 0,
      items: media,
      itemsList: <Object?>[media],
    ),
  );
}

Future<void> _shareGoshenEvent(
  BuildContext context,
  GoshenRetreatEvent event, {
  String referralCode = '',
}) async {
  final text = _goshenRetreatShareText(
    event,
    referralCode: referralCode,
  );
  await Share.share(
    text,
    subject: event.name.trim().isEmpty
        ? 'Goshen Retreat invitation'
        : event.name.trim(),
  );
}

Future<void> _copyGoshenEventLink(
  BuildContext context,
  GoshenRetreatEvent event,
) async {
  await Clipboard.setData(
    ClipboardData(text: _goshenRetreatShareUrl(event)),
  );
  if (!context.mounted) return;
  _showGoshenSnack(context, 'Retreat link copied.');
}

Future<void> _copyReferralCode(BuildContext context, String code) async {
  final cleanCode = code.trim();
  if (cleanCode.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: cleanCode));
  if (!context.mounted) return;
  _showGoshenSnack(context, 'Referral code copied.');
}

String _goshenRetreatShareText(
  GoshenRetreatEvent event, {
  String referralCode = '',
}) {
  final venue = [
    event.venueName.trim(),
    event.venueAddress.trim(),
  ].where((value) => value.isNotEmpty).join(', ');
  final cleanReferralCode = referralCode.trim();
  final lines = <String>[
    event.name.trim().isEmpty
        ? 'GOSHEN RETREAT'
        : event.name.trim().toUpperCase(),
    if (event.dateLabel.trim().isNotEmpty) 'Date: ${event.dateLabel}',
    if (venue.isNotEmpty) 'Venue: $venue',
    if (event.priceLabel.trim().isNotEmpty) 'Ticket: ${event.priceLabel}',
    if (cleanReferralCode.isNotEmpty) 'Referral code: $cleanReferralCode',
    'Register here: ${_goshenRetreatShareUrl(event)}',
    'You are invited to join us. Please share with someone.',
  ];

  return lines.join('\n');
}

String _goshenRetreatShareUrl(GoshenRetreatEvent event) {
  final identifier = event.slug.trim().isNotEmpty
      ? event.slug.trim()
      : event.publicId.trim().isNotEmpty
          ? event.publicId.trim()
          : '';
  final base = ApiUrl.BASEURL.endsWith('/')
      ? ApiUrl.BASEURL.substring(0, ApiUrl.BASEURL.length - 1)
      : ApiUrl.BASEURL;

  if (identifier.isEmpty) return '$base/goshen-retreat';
  return '$base/goshen-retreat/${Uri.encodeComponent(identifier)}';
}

Future<void> _openGoshenAddress(
  BuildContext context,
  GoshenRetreatEvent event,
) async {
  final parts = <String>[
    event.venueName.trim(),
    event.venueAddress.trim(),
  ].where((part) => part.isNotEmpty).toList();
  final query = parts.join(', ');
  if (query.isEmpty) return;

  final encoded = Uri.encodeComponent(query);
  final geoUri = Uri.parse('geo:0,0?q=$encoded');
  final mapsUri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$encoded',
  );

  var launched = false;
  try {
    if (await canLaunchUrl(geoUri)) {
      launched = await launchUrl(
        geoUri,
        mode: LaunchMode.externalApplication,
      );
    }
    if (!launched) {
      launched = await launchUrl(
        mapsUri,
        mode: LaunchMode.externalApplication,
      );
    }
  } catch (_) {
    launched = false;
  }

  if (!launched) {
    if (!context.mounted) return;
    _showGoshenSnack(
      context,
      'Could not open maps on this device.',
    );
  }
}

Future<void> _callGoshenInquiry(BuildContext context, String phone) async {
  final dialable = phone.replaceAll(RegExp(r'(?!^\+)[^\d]'), '');
  final target = dialable.isEmpty ? phone.trim() : dialable;
  final uri = Uri(scheme: 'tel', path: target);

  var launched = false;
  try {
    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    launched = false;
  }

  if (!launched) {
    if (!context.mounted) return;
    _showGoshenSnack(
      context,
      'Could not start a phone call on this device.',
    );
  }
}

void _showGoshenSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String _formatScreenMoney(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

Color _colorFromHex(String value) {
  var hex = value.trim().replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  final parsed = int.tryParse(hex, radix: 16);

  return parsed == null ? const Color(0xFFE5E7EB) : Color(parsed);
}

class _GoshenPalette {
  const _GoshenPalette({
    required this.isDark,
    required this.background,
    required this.card,
    required this.innerCard,
    required this.text,
    required this.muted,
    required this.border,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color innerCard;
  final Color text;
  final Color muted;
  final Color border;

  static _GoshenPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _GoshenPalette(
      isDark: isDark,
      background: isDark ? const Color(0xFF071720) : const Color(0xFFF3F8FA),
      card: isDark ? const Color(0xFF102B38) : Colors.white,
      innerCard: isDark ? const Color(0xFF0B202B) : const Color(0xFFF3F7FA),
      text: isDark ? Colors.white : const Color(0xFF0C2230),
      muted: isDark ? Colors.white60 : const Color(0xFF64717B),
      border: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE2EBF0),
    );
  }
}
