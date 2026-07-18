import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/counseling/counseling_screen.dart';
import '../features/fundraising/fundraising_api.dart';
import '../features/fundraising/fundraising_models.dart';
import '../models/GoshenExperience.dart';
import '../models/GoshenQuiz.dart';
import '../models/GoshenRetreat.dart';
import '../models/GoshenWallet.dart';
import '../models/Userdata.dart';
import '../service/GoshenExperienceApi.dart';
import '../service/GoshenQuizApi.dart';
import '../service/GoshenRetreatApi.dart';
import '../service/GoshenWalletApi.dart';
import '../service/ControlHubMessagingApi.dart';
import '../service/ControlHubUsersApi.dart';
import '../wallet_security/wallet_security_guard.dart';
import '../prayers/prayer_point_management_screen.dart';
import 'ChurchEventManagementScreen.dart';
import 'DynamicFormManagementScreen.dart';
import 'GoshenRetreatScreen.dart';
import 'GoshenScannerManagerScreen.dart';
import 'VerseOfDayManagementScreen.dart';

class GoshenManagementHubScreen extends StatefulWidget {
  const GoshenManagementHubScreen({
    super.key,
    required this.user,
    required this.canUseScannerConsole,
    required this.canManageScanners,
    required this.canManageRegistration,
    required this.canManageVouchers,
    required this.canManageFundraising,
    required this.canManageWalletWithdrawals,
    required this.canManageDynamicForms,
    required this.canManageChurchEvents,
    required this.canManageCounseling,
    required this.canSendAdminMessages,
  });

  final Userdata user;
  final bool canUseScannerConsole;
  final bool canManageScanners;
  final bool canManageRegistration;
  final bool canManageVouchers;
  final bool canManageFundraising;
  final bool canManageWalletWithdrawals;
  final bool canManageDynamicForms;
  final bool canManageChurchEvents;
  final bool canManageCounseling;
  final bool canSendAdminMessages;

  @override
  State<GoshenManagementHubScreen> createState() =>
      _GoshenManagementHubScreenState();
}

class _GoshenManagementHubScreenState extends State<GoshenManagementHubScreen> {
  final _api = GoshenRetreatApi();
  late Future<List<GoshenRetreatEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _api.fetchEvents();
  }

  Future<void> _refresh() async {
    final future = _api.fetchEvents();
    setState(() {
      _eventsFuture = future;
    });
    await future;
  }

  bool _canManagePrayerPoints(Userdata user) {
    if (user.isGeneralOverseer ||
        user.canSendAdminMessageTools ||
        user.canManageDynamicFormTools) {
      return true;
    }

    final normalizedRoles = [
      ...user.roles,
      if ((user.role ?? '').trim().isNotEmpty) user.role!,
    ].map((role) => role.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''));

    return normalizedRoles.any((role) => {
          'admin',
          'superadmin',
          'contentmanager',
          'prayermanager',
          'prayerpointsmanager',
          'prayerpointmanager',
          'eventmanager',
          'goshenmanager',
          'generaloverseer',
          'triumphantitmanager',
        }.contains(role));
  }

  bool _canManageVerseOfDay(Userdata user) {
    return user.canManageVerseOfDayTools || _canManagePrayerPoints(user);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Control Hub'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<List<GoshenRetreatEvent>>(
          future: _eventsFuture,
          builder: (context, snapshot) {
            final events = snapshot.data ?? const <GoshenRetreatEvent>[];
            final initialEvent = events.isEmpty ? null : events.first;
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final error = snapshot.hasError
                ? snapshot.error.toString().replaceFirst('Exception: ', '')
                : null;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _ManagementHeroCard(colors: colors),
                if (loading) ...[
                  const SizedBox(height: 18),
                  _LoadingCard(colors: colors, label: 'Loading event tools...'),
                ] else if (error != null) ...[
                  const SizedBox(height: 18),
                  _MessageCard(
                    colors: colors,
                    icon: Icons.cloud_off_rounded,
                    title: 'Event tools need a refresh',
                    message: error,
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  ),
                ],
                const SizedBox(height: 18),
                if (widget.canManageCounseling) ...[
                  _HubActionCard(
                    colors: colors,
                    title: 'Counseling desk',
                    subtitle:
                        'Review private counseling requests, open case threads, and follow up securely.',
                    icon: Icons.health_and_safety_outlined,
                    accent: colors.gold,
                    onTap: () => Navigator.pushNamed(
                      context,
                      CounselingScreen.routeName,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.canManageChurchEvents) ...[
                  _HubActionCard(
                    colors: colors,
                    title: 'Church events',
                    subtitle:
                        'Create, edit, publish, unpublish, delete, and upload event feature images.',
                    icon: Icons.event_available_outlined,
                    accent: colors.gold,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChurchEventManagementScreen(
                          user: widget.user,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _HubActionCard(
                  colors: colors,
                  title: 'Registration stats',
                  subtitle:
                      'Gender, age group, free bus interest, volunteer departments, payments, and attendee tables.',
                  icon: Icons.analytics_outlined,
                  enabled: initialEvent != null && widget.canManageRegistration,
                  disabledSubtitle: initialEvent == null
                      ? 'No retreat event is available yet.'
                      : 'Only event managers can view registration stats.',
                  onTap: initialEvent == null || !widget.canManageRegistration
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GoshenRegistrationStatsScreen(
                                user: widget.user,
                                initialEvent: initialEvent,
                              ),
                            ),
                          ),
                ),
                if (widget.canManageRegistration) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Retreat setup',
                    subtitle:
                        'Review event dates, registration window, schedules, ticket types, and pay-in-full discount setup.',
                    icon: Icons.event_note_outlined,
                    accent: colors.gold,
                    enabled: initialEvent != null,
                    disabledSubtitle: 'No retreat event is available yet.',
                    onTap: initialEvent == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GoshenRetreatSetupScreen(
                                  user: widget.user,
                                  initialEvent: initialEvent,
                                  events: events,
                                ),
                              ),
                            ),
                  ),
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Register member',
                    subtitle:
                        'Create or select a member account, register one ticket, and complete payment with a voucher.',
                    icon: Icons.person_add_alt_1_rounded,
                    accent: colors.teal,
                    enabled: initialEvent != null,
                    disabledSubtitle: 'No retreat event is available yet.',
                    onTap: initialEvent == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GoshenManagedMemberRegistrationScreen(
                                  user: widget.user,
                                  initialEvent: initialEvent,
                                  events: events,
                                ),
                              ),
                            ),
                  ),
                ],
                if (widget.canManageVouchers) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Voucher payments',
                    subtitle:
                        'Generate payment or wallet funding vouchers, verify codes, and review voucher usage.',
                    icon: Icons.confirmation_number_outlined,
                    accent: colors.teal,
                    enabled: initialEvent != null,
                    disabledSubtitle: 'No retreat event is available yet.',
                    onTap: initialEvent == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GoshenVoucherManagementScreen(
                                  user: widget.user,
                                  initialEvent: initialEvent,
                                  events: events,
                                ),
                              ),
                            ),
                  ),
                ],
                if (widget.canManageRegistration) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Accommodation allocations',
                    subtitle:
                        'Assign rooms and beds for attendees with accepted payments and active tickets.',
                    icon: Icons.home_work_outlined,
                    accent: colors.teal,
                    enabled: initialEvent != null,
                    disabledSubtitle: 'No retreat event is available yet.',
                    onTap: initialEvent == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GoshenAccommodationManagementScreen(
                                  user: widget.user,
                                  initialEvent: initialEvent,
                                  events: events,
                                ),
                              ),
                            ),
                  ),
                ],
                if (widget.user.canViewGoshenExperienceStats) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Survey stats',
                    subtitle:
                        'Goshen Experience responses, response rate, and attendee breakdowns.',
                    icon: Icons.query_stats_rounded,
                    accent: colors.teal,
                    enabled: initialEvent != null,
                    disabledSubtitle: 'No retreat event is available yet.',
                    onTap: initialEvent == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GoshenSurveyStatsScreen(
                                  user: widget.user,
                                  initialEvent: initialEvent,
                                  events: events,
                                ),
                              ),
                            ),
                  ),
                ],
                if (widget.user.canManageQuizTools) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Quiz management',
                    subtitle:
                        'Review quiz activity, winner counts, prize status, and open or close quizzes.',
                    icon: Icons.quiz_rounded,
                    accent: colors.gold,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GoshenQuizManagementStatsScreen(user: widget.user),
                      ),
                    ),
                  ),
                ],
                if (widget.canManageFundraising) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Project support stats',
                    subtitle:
                        'Campaign totals, payment channels, contribution status, and recent supporter activity.',
                    icon: Icons.campaign_rounded,
                    accent: colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FundraisingManagementStatsScreen(user: widget.user),
                      ),
                    ),
                  ),
                ],
                if (widget.canManageDynamicForms) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Forms management',
                    subtitle:
                        'Create, edit, activate, deactivate, delete unused forms, and view user submissions.',
                    icon: Icons.dynamic_form_rounded,
                    accent: colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DynamicFormManagementScreen(user: widget.user),
                      ),
                    ),
                  ),
                ],
                if (_canManagePrayerPoints(widget.user)) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Prayer points',
                    subtitle:
                        'Create, edit, publish, unpublish, or delete prayer points shown in the app.',
                    icon: Icons.favorite_border_rounded,
                    accent: colors.gold,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrayerPointManagementScreen(
                          user: widget.user,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_canManageVerseOfDay(widget.user)) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Verse of the Day',
                    subtitle:
                        'Create, edit, publish, unpublish, or delete the daily Bible verse shown in the app.',
                    icon: Icons.menu_book_outlined,
                    accent: colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VerseOfDayManagementScreen(
                          user: widget.user,
                        ),
                      ),
                    ),
                  ),
                ],
                if (widget.canManageWalletWithdrawals) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Wallet withdrawals',
                    subtitle:
                        'Review member withdrawal requests, approve, reject, or mark payouts as paid.',
                    icon: Icons.account_balance_outlined,
                    accent: colors.gold,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GoshenWalletWithdrawalManagementScreen(
                          user: widget.user,
                        ),
                      ),
                    ),
                  ),
                ],
                if (widget.canSendAdminMessages) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Send message',
                    subtitle:
                        'Send an inbox announcement or push notification to app users.',
                    icon: Icons.mark_email_unread_outlined,
                    accent: colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ControlHubMessageSenderScreen(
                          user: widget.user,
                        ),
                      ),
                    ),
                  ),
                ],
                if (widget.user.isGeneralOverseer ||
                    widget.canManageRegistration ||
                    widget.canSendAdminMessages) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Mobile users',
                    subtitle:
                        'Search, add, edit, or delete mobile app user profiles.',
                    icon: Icons.supervised_user_circle_outlined,
                    accent: colors.gold,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ControlHubMobileUsersScreen(user: widget.user),
                      ),
                    ),
                  ),
                ],
                if (widget.canUseScannerConsole) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Scanner Console',
                    subtitle:
                        'Scan QR tickets, search attendees, and sync offline check-ins.',
                    icon: Icons.qr_code_scanner_rounded,
                    accent: colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GoshenScannerScreen(user: widget.user),
                      ),
                    ),
                  ),
                ],
                if (widget.canManageScanners) ...[
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Scanner stats',
                    subtitle:
                        'Check-in progress, gender and age group scanner breakdowns.',
                    icon: Icons.fact_check_outlined,
                    accent: colors.teal,
                    enabled: initialEvent != null,
                    disabledSubtitle: 'No retreat event is available yet.',
                    onTap: initialEvent == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GoshenScannerStatsScreen(
                                  user: widget.user,
                                  initialEvent: initialEvent,
                                  events: events,
                                ),
                              ),
                            ),
                  ),
                  const SizedBox(height: 12),
                  _HubActionCard(
                    colors: colors,
                    title: 'Manage Scanners',
                    subtitle:
                        'Suspend or restore scanner access for event operators.',
                    icon: Icons.manage_accounts_rounded,
                    accent: colors.gold,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GoshenScannerManagerScreen(user: widget.user),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class GoshenRetreatSetupScreen extends StatefulWidget {
  const GoshenRetreatSetupScreen({
    super.key,
    required this.user,
    required this.initialEvent,
    required this.events,
  });

  final Userdata user;
  final GoshenRetreatEvent initialEvent;
  final List<GoshenRetreatEvent> events;

  @override
  State<GoshenRetreatSetupScreen> createState() =>
      _GoshenRetreatSetupScreenState();
}

class _GoshenRetreatSetupScreenState extends State<GoshenRetreatSetupScreen> {
  final _api = GoshenRetreatApi();
  late List<GoshenRetreatEvent> _events;
  late GoshenRetreatEvent _selectedEvent;
  late Future<GoshenRetreatEvent> _future;

  @override
  void initState() {
    super.initState();
    _events = widget.events.isEmpty ? [widget.initialEvent] : widget.events;
    _selectedEvent = _events.firstWhere(
      (event) => event.publicId == widget.initialEvent.publicId,
      orElse: () => widget.initialEvent,
    );
    _future = _loadSetup(_selectedEvent);
  }

  Future<GoshenRetreatEvent> _loadSetup(GoshenRetreatEvent event) async {
    final updated = await _api.fetchRetreatSetup(
      user: widget.user,
      event: event,
    );
    if (mounted) {
      setState(() => _replaceEvent(updated));
    }
    return updated;
  }

  Future<void> _refresh() async {
    final future = _api.fetchRetreatSetup(
      user: widget.user,
      event: _selectedEvent,
    );
    setState(() {
      _future = future;
    });
    try {
      final updated = await future;
      if (!mounted) return;
      setState(() => _replaceEvent(updated));
    } catch (_) {
      // FutureBuilder renders the error state.
    }
  }

  void _replaceEvent(GoshenRetreatEvent updated) {
    final index =
        _events.indexWhere((event) => event.publicId == updated.publicId);
    if (index >= 0) {
      _events = [
        for (var i = 0; i < _events.length; i += 1)
          if (i == index) updated else _events[i],
      ];
    } else {
      _events = [updated, ..._events];
    }
    _selectedEvent = updated;
  }

  void _applyUpdatedEvent(GoshenRetreatEvent updated, String message) {
    if (!mounted) return;
    setState(() {
      _replaceEvent(updated);
      _future = Future.value(updated);
    });
    _showSnack(message);
  }

  void _selectEvent(String? publicId) {
    final selected = _events.firstWhere(
      (event) => event.publicId == publicId,
      orElse: () => _selectedEvent,
    );
    setState(() {
      _selectedEvent = selected;
      _future = _loadSetup(selected);
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openOverviewEditor() async {
    final updated = await _showOverviewEditor(context, _selectedEvent);
    if (updated != null) _applyUpdatedEvent(updated, 'Retreat setup saved.');
  }

  Future<void> _openScheduleEditor([GoshenRetreatSchedule? schedule]) async {
    final updated =
        await _showScheduleEditor(context, _selectedEvent, schedule);
    if (updated != null) _applyUpdatedEvent(updated, 'Schedule saved.');
  }

  Future<void> _deleteSchedule(GoshenRetreatSchedule schedule) async {
    if (schedule.id <= 0) return;
    final confirmed = await _confirmDelete(
      title: 'Delete schedule?',
      message: 'This removes the schedule row from the retreat setup.',
    );
    if (!confirmed) return;
    try {
      final updated = await _api.deleteRetreatSetupSchedule(
        user: widget.user,
        event: _selectedEvent,
        scheduleId: schedule.id,
      );
      _applyUpdatedEvent(updated, 'Schedule deleted.');
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openTicketEditor([GoshenTicketType? ticket]) async {
    final updated = await _showTicketEditor(context, _selectedEvent, ticket);
    if (updated != null) _applyUpdatedEvent(updated, 'Ticket type saved.');
  }

  Future<void> _deleteTicket(GoshenTicketType ticket) async {
    final ticketId =
        ticket.publicId.isNotEmpty ? ticket.publicId : '${ticket.id}';
    if (ticketId.trim().isEmpty || ticketId == '0') return;
    final confirmed = await _confirmDelete(
      title: 'Delete ticket type?',
      message:
          'Ticket types with registrations cannot be deleted. Deactivate them instead.',
    );
    if (!confirmed) return;
    try {
      final updated = await _api.deleteRetreatSetupTicketType(
        user: widget.user,
        event: _selectedEvent,
        ticketTypeId: ticketId,
      );
      _applyUpdatedEvent(updated, 'Ticket type deleted.');
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openRegistrationFieldEditor(
      [GoshenRegistrationField? field]) async {
    final updated = await _showRegistrationFieldEditor(
      context,
      _selectedEvent,
      field,
    );
    if (updated != null) {
      _applyUpdatedEvent(updated, 'Registration field saved.');
    }
  }

  Future<void> _deleteRegistrationField(GoshenRegistrationField field) async {
    if (field.id <= 0) return;
    final confirmed = await _confirmDelete(
      title: 'Delete registration field?',
      message:
          'Existing submitted answers remain in registration records, but the field will no longer appear on the form.',
    );
    if (!confirmed) return;
    try {
      final updated = await _api.deleteRetreatSetupRegistrationField(
        user: widget.user,
        event: _selectedEvent,
        fieldId: field.id,
      );
      _applyUpdatedEvent(updated, 'Registration field deleted.');
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _pickDateTimeInto(TextEditingController controller) async {
    final parsed = DateTime.tryParse(controller.text.trim());
    final now = DateTime.now();
    final initial = parsed ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    controller.text = _dateInput(DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ));
  }

  Future<GoshenRetreatEvent?> _showOverviewEditor(
    BuildContext context,
    GoshenRetreatEvent event,
  ) async {
    final colors = _ManagementPalette.of(context);
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: event.name);
    final slug = TextEditingController(text: event.slug);
    final description = TextEditingController(text: event.description);
    final timezone = TextEditingController(text: event.timezone);
    final supportEmail = TextEditingController(text: event.supportEmail);
    final inquiryPhone = TextEditingController(text: event.inquiryPhone);
    final venueName = TextEditingController(text: event.venueName);
    final venueAddress = TextEditingController(text: event.venueAddress);
    final salesStart =
        TextEditingController(text: _dateInput(event.salesStartAt));
    final salesEnd = TextEditingController(text: _dateInput(event.salesEndAt));
    final closeReason =
        TextEditingController(text: event.registration.closedReason);
    final discountLabel =
        TextEditingController(text: event.payInFullDiscount.label);
    final discountValue = TextEditingController(
        text: _decimalInput(event.payInFullDiscount.value));
    final discountStarts = TextEditingController(
        text: _dateInput(event.payInFullDiscount.startsAt));
    final discountEnds =
        TextEditingController(text: _dateInput(event.payInFullDiscount.endsAt));
    var registrationOverride =
        ['auto', 'open', 'closed'].contains(event.registration.override)
            ? event.registration.override
            : 'auto';
    var discountEnabled = event.payInFullDiscount.enabled;
    var discountType =
        ['percentage', 'fixed'].contains(event.payInFullDiscount.type)
            ? event.payInFullDiscount.type
            : 'percentage';
    var saving = false;

    final result = await showModalBottomSheet<GoshenRetreatEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            Future<void> save() async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              setModalState(() => saving = true);
              try {
                final updated = await _api.saveRetreatSetupOverview(
                  user: widget.user,
                  event: event,
                  payload: {
                    'name': name.text.trim(),
                    'slug': slug.text.trim(),
                    'description': description.text.trim(),
                    'timezone': timezone.text.trim(),
                    'support_email': supportEmail.text.trim(),
                    'inquiry_phone': inquiryPhone.text.trim(),
                    'venue_name': venueName.text.trim(),
                    'venue_address': venueAddress.text.trim(),
                    'sales_start_at': _nullableTextValue(salesStart.text),
                    'sales_end_at': _nullableTextValue(salesEnd.text),
                    'registration_override': registrationOverride,
                    'registration_close_reason': closeReason.text.trim(),
                    'pay_in_full_discount': {
                      'enabled': discountEnabled,
                      'label': discountLabel.text.trim(),
                      'type': discountType,
                      'value': double.tryParse(discountValue.text.trim()) ?? 0,
                      'starts_at': _nullableTextValue(discountStarts.text),
                      'ends_at': _nullableTextValue(discountEnds.text),
                    },
                  },
                );
                if (sheetContext.mounted) Navigator.pop(sheetContext, updated);
              } catch (error) {
                _showSnack(error.toString().replaceFirst('Exception: ', ''));
              } finally {
                if (sheetContext.mounted) {
                  setModalState(() => saving = false);
                }
              }
            }

            return _setupSheet(
              context: sheetContext,
              colors: colors,
              title: 'Edit retreat setup',
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _setupTextField(
                      colors: colors,
                      controller: name,
                      label: 'Edition name',
                      validator: _requiredValidator,
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: slug,
                      label: 'Slug',
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: description,
                      label: 'Description',
                      minLines: 3,
                      maxLines: 5,
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: timezone,
                      label: 'Timezone',
                      validator: _requiredValidator,
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: supportEmail,
                      label: 'Support email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: inquiryPhone,
                      label: 'Inquiry phone',
                      keyboardType: TextInputType.phone,
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: venueName,
                      label: 'Venue name',
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: venueAddress,
                      label: 'Venue address',
                      minLines: 2,
                      maxLines: 4,
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: salesStart,
                      label: 'Registration opens',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today_outlined),
                        onPressed: () => _pickDateTimeInto(salesStart),
                      ),
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: salesEnd,
                      label: 'Registration closes',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today_outlined),
                        onPressed: () => _pickDateTimeInto(salesEnd),
                      ),
                    ),
                    _setupDropdown(
                      colors: colors,
                      label: 'Manual registration status',
                      value: registrationOverride,
                      values: const {
                        'auto': 'Use dates',
                        'open': 'Force open',
                        'closed': 'Force closed',
                      },
                      onChanged: (value) =>
                          setModalState(() => registrationOverride = value),
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: closeReason,
                      label: 'Closed message',
                      minLines: 2,
                      maxLines: 3,
                    ),
                    SwitchListTile.adaptive(
                      value: discountEnabled,
                      onChanged: (value) =>
                          setModalState(() => discountEnabled = value),
                      title: const Text('Enable pay-in-full discount'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: discountLabel,
                      label: 'Discount label',
                    ),
                    _setupDropdown(
                      colors: colors,
                      label: 'Discount type',
                      value: discountType,
                      values: const {
                        'percentage': 'Percentage',
                        'fixed': 'Fixed amount',
                      },
                      onChanged: (value) =>
                          setModalState(() => discountType = value),
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: discountValue,
                      label: 'Discount value',
                      keyboardType: TextInputType.number,
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: discountStarts,
                      label: 'Discount starts',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today_outlined),
                        onPressed: () => _pickDateTimeInto(discountStarts),
                      ),
                    ),
                    _setupTextField(
                      colors: colors,
                      controller: discountEnds,
                      label: 'Discount ends',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today_outlined),
                        onPressed: () => _pickDateTimeInto(discountEnds),
                      ),
                    ),
                    _setupSaveButton(
                      colors: colors,
                      saving: saving,
                      label: 'Save setup',
                      onPressed: save,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    for (final controller in [
      name,
      slug,
      description,
      timezone,
      supportEmail,
      inquiryPhone,
      venueName,
      venueAddress,
      salesStart,
      salesEnd,
      closeReason,
      discountLabel,
      discountValue,
      discountStarts,
      discountEnds,
    ]) {
      controller.dispose();
    }

    return result;
  }

  Future<GoshenRetreatEvent?> _showScheduleEditor(
    BuildContext context,
    GoshenRetreatEvent event,
    GoshenRetreatSchedule? schedule,
  ) async {
    final colors = _ManagementPalette.of(context);
    final formKey = GlobalKey<FormState>();
    final day = TextEditingController(text: '${schedule?.dayNumber ?? 1}');
    final title = TextEditingController(text: schedule?.title ?? '');
    final startsAt =
        TextEditingController(text: _dateInput(schedule?.startsAt));
    final endsAt = TextEditingController(text: _dateInput(schedule?.endsAt));
    final capacity = TextEditingController(
      text: schedule?.capacity == null ? '' : '${schedule!.capacity}',
    );
    var saving = false;

    final result = await showModalBottomSheet<GoshenRetreatEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          Future<void> save() async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            setModalState(() => saving = true);
            try {
              final updated = await _api.saveRetreatSetupSchedule(
                user: widget.user,
                event: event,
                payload: {
                  if ((schedule?.id ?? 0) > 0) 'id': schedule!.id,
                  'day_number': int.tryParse(day.text.trim()) ?? 1,
                  'title': title.text.trim(),
                  'starts_at': startsAt.text.trim(),
                  'ends_at': _nullableTextValue(endsAt.text),
                  'capacity': capacity.text.trim().isEmpty
                      ? null
                      : int.tryParse(capacity.text.trim()),
                },
              );
              if (sheetContext.mounted) Navigator.pop(sheetContext, updated);
            } catch (error) {
              _showSnack(error.toString().replaceFirst('Exception: ', ''));
            } finally {
              if (sheetContext.mounted) setModalState(() => saving = false);
            }
          }

          return _setupSheet(
            context: sheetContext,
            colors: colors,
            title: schedule == null ? 'Add schedule' : 'Edit schedule',
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _setupTextField(
                    colors: colors,
                    controller: day,
                    label: 'Day number',
                    keyboardType: TextInputType.number,
                    validator: _requiredValidator,
                  ),
                  _setupTextField(
                    colors: colors,
                    controller: title,
                    label: 'Session title',
                  ),
                  _setupTextField(
                    colors: colors,
                    controller: startsAt,
                    label: 'Starts at',
                    validator: _requiredValidator,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: () => _pickDateTimeInto(startsAt),
                    ),
                  ),
                  _setupTextField(
                    colors: colors,
                    controller: endsAt,
                    label: 'Ends at',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: () => _pickDateTimeInto(endsAt),
                    ),
                  ),
                  _setupTextField(
                    colors: colors,
                    controller: capacity,
                    label: 'Capacity',
                    keyboardType: TextInputType.number,
                  ),
                  _setupSaveButton(
                    colors: colors,
                    saving: saving,
                    label: 'Save schedule',
                    onPressed: save,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    for (final controller in [day, title, startsAt, endsAt, capacity]) {
      controller.dispose();
    }
    return result;
  }

  Future<GoshenRetreatEvent?> _showTicketEditor(
    BuildContext context,
    GoshenRetreatEvent event,
    GoshenTicketType? ticket,
  ) async {
    final colors = _ManagementPalette.of(context);
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: ticket?.name ?? '');
    final sku = TextEditingController(text: ticket?.sku ?? '');
    final currency = TextEditingController(text: ticket?.currency ?? 'GBP');
    final price = TextEditingController(
        text: ticket == null ? '' : _decimalInput(ticket.price));
    final capacity = TextEditingController(
      text: ticket?.capacity == null ? '' : '${ticket!.capacity}',
    );
    final minPerBooking =
        TextEditingController(text: '${ticket?.minPerBooking ?? 1}');
    final maxPerBooking =
        TextEditingController(text: '${ticket?.maxPerBooking ?? 1}');
    var active = ticket?.isActive ?? true;
    var saving = false;

    final result = await showModalBottomSheet<GoshenRetreatEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          Future<void> save() async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            setModalState(() => saving = true);
            try {
              final updated = await _api.saveRetreatSetupTicketType(
                user: widget.user,
                event: event,
                payload: {
                  if (ticket != null)
                    'id': ticket.publicId.isNotEmpty
                        ? ticket.publicId
                        : '${ticket.id}',
                  'name': name.text.trim(),
                  'sku': sku.text.trim(),
                  'currency': currency.text.trim().toUpperCase(),
                  'price': double.tryParse(price.text.trim()) ?? 0,
                  'capacity': capacity.text.trim().isEmpty
                      ? null
                      : int.tryParse(capacity.text.trim()),
                  'min_per_booking':
                      int.tryParse(minPerBooking.text.trim()) ?? 1,
                  'max_per_booking':
                      int.tryParse(maxPerBooking.text.trim()) ?? 1,
                  'is_active': active,
                },
              );
              if (sheetContext.mounted) Navigator.pop(sheetContext, updated);
            } catch (error) {
              _showSnack(error.toString().replaceFirst('Exception: ', ''));
            } finally {
              if (sheetContext.mounted) setModalState(() => saving = false);
            }
          }

          return _setupSheet(
            context: sheetContext,
            colors: colors,
            title: ticket == null ? 'Add ticket type' : 'Edit ticket type',
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _setupTextField(
                    colors: colors,
                    controller: name,
                    label: 'Ticket name',
                    validator: _requiredValidator,
                  ),
                  _setupTextField(
                      colors: colors, controller: sku, label: 'SKU'),
                  _setupTextField(
                    colors: colors,
                    controller: currency,
                    label: 'Currency',
                    validator: _requiredValidator,
                  ),
                  _setupTextField(
                    colors: colors,
                    controller: price,
                    label: 'Price',
                    keyboardType: TextInputType.number,
                    validator: _requiredValidator,
                  ),
                  _setupTextField(
                    colors: colors,
                    controller: capacity,
                    label: 'Capacity',
                    keyboardType: TextInputType.number,
                  ),
                  _setupTextField(
                    colors: colors,
                    controller: minPerBooking,
                    label: 'Minimum per booking',
                    keyboardType: TextInputType.number,
                  ),
                  _setupTextField(
                    colors: colors,
                    controller: maxPerBooking,
                    label: 'Maximum per booking',
                    keyboardType: TextInputType.number,
                  ),
                  SwitchListTile.adaptive(
                    value: active,
                    onChanged: (value) => setModalState(() => active = value),
                    title: const Text('Ticket active'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  _setupSaveButton(
                    colors: colors,
                    saving: saving,
                    label: 'Save ticket',
                    onPressed: save,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    for (final controller in [
      name,
      sku,
      currency,
      price,
      capacity,
      minPerBooking,
      maxPerBooking,
    ]) {
      controller.dispose();
    }
    return result;
  }

  Future<GoshenRetreatEvent?> _showRegistrationFieldEditor(
    BuildContext context,
    GoshenRetreatEvent event,
    GoshenRegistrationField? field,
  ) async {
    final colors = _ManagementPalette.of(context);
    final formKey = GlobalKey<FormState>();
    final key = TextEditingController(text: field?.key ?? '');
    final label = TextEditingController(text: field?.label ?? '');
    final sortOrder = TextEditingController(text: '${field?.sortOrder ?? 0}');
    final options = TextEditingController(
        text: _optionsToLines(field?.options ?? const []));
    var type = _setupFieldTypes.contains(field?.type) ? field!.type : 'text';
    var isRequired = field?.isRequired ?? false;
    var unique = field?.isUnique ?? false;
    var saving = false;

    final result = await showModalBottomSheet<GoshenRetreatEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          Future<void> save() async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            setModalState(() => saving = true);
            try {
              final updated = await _api.saveRetreatSetupRegistrationField(
                user: widget.user,
                event: event,
                payload: {
                  if ((field?.id ?? 0) > 0) 'id': field!.id,
                  'key': key.text.trim(),
                  'label': label.text.trim(),
                  'type': type,
                  'is_required': isRequired,
                  'is_unique': unique,
                  'sort_order': int.tryParse(sortOrder.text.trim()) ?? 0,
                  'options': _parseOptionsLines(options.text),
                },
              );
              if (sheetContext.mounted) Navigator.pop(sheetContext, updated);
            } catch (error) {
              _showSnack(error.toString().replaceFirst('Exception: ', ''));
            } finally {
              if (sheetContext.mounted) setModalState(() => saving = false);
            }
          }

          return _setupSheet(
            context: sheetContext,
            colors: colors,
            title: field == null
                ? 'Add registration field'
                : 'Edit registration field',
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _setupTextField(
                    colors: colors,
                    controller: label,
                    label: 'Field label',
                    validator: _requiredValidator,
                  ),
                  _setupTextField(
                    colors: colors,
                    controller: key,
                    label: 'Field key',
                    validator: _requiredValidator,
                  ),
                  _setupDropdown(
                    colors: colors,
                    label: 'Field type',
                    value: type,
                    values: const {
                      'text': 'Text',
                      'textarea': 'Long text',
                      'select': 'Dropdown',
                      'image_select': 'Image choices',
                      'color_select': 'Colour choices',
                    },
                    onChanged: (value) => setModalState(() => type = value),
                  ),
                  SwitchListTile.adaptive(
                    value: isRequired,
                    onChanged: (value) =>
                        setModalState(() => isRequired = value),
                    title: const Text('Required'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile.adaptive(
                    value: unique,
                    onChanged: (value) => setModalState(() => unique = value),
                    title: const Text('Unique per attendee'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  _setupTextField(
                    colors: colors,
                    controller: sortOrder,
                    label: 'Sort order',
                    keyboardType: TextInputType.number,
                  ),
                  _setupTextField(
                    colors: colors,
                    controller: options,
                    label: 'Options',
                    minLines: 4,
                    maxLines: 8,
                    helperText:
                        'One per line: label|value|image path|#colour|fee|fee label',
                  ),
                  _setupSaveButton(
                    colors: colors,
                    saving: saving,
                    label: 'Save field',
                    onPressed: save,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    for (final controller in [key, label, sortOrder, options]) {
      controller.dispose();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Retreat Setup'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<GoshenRetreatEvent>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _LoadingCard(
                    colors: colors,
                    label: 'Loading retreat setup...',
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _MessageCard(
                    colors: colors,
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load retreat setup',
                    message: snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  ),
                ],
              );
            }

            final event = snapshot.data ?? _selectedEvent;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _EventSelector(
                  colors: colors,
                  events: _events,
                  selected: event,
                  onChanged: _selectEvent,
                ),
                const SizedBox(height: 14),
                _RetreatSetupOverviewCard(
                  colors: colors,
                  event: event,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _openOverviewEditor,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit overview'),
                  ),
                ),
                const SizedBox(height: 14),
                _RetreatSetupMetricsGrid(
                  colors: colors,
                  event: event,
                ),
                const SizedBox(height: 14),
                _RetreatSetupSchedulesManagerCard(
                  colors: colors,
                  schedules: event.schedules,
                  onAdd: () => _openScheduleEditor(),
                  onEdit: _openScheduleEditor,
                  onDelete: _deleteSchedule,
                ),
                const SizedBox(height: 14),
                _RetreatSetupTicketTypesManagerCard(
                  colors: colors,
                  ticketTypes: event.ticketTypes,
                  onAdd: () => _openTicketEditor(),
                  onEdit: _openTicketEditor,
                  onDelete: _deleteTicket,
                ),
                const SizedBox(height: 14),
                _RetreatSetupRegistrationFieldsCard(
                  colors: colors,
                  fields: event.registrationFields,
                  onAdd: () => _openRegistrationFieldEditor(),
                  onEdit: _openRegistrationFieldEditor,
                  onDelete: _deleteRegistrationField,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class GoshenVoucherManagementScreen extends StatefulWidget {
  const GoshenVoucherManagementScreen({
    super.key,
    required this.user,
    required this.initialEvent,
    required this.events,
  });

  final Userdata user;
  final GoshenRetreatEvent initialEvent;
  final List<GoshenRetreatEvent> events;

  @override
  State<GoshenVoucherManagementScreen> createState() =>
      _GoshenVoucherManagementScreenState();
}

class _GoshenVoucherManagementScreenState
    extends State<GoshenVoucherManagementScreen> {
  final _api = GoshenRetreatApi();
  final _verifyController = TextEditingController();
  final _labelController = TextEditingController(text: 'Offline cash voucher');
  final _amountController = TextEditingController();
  final _currencyController = TextEditingController(text: 'GBP');
  final _quantityController = TextEditingController(text: '1');
  final _maxUsesController = TextEditingController(text: '1');

  late List<GoshenRetreatEvent> _events;
  late GoshenRetreatEvent _selectedEvent;
  late Future<List<GoshenVoucherUsage>> _usageFuture;
  String _purpose = GoshenVoucherInfo.purposePayments;
  String _redemptionType = GoshenVoucherInfo.redemptionFixed;
  bool _generating = false;
  bool _verifying = false;
  GoshenVoucherVerification? _verification;
  List<GoshenGeneratedVoucher> _generated = const [];

  @override
  void initState() {
    super.initState();
    _events = widget.events.isEmpty ? [widget.initialEvent] : widget.events;
    _selectedEvent = _events.firstWhere(
      (event) => event.publicId == widget.initialEvent.publicId,
      orElse: () => widget.initialEvent,
    );
    _usageFuture = _loadUsages();
  }

  @override
  void dispose() {
    _verifyController.dispose();
    _labelController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _quantityController.dispose();
    _maxUsesController.dispose();
    super.dispose();
  }

  Future<List<GoshenVoucherUsage>> _loadUsages() {
    return _api.fetchVoucherUsages(
      user: widget.user,
      event: _selectedEvent,
      limit: 100,
    );
  }

  Future<void> _refresh() async {
    final future = _loadUsages();
    setState(() {
      _usageFuture = future;
    });
    await future;
  }

  void _selectEvent(String? publicId) {
    final selected = _events.firstWhere(
      (event) => event.publicId == publicId,
      orElse: () => _selectedEvent,
    );
    setState(() {
      _selectedEvent = selected;
      _verification = null;
      _generated = const [];
      _usageFuture = _loadUsages();
    });
  }

  void _selectPurpose(String purpose) {
    setState(() {
      _purpose = purpose;
      if (purpose == GoshenVoucherInfo.purposeWalletFunding) {
        _redemptionType = GoshenVoucherInfo.redemptionFixed;
        _maxUsesController.text = '1';
      }
      _generated = const [];
    });
  }

  void _selectRedemptionType(String redemptionType) {
    setState(() {
      _redemptionType = redemptionType;
      if (redemptionType == GoshenVoucherInfo.redemptionPool &&
          _maxUsesController.text.trim() == '1') {
        _maxUsesController.text = '1000';
      }
      _generated = const [];
    });
  }

  Future<void> _verifyVoucher() async {
    final code = _verifyController.text.trim();
    if (code.isEmpty) {
      _showSnack('Enter a voucher code to verify.');
      return;
    }

    setState(() {
      _verifying = true;
      _verification = null;
    });

    try {
      final result = await _api.verifyVoucher(
        user: widget.user,
        voucherCode: code,
        event: _selectedEvent,
      );
      if (!mounted) return;
      setState(() => _verification = result);
    } catch (error) {
      if (!mounted) return;
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _generateVouchers() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final currency = _currencyController.text.trim().toUpperCase();
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    final enteredMaxUses = int.tryParse(_maxUsesController.text.trim()) ?? 1;
    final maxUses = _redemptionType == GoshenVoucherInfo.redemptionPool &&
            enteredMaxUses <= 1
        ? 1000
        : enteredMaxUses;

    if (amount <= 0 || currency.length != 3) {
      _showSnack('Enter a valid amount and 3-letter currency.');
      return;
    }

    final unlocked = await WalletSecurityGuard.ensureWalletUnlocked(
      context,
      requireFreshVerification: true,
    );
    if (!unlocked || !mounted) return;

    setState(() => _generating = true);
    try {
      final generated = await _api.generateVouchers(
        user: widget.user,
        event: _purpose == GoshenVoucherInfo.purposePayments
            ? _selectedEvent
            : null,
        label: _labelController.text,
        amount: amount,
        currency: currency,
        quantity: quantity.clamp(1, 200).toInt(),
        purpose: _purpose,
        redemptionType: _redemptionType,
        maxUses: maxUses.clamp(1, 1000).toInt(),
      );
      if (!mounted) return;
      setState(() {
        _generated = generated;
        _usageFuture = _loadUsages();
      });
      _showSnack('${generated.length} voucher code(s) generated.');
    } catch (error) {
      if (!mounted) return;
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _copyGeneratedCodes() async {
    final text = _generated.map((item) => item.code).join('\n');
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('Voucher codes copied.');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Voucher Payments'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            32 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            _EventSelector(
              colors: colors,
              events: _events,
              selected: _selectedEvent,
              onChanged: _selectEvent,
            ),
            const SizedBox(height: 14),
            _VoucherVerifyPanel(
              colors: colors,
              controller: _verifyController,
              verifying: _verifying,
              verification: _verification,
              onVerify: _verifyVoucher,
            ),
            const SizedBox(height: 14),
            _VoucherGeneratePanel(
              colors: colors,
              labelController: _labelController,
              amountController: _amountController,
              currencyController: _currencyController,
              quantityController: _quantityController,
              maxUsesController: _maxUsesController,
              purpose: _purpose,
              redemptionType: _redemptionType,
              generating: _generating,
              generated: _generated,
              onPurposeChanged: _selectPurpose,
              onRedemptionTypeChanged: _selectRedemptionType,
              onGenerate: _generateVouchers,
              onCopyGenerated: _copyGeneratedCodes,
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<GoshenVoucherUsage>>(
              future: _usageFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return _LoadingCard(
                    colors: colors,
                    label: 'Loading voucher usage...',
                  );
                }

                if (snapshot.hasError) {
                  return _MessageCard(
                    colors: colors,
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load voucher usage',
                    message: snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  );
                }

                return _VoucherUsagePanel(
                  colors: colors,
                  rows: snapshot.data ?? const [],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class GoshenManagedMemberRegistrationScreen extends StatefulWidget {
  const GoshenManagedMemberRegistrationScreen({
    super.key,
    required this.user,
    required this.initialEvent,
    required this.events,
  });

  final Userdata user;
  final GoshenRetreatEvent initialEvent;
  final List<GoshenRetreatEvent> events;

  @override
  State<GoshenManagedMemberRegistrationScreen> createState() =>
      _GoshenManagedMemberRegistrationScreenState();
}

class _GoshenManagedMemberRegistrationScreenState
    extends State<GoshenManagedMemberRegistrationScreen> {
  final _api = GoshenRetreatApi();
  final _searchController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController(text: 'United Kingdom');
  final _stateController = TextEditingController();
  final _addressController = TextEditingController();
  final _voucherController = TextEditingController();

  late List<GoshenRetreatEvent> _events;
  late GoshenRetreatEvent _selectedEvent;
  GoshenTicketType? _selectedTicketType;
  GoshenManagedMember? _selectedMember;
  List<GoshenManagedMember> _members = const [];
  String _managedProfileTitle = '';
  String _managedMaritalStatus = '';
  String _gender = 'male';
  String _memberType = 'visitor';
  String _ageGroup = 'adult';
  String _busInterest = 'no_thanks';
  String _volunteerDepartment = 'no_chance_at_the_moment';
  bool _searching = false;
  bool _savingMember = false;
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    _events = widget.events.isEmpty ? [widget.initialEvent] : widget.events;
    _selectedEvent = _events.firstWhere(
      (event) => event.publicId == widget.initialEvent.publicId,
      orElse: () => widget.initialEvent,
    );
    _selectedTicketType = _selectedEvent.ticketTypes.isEmpty
        ? null
        : _selectedEvent.ticketTypes.first;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _addressController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  void _selectEvent(String? publicId) {
    final selected = _events.firstWhere(
      (event) => event.publicId == publicId,
      orElse: () => _selectedEvent,
    );
    setState(() {
      _selectedEvent = selected;
      _selectedTicketType =
          selected.ticketTypes.isEmpty ? null : selected.ticketTypes.first;
    });
  }

  Future<void> _searchMembers() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _searching = true);
    try {
      final members = await _api.searchManagedMembers(
        user: widget.user,
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() => _members = members);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _createMember() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_managedProfileTitle.trim().isEmpty ||
        _managedMaritalStatus.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Select member title and marital status first.'),
        ),
      );
      return;
    }
    setState(() => _savingMember = true);
    try {
      final member = await _api.createManagedMember(
        user: widget.user,
        member: {
          'profile_title': _managedProfileTitle,
          'salutation': _managedProfileTitle,
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'gender': _gender,
          'marital_status': _managedMaritalStatus,
          'member_type': _memberType,
          'country_of_residence': _countryController.text.trim(),
          'state_county_province': _stateController.text.trim(),
          'address': _addressController.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _selectedMember = member;
        _members = [member, ..._members];
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Member profile created and selected.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingMember = false);
    }
  }

  Future<void> _registerMember() async {
    final member = _selectedMember;
    final ticketType = _selectedTicketType;
    final messenger = ScaffoldMessenger.of(context);
    if (member == null || ticketType == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Select a member and ticket type first.')),
      );
      return;
    }
    if (!member.profileComplete) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Complete member profile first: ${member.profileMissingFields.join(', ')}.',
          ),
        ),
      );
      return;
    }
    if (_voucherController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a voucher code.')),
      );
      return;
    }

    setState(() => _registering = true);
    try {
      await _api.startBooking(
        event: _selectedEvent,
        ticketType: ticketType,
        quantity: 1,
        user: widget.user,
        managedMemberId: member.id,
        paymentMode: 'voucher',
        voucherCode: _voucherController.text,
        ukPrivacyConsent: true,
        freeChurchBusConsent: _busInterest == 'yes',
        attendees: [
          {
            'first_name': member.firstName,
            'last_name': member.lastName,
            'email': member.email,
            'phone': member.phone,
            'gender': member.gender.trim().isEmpty ? _gender : member.gender,
            'age_group': _ageGroup,
            'free_church_bus_interest': _busInterest,
            'volunteer_department': _volunteerDepartment,
          }
        ],
      );
      if (!mounted) return;
      _voucherController.clear();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${member.displayName} has been registered.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Register Member'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          _EventSelector(
            colors: colors,
            events: _events,
            selected: _selectedEvent,
            onChanged: _selectEvent,
          ),
          const SizedBox(height: 14),
          _Panel(
            colors: colors,
            title: 'Find member',
            subtitle: 'Search by name, email, phone, or Triumphant ID.',
            child: Column(
              children: [
                _VoucherTextField(
                  controller: _searchController,
                  label: 'Name, email, phone, or Triumphant ID',
                  icon: Icons.search_rounded,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _searching ? null : _searchMembers,
                    icon: _searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded),
                    label: const Text('Search members'),
                  ),
                ),
                if (_members.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._members.map(
                    (member) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: colors.gold.withValues(alpha: 0.16),
                        child: Icon(Icons.person_rounded, color: colors.deep),
                      ),
                      title: Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: _ManagedMemberSubtitle(
                          member: member, colors: colors),
                      trailing: member.id == _selectedMember?.id
                          ? Icon(Icons.check_circle_rounded,
                              color: colors.success)
                          : null,
                      onTap: () => setState(() => _selectedMember = member),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            colors: colors,
            title: 'Create member',
            subtitle: 'Use this when the member does not already exist.',
            child: Column(
              children: [
                _VoucherTextField(
                  controller: _firstNameController,
                  label: 'First name',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 10),
                _VoucherTextField(
                  controller: _lastNameController,
                  label: 'Last name',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 10),
                _VoucherTextField(
                  controller: _emailController,
                  label: 'Email address',
                  icon: Icons.mail_outline_rounded,
                ),
                const SizedBox(height: 10),
                _VoucherTextField(
                  controller: _phoneController,
                  label: 'Phone number',
                  icon: Icons.phone_outlined,
                ),
                const SizedBox(height: 10),
                _ManagedDropdown(
                  colors: colors,
                  label: 'Title',
                  value: _managedProfileTitle,
                  items: const {
                    'Mr.': 'Mr.',
                    'Mrs.': 'Mrs.',
                    'Miss': 'Miss',
                  },
                  onChanged: (value) =>
                      setState(() => _managedProfileTitle = value),
                ),
                const SizedBox(height: 10),
                _ManagedDropdown(
                  colors: colors,
                  label: 'Gender',
                  value: _gender,
                  items: const {'male': 'Male', 'female': 'Female'},
                  onChanged: (value) => setState(() => _gender = value),
                ),
                const SizedBox(height: 10),
                _ManagedDropdown(
                  colors: colors,
                  label: 'Marital status',
                  value: _managedMaritalStatus,
                  items: const {
                    'Single': 'Single',
                    'Married': 'Married',
                    'Widowed': 'Widowed',
                    'Divorced/Separated': 'Divorced/Separated',
                    'Prefer not to say': 'Prefer not to say',
                  },
                  onChanged: (value) =>
                      setState(() => _managedMaritalStatus = value),
                ),
                const SizedBox(height: 10),
                _ManagedDropdown(
                  colors: colors,
                  label: 'Member type',
                  value: _memberType,
                  items: const {
                    'member': 'Member',
                    'visitor': 'Visitor',
                  },
                  onChanged: (value) => setState(() => _memberType = value),
                ),
                const SizedBox(height: 10),
                _VoucherTextField(
                  controller: _countryController,
                  label: 'Country of residence',
                  icon: Icons.public_rounded,
                ),
                const SizedBox(height: 10),
                _VoucherTextField(
                  controller: _stateController,
                  label: 'State/county/province',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 10),
                _VoucherTextField(
                  controller: _addressController,
                  label: 'Address',
                  icon: Icons.home_outlined,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _savingMember ? null : _createMember,
                    icon: _savingMember
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Create and select member'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            colors: colors,
            title: 'Register with voucher',
            subtitle: _selectedMember == null
                ? 'Select or create a member first.'
                : 'Selected: ${_selectedMember!.displayName}',
            child: Column(
              children: [
                _ManagedDropdown(
                  colors: colors,
                  label: 'Ticket type',
                  value: _selectedTicketType?.publicId ?? '',
                  items: {
                    for (final ticket in _selectedEvent.ticketTypes)
                      ticket.publicId:
                          '${ticket.name} (${ticket.currency} ${ticket.price.toStringAsFixed(2)})',
                  },
                  onChanged: (value) => setState(() {
                    _selectedTicketType = _selectedEvent.ticketTypes.firstWhere(
                      (ticket) => ticket.publicId == value,
                      orElse: () => _selectedEvent.ticketTypes.first,
                    );
                  }),
                ),
                const SizedBox(height: 10),
                _ManagedDropdown(
                  colors: colors,
                  label: 'Age group',
                  value: _ageGroup,
                  items: const {
                    'child': 'Child',
                    'teen': 'Teen',
                    'young_adult': 'Young adult',
                    'adult': 'Adult',
                    'senior': 'Senior',
                  },
                  onChanged: (value) => setState(() => _ageGroup = value),
                ),
                const SizedBox(height: 10),
                _ManagedDropdown(
                  colors: colors,
                  label: 'Interested in FREE church bus',
                  value: _busInterest,
                  items: const {
                    'yes': 'Yes',
                    'no_thanks': 'No thanks',
                  },
                  onChanged: (value) => setState(() => _busInterest = value),
                ),
                const SizedBox(height: 10),
                _ManagedDropdown(
                  colors: colors,
                  label: 'Volunteer department',
                  value: _volunteerDepartment,
                  items: const {
                    'children_department': 'Children department',
                    'intercessory': 'Intercessory',
                    'media': 'Media',
                    'protocol': 'Protocol',
                    'sanctuary': 'Sanctuary',
                    'no_chance_at_the_moment': 'No Chance at the moment',
                  },
                  onChanged: (value) =>
                      setState(() => _volunteerDepartment = value),
                ),
                const SizedBox(height: 10),
                _VoucherTextField(
                  controller: _voucherController,
                  label: 'Voucher code',
                  icon: Icons.confirmation_number_outlined,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _registering ? null : _registerMember,
                    icon: _registering
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.how_to_reg_rounded),
                    label: const Text('Register and pay voucher'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.gold,
                      foregroundColor: colors.deep,
                    ),
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

class _ManagedMemberSubtitle extends StatelessWidget {
  const _ManagedMemberSubtitle({
    required this.member,
    required this.colors,
  });

  final GoshenManagedMember member;
  final _ManagementPalette colors;

  @override
  Widget build(BuildContext context) {
    final triumphantId = member.triumphantId.trim();
    final contact = [
      if (member.email.trim().isNotEmpty) member.email.trim(),
      if (member.phone.trim().isNotEmpty) member.phone.trim(),
    ].join(' | ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (triumphantId.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            'Triumphant ID: $triumphantId',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.isDark ? colors.gold : colors.deep,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        if (contact.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            contact,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.muted),
          ),
        ],
      ],
    );
  }
}

class GoshenQuizManagementStatsScreen extends StatefulWidget {
  const GoshenQuizManagementStatsScreen({
    super.key,
    required this.user,
  });

  final Userdata user;

  @override
  State<GoshenQuizManagementStatsScreen> createState() =>
      _GoshenQuizManagementStatsScreenState();
}

class _GoshenQuizManagementStatsScreenState
    extends State<GoshenQuizManagementStatsScreen> {
  final _api = GoshenQuizApi();
  final Set<int> _busyQuizIds = <int>{};
  late Future<GoshenQuizManagementSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchManagementSummary(widget.user);
  }

  Future<void> _refresh() async {
    final future = _api.fetchManagementSummary(widget.user);
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _updateQuiz(
    GoshenQuizManagementRow quiz, {
    bool? isActive,
    bool? autoSelectWinners,
    bool? showWinnersImmediately,
    bool? walletPrizeEnabled,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (walletPrizeEnabled == true) {
      final unlocked = await WalletSecurityGuard.ensureWalletUnlocked(
        context,
        requireFreshVerification: true,
      );
      if (!unlocked || !mounted) return;
    }
    setState(() => _busyQuizIds.add(quiz.id));
    try {
      await _api.updateQuizSettings(
        widget.user,
        quiz,
        isActive: isActive,
        autoSelectWinners: autoSelectWinners,
        showWinnersImmediately: showWinnersImmediately,
        walletPrizeEnabled: walletPrizeEnabled,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Quiz settings updated.')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyQuizIds.remove(quiz.id));
      }
    }
  }

  Future<void> _payWinnerPrize(
    GoshenQuizManagementRow quiz,
    GoshenQuizWinner winner,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final unlocked = await WalletSecurityGuard.ensureWalletUnlocked(
      context,
      requireFreshVerification: true,
    );
    if (!unlocked || !mounted) return;

    setState(() => _busyQuizIds.add(quiz.id));
    try {
      await _api.payWinnerPrize(widget.user, quiz.id, winner.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Prize paid to ${winner.name}.')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyQuizIds.remove(quiz.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Quiz Management'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<GoshenQuizManagementSummary>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _LoadingCard(colors: colors, label: 'Loading quiz tools...'),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _MessageCard(
                    colors: colors,
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load quiz management',
                    message: snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  ),
                ],
              );
            }

            final summary = snapshot.data!;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _Panel(
                  colors: colors,
                  title: 'Quiz overview',
                  subtitle:
                      'Latest quiz activity, submitted attempts, winners, and wallet prize status.',
                  child: _QuizManagementTotalsGrid(
                    colors: colors,
                    totals: summary.totals,
                  ),
                ),
                const SizedBox(height: 14),
                _QuizManagementList(
                  colors: colors,
                  quizzes: summary.quizzes,
                  busyQuizIds: _busyQuizIds,
                  onActiveChanged: (quiz, value) =>
                      _updateQuiz(quiz, isActive: value),
                  onAutoSelectChanged: (quiz, value) =>
                      _updateQuiz(quiz, autoSelectWinners: value),
                  onShowWinnersChanged: (quiz, value) =>
                      _updateQuiz(quiz, showWinnersImmediately: value),
                  onWalletPrizeChanged: (quiz, value) =>
                      _updateQuiz(quiz, walletPrizeEnabled: value),
                  onPayWinnerPrize: _payWinnerPrize,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class GoshenRegistrationStatsScreen extends StatefulWidget {
  const GoshenRegistrationStatsScreen({
    super.key,
    required this.user,
    this.initialEvent,
  });

  final Userdata user;
  final GoshenRetreatEvent? initialEvent;

  @override
  State<GoshenRegistrationStatsScreen> createState() =>
      _GoshenRegistrationStatsScreenState();
}

class _GoshenRegistrationStatsScreenState
    extends State<GoshenRegistrationStatsScreen> {
  final _api = GoshenRetreatApi();
  late Future<_StatsLoadResult> _future;
  GoshenRetreatEvent? _selectedEvent;

  @override
  void initState() {
    super.initState();
    _selectedEvent = widget.initialEvent;
    _future = _load(event: widget.initialEvent);
  }

  Future<_StatsLoadResult> _load({GoshenRetreatEvent? event}) async {
    final events = await _api.fetchEvents();
    if (events.isEmpty)
      throw Exception('No Goshen Retreat event is available.');

    final requested = event ?? _selectedEvent ?? widget.initialEvent;
    final selected = _matchEvent(events, requested) ?? events.first;
    final summary = await _api.fetchManagementSummary(
      user: widget.user,
      event: selected,
    );
    return _StatsLoadResult(
      events: events,
      selectedEvent: selected,
      summary: summary,
    );
  }

  GoshenRetreatEvent? _matchEvent(
    List<GoshenRetreatEvent> events,
    GoshenRetreatEvent? requested,
  ) {
    if (requested == null) return null;
    for (final event in events) {
      if (event.publicId == requested.publicId) return event;
    }
    return null;
  }

  Future<void> _refresh() async {
    final future = _load(event: _selectedEvent);
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _setRegistrationOpen(
    GoshenRetreatEvent event,
    bool open,
  ) async {
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
              labelText: 'Reason shown to members',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.lock_rounded),
              label: const Text('Close registration'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      reason = controller.text.trim().isEmpty ? reason : controller.text.trim();
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reopen registration?'),
          content: Text(
            'Members will be able to start new registrations for ${event.name}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Reopen registration'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final updatedEvent = await _api.updateRegistrationStatus(
        user: widget.user,
        event: event,
        registrationOpen: open,
        reason: open ? null : reason,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content:
              Text(open ? 'Registration reopened.' : 'Registration closed.'),
        ),
      );
      _selectedEvent = updatedEvent;
      final future = _load(event: updatedEvent);
      setState(() {
        _future = future;
      });
      await future;
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _selectEvent(List<GoshenRetreatEvent> events, String? publicId) {
    if (publicId == null) return;
    GoshenRetreatEvent? selected;
    for (final event in events) {
      if (event.publicId == publicId) {
        selected = event;
        break;
      }
    }
    if (selected == null) return;
    setState(() {
      _selectedEvent = selected;
      _future = _load(event: selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Registration Stats'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<_StatsLoadResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _LoadingCard(colors: colors, label: 'Loading stats...'),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _MessageCard(
                    colors: colors,
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load registration stats',
                    message: snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  ),
                ],
              );
            }

            final data = snapshot.data!;
            final summary = data.summary;
            final totals = summary.totals;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                if (data.events.length > 1) ...[
                  _EventSelector(
                    colors: colors,
                    events: data.events,
                    selected: data.selectedEvent,
                    onChanged: (value) => _selectEvent(data.events, value),
                  ),
                  const SizedBox(height: 14),
                ],
                _RegistrationStatusCard(
                  colors: colors,
                  summary: summary,
                ),
                const SizedBox(height: 14),
                _RegistrationControlCard(
                  colors: colors,
                  event: data.selectedEvent,
                  summary: summary,
                  onSetOpen: (open) =>
                      _setRegistrationOpen(data.selectedEvent, open),
                ),
                const SizedBox(height: 14),
                _TotalsGrid(colors: colors, totals: totals),
                const SizedBox(height: 14),
                _PaymentProgressCard(colors: colors, totals: totals),
                const SizedBox(height: 14),
                _BreakdownCard(
                  colors: colors,
                  title: 'Gender',
                  subtitle: 'Attendees by selected gender',
                  rows: summary.breakdowns.gender,
                  showDonut: true,
                ),
                const SizedBox(height: 14),
                _BreakdownCard(
                  colors: colors,
                  title: 'Age group',
                  subtitle: 'Attendees by age range',
                  rows: summary.breakdowns.ageGroup,
                  showDonut: true,
                ),
                const SizedBox(height: 14),
                _BreakdownCard(
                  colors: colors,
                  title: 'Free church bus',
                  subtitle: 'Transport interest from registration answers',
                  rows: summary.breakdowns.freeChurchBusInterest,
                  showDonut: true,
                ),
                const SizedBox(height: 14),
                _BreakdownCard(
                  colors: colors,
                  title: 'Volunteer department',
                  subtitle: 'Volunteer interest from registration answers',
                  rows: summary.breakdowns.volunteerDepartment,
                  showDonut: true,
                ),
                const SizedBox(height: 14),
                _BreakdownCard(
                  colors: colors,
                  title: 'Ticket type',
                  subtitle: 'Attendees grouped by selected ticket',
                  rows: summary.breakdowns.ticketType,
                  showDonut: true,
                ),
                const SizedBox(height: 14),
                _BreakdownCard(
                  colors: colors,
                  title: 'Company',
                  subtitle: 'Optional company responses from attendees',
                  rows: summary.breakdowns.company,
                  showDonut: true,
                ),
                const SizedBox(height: 14),
                _BreakdownCard(
                  colors: colors,
                  title: 'Designation',
                  subtitle: 'Optional designation responses from attendees',
                  rows: summary.breakdowns.designation,
                  showDonut: true,
                ),
                const SizedBox(height: 14),
                _DualBreakdownCard(
                  colors: colors,
                  leftTitle: 'Booking status',
                  leftRows: summary.breakdowns.bookingStatus,
                  rightTitle: 'Payment mode',
                  rightRows: summary.breakdowns.paymentMode,
                ),
                const SizedBox(height: 14),
                _BreakdownCard(
                  colors: colors,
                  title: 'Privacy consent',
                  subtitle: 'Booking privacy consent capture status',
                  rows: summary.breakdowns.privacyConsent,
                  showDonut: true,
                ),
                const SizedBox(height: 14),
                _RegistrationsTableCard(
                  colors: colors,
                  rows: summary.registrations,
                  totals: totals,
                ),
                const SizedBox(height: 14),
                _AttendeesTableCard(
                  colors: colors,
                  rows: summary.attendees,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatsLoadResult {
  const _StatsLoadResult({
    required this.events,
    required this.selectedEvent,
    required this.summary,
  });

  final List<GoshenRetreatEvent> events;
  final GoshenRetreatEvent selectedEvent;
  final GoshenManagementSummary summary;
}

class GoshenAccommodationManagementScreen extends StatefulWidget {
  const GoshenAccommodationManagementScreen({
    super.key,
    required this.user,
    required this.initialEvent,
    required this.events,
  });

  final Userdata user;
  final GoshenRetreatEvent initialEvent;
  final List<GoshenRetreatEvent> events;

  @override
  State<GoshenAccommodationManagementScreen> createState() =>
      _GoshenAccommodationManagementScreenState();
}

class _GoshenAccommodationManagementScreenState
    extends State<GoshenAccommodationManagementScreen> {
  final _api = GoshenRetreatApi();
  final Set<int> _savingAttendees = <int>{};
  late final List<GoshenRetreatEvent> _events;
  late GoshenRetreatEvent _selectedEvent;
  late Future<GoshenAccommodationManagementSummary> _future;

  @override
  void initState() {
    super.initState();
    _events = widget.events.isEmpty ? [widget.initialEvent] : widget.events;
    _selectedEvent = _events.firstWhere(
      (event) => event.publicId == widget.initialEvent.publicId,
      orElse: () => widget.initialEvent,
    );
    _future = _load();
  }

  Future<GoshenAccommodationManagementSummary> _load() {
    return _api.fetchAccommodationManagement(
      user: widget.user,
      event: _selectedEvent,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  void _selectEvent(String? publicId) {
    final selected = _events.firstWhere(
      (event) => event.publicId == publicId,
      orElse: () => _selectedEvent,
    );
    setState(() {
      _selectedEvent = selected;
      _future = _load();
    });
  }

  Future<void> _openAllocationDialog(
    GoshenAccommodationEligibleAttendee attendee,
  ) async {
    final current = attendee.currentAllocation;
    final building = TextEditingController(text: current?.building ?? '');
    final room = TextEditingController(text: current?.room ?? '');
    final bed = TextEditingController(text: current?.bed ?? '');
    final note = TextEditingController(text: current?.checkInNote ?? '');
    var status = current?.status ?? 'assigned';

    final result = await showDialog<_AccommodationFormResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                current == null ? 'Assign accommodation' : 'Edit allocation',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        attendee.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'assigned',
                          child: Text('Assigned'),
                        ),
                        DropdownMenuItem(
                          value: 'changed',
                          child: Text('Changed'),
                        ),
                        DropdownMenuItem(
                          value: 'removed',
                          child: Text('Removed'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => status = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: building,
                      decoration: const InputDecoration(
                        labelText: 'Building',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: room,
                      decoration: const InputDecoration(
                        labelText: 'Room',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bed,
                      decoration: const InputDecoration(
                        labelText: 'Bed',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: note,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Check-in note',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    _AccommodationFormResult(
                      status: status,
                      building: building.text,
                      room: room.text,
                      bed: bed.text,
                      checkInNote: note.text,
                    ),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    building.dispose();
    room.dispose();
    bed.dispose();
    note.dispose();

    if (result == null) return;
    await _saveAllocation(attendee, result);
  }

  Future<void> _saveAllocation(
    GoshenAccommodationEligibleAttendee attendee,
    _AccommodationFormResult result,
  ) async {
    if (_savingAttendees.contains(attendee.id)) return;
    setState(() => _savingAttendees.add(attendee.id));
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _api.saveAccommodationAllocation(
        user: widget.user,
        event: _selectedEvent,
        attendeeId: attendee.id,
        allocationId: attendee.currentAllocation?.id,
        ticketId: attendee.ticketId,
        status: result.status,
        building: result.building,
        room: result.room,
        bed: result.bed,
        checkInNote: result.checkInNote,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Accommodation allocation saved.')),
      );
      final future = _load();
      setState(() {
        _future = future;
      });
      await future;
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingAttendees.remove(attendee.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Accommodation Allocations'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<GoshenAccommodationManagementSummary>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _LoadingCard(
                    colors: colors,
                    label: 'Loading accommodation allocations...',
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _EventSelector(
                    colors: colors,
                    events: _events,
                    selected: _selectedEvent,
                    onChanged: _selectEvent,
                  ),
                  const SizedBox(height: 14),
                  _MessageCard(
                    colors: colors,
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load allocations',
                    message: snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  ),
                ],
              );
            }

            final summary = snapshot.data!;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _EventSelector(
                  colors: colors,
                  events: _events,
                  selected: _selectedEvent,
                  onChanged: _selectEvent,
                ),
                const SizedBox(height: 14),
                _AccommodationTotalsGrid(
                  colors: colors,
                  totals: summary.totals,
                ),
                const SizedBox(height: 14),
                _AccommodationProgressCard(
                  colors: colors,
                  summary: summary,
                ),
                const SizedBox(height: 14),
                _BreakdownCard(
                  colors: colors,
                  title: 'Allocation status',
                  subtitle: 'Assigned, changed, and removed allocations',
                  rows: summary.statusBreakdown,
                  showDonut: true,
                ),
                const SizedBox(height: 14),
                _AccommodationEligibleTableCard(
                  colors: colors,
                  rows: summary.eligibleAttendees,
                  savingIds: _savingAttendees,
                  onAssign: _openAllocationDialog,
                ),
                const SizedBox(height: 14),
                _AccommodationAllocationsTableCard(
                  colors: colors,
                  rows: summary.allocations,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccommodationFormResult {
  const _AccommodationFormResult({
    required this.status,
    required this.building,
    required this.room,
    required this.bed,
    required this.checkInNote,
  });

  final String status;
  final String building;
  final String room;
  final String bed;
  final String checkInNote;
}

class GoshenScannerStatsScreen extends StatefulWidget {
  const GoshenScannerStatsScreen({
    super.key,
    required this.user,
    required this.initialEvent,
    required this.events,
  });

  final Userdata user;
  final GoshenRetreatEvent initialEvent;
  final List<GoshenRetreatEvent> events;

  @override
  State<GoshenScannerStatsScreen> createState() =>
      _GoshenScannerStatsScreenState();
}

class _GoshenScannerStatsScreenState extends State<GoshenScannerStatsScreen> {
  final _api = GoshenRetreatApi();
  late final List<GoshenRetreatEvent> _events;
  late GoshenRetreatEvent _selectedEvent;
  late Future<GoshenScannerStats> _future;

  @override
  void initState() {
    super.initState();
    _events = widget.events.isEmpty ? [widget.initialEvent] : widget.events;
    _selectedEvent = _events.firstWhere(
      (event) => event.publicId == widget.initialEvent.publicId,
      orElse: () => widget.initialEvent,
    );
    _future = _loadStats();
  }

  Future<GoshenScannerStats> _loadStats() {
    return _api.fetchScannerStats(user: widget.user, event: _selectedEvent);
  }

  Future<void> _refresh() async {
    final future = _loadStats();
    setState(() {
      _future = future;
    });
    await future;
  }

  void _selectEvent(String? publicId) {
    final selected = _events.firstWhere(
      (event) => event.publicId == publicId,
      orElse: () => _selectedEvent,
    );
    setState(() {
      _selectedEvent = selected;
      _future = _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Scanner Stats'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<GoshenScannerStats>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _LoadingCard(
                    colors: colors,
                    label: 'Loading scanner stats...',
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _EventSelector(
                    colors: colors,
                    events: _events,
                    selected: _selectedEvent,
                    onChanged: _selectEvent,
                  ),
                  const SizedBox(height: 14),
                  _MessageCard(
                    colors: colors,
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load scanner stats',
                    message: snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  ),
                ],
              );
            }

            final stats = snapshot.data!;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _EventSelector(
                  colors: colors,
                  events: _events,
                  selected: _selectedEvent,
                  onChanged: _selectEvent,
                ),
                const SizedBox(height: 14),
                _ScannerTotalsGrid(colors: colors, stats: stats),
                const SizedBox(height: 14),
                _ScannerProgressCard(colors: colors, stats: stats),
                const SizedBox(height: 14),
                _ScannerCheckInBreakdownCard(
                  colors: colors,
                  title: 'Gender check-in',
                  subtitle: 'Registered and checked-in tickets by gender',
                  rows: stats.genderBreakdown,
                ),
                const SizedBox(height: 14),
                _ScannerCheckInBreakdownCard(
                  colors: colors,
                  title: 'Age group check-in',
                  subtitle: 'Registered and checked-in tickets by age group',
                  rows: stats.ageGroupBreakdown,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class GoshenSurveyStatsScreen extends StatefulWidget {
  const GoshenSurveyStatsScreen({
    super.key,
    required this.user,
    required this.initialEvent,
    required this.events,
  });

  final Userdata user;
  final GoshenRetreatEvent initialEvent;
  final List<GoshenRetreatEvent> events;

  @override
  State<GoshenSurveyStatsScreen> createState() =>
      _GoshenSurveyStatsScreenState();
}

class _GoshenSurveyStatsScreenState extends State<GoshenSurveyStatsScreen> {
  final _api = GoshenExperienceApi();
  final Set<int> _surveyUpdates = <int>{};
  late final List<GoshenRetreatEvent> _events;
  late GoshenRetreatEvent _selectedEvent;
  late Future<GoshenExperienceStats> _future;

  @override
  void initState() {
    super.initState();
    _events = widget.events.isEmpty ? [widget.initialEvent] : widget.events;
    _selectedEvent = _events.firstWhere(
      (event) => event.publicId == widget.initialEvent.publicId,
      orElse: () => widget.initialEvent,
    );
    _future = _loadStats();
  }

  Future<GoshenExperienceStats> _loadStats() {
    return _api.fetchStats(user: widget.user, eventId: _selectedEvent.publicId);
  }

  Future<void> _refresh() async {
    final future = _loadStats();
    setState(() {
      _future = future;
    });
    await future;
  }

  void _selectEvent(String? publicId) {
    final selected = _events.firstWhere(
      (event) => event.publicId == publicId,
      orElse: () => _selectedEvent,
    );
    setState(() {
      _selectedEvent = selected;
      _future = _loadStats();
    });
  }

  Future<void> _updateSurveySettings(
    GoshenExperienceSurveySummary survey, {
    bool? isActive,
    bool? allowAudio,
    bool? allowVideo,
    bool? allowAllAuthenticatedUsers,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update survey settings'),
            content: Text('Apply this change to "${survey.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Apply'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _surveyUpdates.add(survey.id));

    try {
      await _api.updateSurveySettings(
        user: widget.user,
        survey: survey,
        isActive: isActive,
        allowAudio: allowAudio,
        allowVideo: allowVideo,
        allowAllAuthenticatedUsers: allowAllAuthenticatedUsers,
      );

      final future = _loadStats();
      if (!mounted) return;
      setState(() {
        _future = future;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Survey settings updated.')),
      );
      await future;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _surveyUpdates.remove(survey.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Survey Stats'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<GoshenExperienceStats>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _LoadingCard(
                      colors: colors, label: 'Loading survey stats...'),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _EventSelector(
                    colors: colors,
                    events: _events,
                    selected: _selectedEvent,
                    onChanged: _selectEvent,
                  ),
                  const SizedBox(height: 14),
                  _MessageCard(
                    colors: colors,
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load survey stats',
                    message: snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  ),
                ],
              );
            }

            final stats = snapshot.data!;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _EventSelector(
                  colors: colors,
                  events: _events,
                  selected: _selectedEvent,
                  onChanged: _selectEvent,
                ),
                const SizedBox(height: 14),
                _SurveyTotalsGrid(colors: colors, stats: stats),
                const SizedBox(height: 14),
                _SurveyResponseProgressCard(colors: colors, stats: stats),
                const SizedBox(height: 14),
                _BreakdownCard(
                  colors: colors,
                  title: 'Gender',
                  subtitle: 'Survey responses by profile gender',
                  rows: _experienceRows(stats.byGender),
                  showDonut: true,
                ),
                const SizedBox(height: 14),
                _BreakdownCard(
                  colors: colors,
                  title: 'Age group',
                  subtitle: 'Survey responses by estimated age range',
                  rows: _experienceRows(stats.byAgeGroup),
                ),
                const SizedBox(height: 14),
                _DualBreakdownCard(
                  colors: colors,
                  leftTitle: 'Country',
                  leftRows: _experienceRows(stats.byCountry),
                  rightTitle: 'State / province',
                  rightRows: _experienceRows(stats.byState),
                ),
                const SizedBox(height: 14),
                _SurveyListCard(
                  colors: colors,
                  surveys: stats.surveys,
                  updatingIds: _surveyUpdates,
                  onSettingsChanged: _updateSurveySettings,
                ),
                const SizedBox(height: 14),
                _SurveyQuestionStatsCard(
                  colors: colors,
                  questions: stats.questionStats,
                ),
                const SizedBox(height: 14),
                _SurveyRecentResponsesCard(
                  colors: colors,
                  responses: stats.recentResponses,
                  totalResponses: stats.responses,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SurveyTotalsGrid extends StatelessWidget {
  const _SurveyTotalsGrid({
    required this.colors,
    required this.stats,
  });

  final _ManagementPalette colors;
  final GoshenExperienceStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        'Checked in',
        _number(stats.checkedInAttendees),
        Icons.how_to_reg_outlined,
      ),
      _MetricData(
        'Responses',
        _number(stats.responses),
        Icons.forum_outlined,
      ),
      _MetricData(
        'Response rate',
        '${stats.responseRate.toStringAsFixed(stats.responseRate % 1 == 0 ? 0 : 1)}%',
        Icons.trending_up_rounded,
      ),
      _MetricData(
        'Countries',
        _number(stats.byCountry.length),
        Icons.public_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map((item) => SizedBox(
                    width: width,
                    child: _MetricTile(colors: colors, data: item),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _SurveyResponseProgressCard extends StatelessWidget {
  const _SurveyResponseProgressCard({
    required this.colors,
    required this.stats,
  });

  final _ManagementPalette colors;
  final GoshenExperienceStats stats;

  @override
  Widget build(BuildContext context) {
    final progress = (stats.responseRate / 100).clamp(0.0, 1.0);
    return _Panel(
      colors: colors,
      title: 'Survey response progress',
      trailing: Text(
        '${stats.responseRate.toStringAsFixed(stats.responseRate % 1 == 0 ? 0 : 1)}%',
        style: TextStyle(
          color: colors.text,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.gold),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Checked in',
                  value: _number(stats.checkedInAttendees),
                ),
              ),
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Responses',
                  value: _number(stats.responses),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SurveyListCard extends StatelessWidget {
  const _SurveyListCard({
    required this.colors,
    required this.surveys,
    required this.updatingIds,
    required this.onSettingsChanged,
  });

  final _ManagementPalette colors;
  final List<GoshenExperienceSurveySummary> surveys;
  final Set<int> updatingIds;
  final Future<void> Function(
    GoshenExperienceSurveySummary survey, {
    bool? isActive,
    bool? allowAudio,
    bool? allowVideo,
    bool? allowAllAuthenticatedUsers,
  }) onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Survey management',
      subtitle: 'Active forms, questions, and response totals',
      child: surveys.isEmpty
          ? _EmptyInline(colors: colors, text: 'No surveys are linked yet.')
          : Column(
              children: [
                for (var index = 0;
                    index < surveys.take(6).length;
                    index++) ...[
                  _SurveySummaryRow(
                    colors: colors,
                    survey: surveys[index],
                    updating: updatingIds.contains(surveys[index].id),
                    onSettingsChanged: onSettingsChanged,
                  ),
                  if (index != surveys.take(6).length - 1)
                    Divider(height: 22, color: colors.border),
                ],
                if (surveys.length > 6) ...[
                  Divider(height: 22, color: colors.border),
                  _LimitHint(
                    colors: colors,
                    text: 'Showing 6 of ${_number(surveys.length)} surveys.',
                  ),
                ],
              ],
            ),
    );
  }
}

class _SurveySummaryRow extends StatelessWidget {
  const _SurveySummaryRow({
    required this.colors,
    required this.survey,
    required this.updating,
    required this.onSettingsChanged,
  });

  final _ManagementPalette colors;
  final GoshenExperienceSurveySummary survey;
  final bool updating;
  final Future<void> Function(
    GoshenExperienceSurveySummary survey, {
    bool? isActive,
    bool? allowAudio,
    bool? allowVideo,
    bool? allowAllAuthenticatedUsers,
  }) onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          survey.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
          color: survey.isActive ? colors.success : colors.muted,
          size: 30,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                survey.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_number(survey.questionsCount)} questions  ${_number(survey.responsesCount)} responses',
                style: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (updating)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.gold),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SurveySettingToggle(
                      colors: colors,
                      label: 'Active',
                      value: survey.isActive,
                      icon: Icons.power_settings_new_rounded,
                      onChanged: (value) => onSettingsChanged(
                        survey,
                        isActive: value,
                      ),
                    ),
                    _SurveySettingToggle(
                      colors: colors,
                      label: 'Audio',
                      value: survey.allowAudio,
                      icon: Icons.mic_none_rounded,
                      onChanged: (value) => onSettingsChanged(
                        survey,
                        allowAudio: value,
                      ),
                    ),
                    _SurveySettingToggle(
                      colors: colors,
                      label: 'Video',
                      value: survey.allowVideo,
                      icon: Icons.videocam_outlined,
                      onChanged: (value) => onSettingsChanged(
                        survey,
                        allowVideo: value,
                      ),
                    ),
                    _SurveySettingToggle(
                      colors: colors,
                      label: 'Open to all',
                      value: survey.allowAllAuthenticatedUsers,
                      icon: Icons.groups_2_outlined,
                      onChanged: (value) => onSettingsChanged(
                        survey,
                        allowAllAuthenticatedUsers: value,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SurveySettingToggle extends StatelessWidget {
  const _SurveySettingToggle({
    required this.colors,
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  final _ManagementPalette colors;
  final String label;
  final bool value;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: value
            ? colors.gold.withValues(alpha: 0.16)
            : colors.border.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: value ? colors.gold.withValues(alpha: 0.42) : colors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: value ? colors.deep : colors.muted,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: value ? colors.deep : colors.muted,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          Transform.scale(
            scale: 0.72,
            child: Switch.adaptive(
              value: value,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeColor: colors.deep,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurveyQuestionStatsCard extends StatelessWidget {
  const _SurveyQuestionStatsCard({
    required this.colors,
    required this.questions,
  });

  final _ManagementPalette colors;
  final List<GoshenSurveyQuestionStats> questions;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Question results',
      subtitle: 'Per-question answers from survey responses',
      child: questions.isEmpty
          ? _EmptyInline(colors: colors, text: 'No question results yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0;
                    index < questions.take(8).length;
                    index++) ...[
                  _SurveyQuestionBlock(
                    colors: colors,
                    question: questions[index],
                  ),
                  if (index != questions.take(8).length - 1)
                    Divider(height: 26, color: colors.border),
                ],
                if (questions.length > 8) ...[
                  Divider(height: 26, color: colors.border),
                  _LimitHint(
                    colors: colors,
                    text:
                        'Showing 8 of ${_number(questions.length)} questions.',
                  ),
                ],
              ],
            ),
    );
  }
}

class _SurveyQuestionBlock extends StatelessWidget {
  const _SurveyQuestionBlock({
    required this.colors,
    required this.question,
  });

  final _ManagementPalette colors;
  final GoshenSurveyQuestionStats question;

  @override
  Widget build(BuildContext context) {
    final rows = question.breakdown;
    final samples = question.samples;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.prompt,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${question.type.replaceAll('_', ' ')}  ${_number(question.responses)} responses',
          style: TextStyle(
            color: colors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...rows.take(5).map(
                (row) => _SurveyAnswerBreakdownRow(
                  colors: colors,
                  row: row,
                  total: question.responses,
                ),
              ),
        ] else if (samples.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...samples.take(3).map(
                (sample) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    sample,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.muted,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _SurveyAnswerBreakdownRow extends StatelessWidget {
  const _SurveyAnswerBreakdownRow({
    required this.colors,
    required this.row,
    required this.total,
  });

  final _ManagementPalette colors;
  final GoshenSurveyAnswerBreakdown row;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = total <= 0 ? 0.0 : (row.count / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _SurveyAnswerMarker(colors: colors, row: row),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${_number(row.count)}  ${(percent * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: colors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: percent,
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.gold),
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

class _SurveyAnswerMarker extends StatelessWidget {
  const _SurveyAnswerMarker({
    required this.colors,
    required this.row,
  });

  final _ManagementPalette colors;
  final GoshenSurveyAnswerBreakdown row;

  @override
  Widget build(BuildContext context) {
    final imageUrl = row.imageUrl?.trim() ?? '';
    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackMarker(),
        ),
      );
    }

    final color = _parseColor(row.colorHex);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color ?? colors.gold.withOpacity(0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: color == null
          ? Icon(Icons.check_rounded, color: colors.gold, size: 20)
          : null,
    );
  }

  Widget _fallbackMarker() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: colors.gold.withOpacity(0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Icon(Icons.image_not_supported_outlined,
          color: colors.gold, size: 18),
    );
  }
}

class _SurveyRecentResponsesCard extends StatelessWidget {
  const _SurveyRecentResponsesCard({
    required this.colors,
    required this.responses,
    required this.totalResponses,
  });

  final _ManagementPalette colors;
  final List<GoshenSurveyRecentResponse> responses;
  final int totalResponses;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Recent responses',
      subtitle: 'Latest stories, answers, and media from attendees',
      child: responses.isEmpty
          ? _EmptyInline(colors: colors, text: 'No survey responses yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0;
                    index < responses.take(10).length;
                    index++) ...[
                  _SurveyResponseBlock(
                    colors: colors,
                    response: responses[index],
                  ),
                  if (index != responses.take(10).length - 1)
                    Divider(height: 26, color: colors.border),
                ],
                if (totalResponses > responses.take(10).length) ...[
                  Divider(height: 26, color: colors.border),
                  _LimitHint(
                    colors: colors,
                    text:
                        'Showing latest ${_number(responses.take(10).length)} of ${_number(totalResponses)} responses.',
                  ),
                ],
              ],
            ),
    );
  }
}

class _SurveyResponseBlock extends StatelessWidget {
  const _SurveyResponseBlock({
    required this.colors,
    required this.response,
  });

  final _ManagementPalette colors;
  final GoshenSurveyRecentResponse response;

  @override
  Widget build(BuildContext context) {
    final submittedAt = response.submittedAt == null
        ? ''
        : _dateTimeLabel(response.submittedAt!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.gold.withOpacity(0.18),
              child: Icon(Icons.person_outline_rounded,
                  color: colors.gold, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    response.memberName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      response.surveyTitle,
                      if (submittedAt.isNotEmpty) submittedAt,
                    ].join(' - '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (response.story.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            response.story,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
        if (response.answers.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...response.answers.take(4).map(
                (answer) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: colors.muted,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      children: [
                        TextSpan(
                          text: '${answer.prompt}: ',
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(text: answer.answer),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
        ],
        if (response.hasMedia) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((response.audioUrl ?? '').isNotEmpty)
                _MediaLinkButton(
                  colors: colors,
                  icon: Icons.graphic_eq_rounded,
                  label: response.audioDurationSeconds == null
                      ? 'Play audio'
                      : 'Play audio (${_durationLabel(response.audioDurationSeconds!)})',
                  url: response.audioUrl!,
                ),
              if ((response.videoUrl ?? '').isNotEmpty)
                _MediaLinkButton(
                  colors: colors,
                  icon: Icons.play_circle_outline_rounded,
                  label: response.videoDurationSeconds == null
                      ? 'Open video'
                      : 'Open video (${_durationLabel(response.videoDurationSeconds!)})',
                  url: response.videoUrl!,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MediaLinkButton extends StatelessWidget {
  const _MediaLinkButton({
    required this.colors,
    required this.icon,
    required this.label,
    required this.url,
  });

  final _ManagementPalette colors;
  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _launchExternalUrl(context, url),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _LimitHint extends StatelessWidget {
  const _LimitHint({
    required this.colors,
    required this.text,
  });

  final _ManagementPalette colors;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: colors.muted,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _RetreatSetupOverviewCard extends StatelessWidget {
  const _RetreatSetupOverviewCard({
    required this.colors,
    required this.event,
  });

  final _ManagementPalette colors;
  final GoshenRetreatEvent event;

  @override
  Widget build(BuildContext context) {
    final registration = event.registration;
    final statusColor = registration.open ? colors.success : colors.danger;
    final salesWindow = [
      if (event.salesStartAt != null)
        'Opens ${_dateTimeLabel(event.salesStartAt!)}',
      if (event.salesEndAt != null)
        'Closes ${_dateTimeLabel(event.salesEndAt!)}',
    ].join('\n');

    return _Panel(
      colors: colors,
      title: event.name.trim().isEmpty ? 'Goshen Retreat' : event.name,
      subtitle: event.venueName.trim().isNotEmpty
          ? event.venueName
          : 'Venue details are not set',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                label: registration.open ? 'Registration open' : 'Closed',
                color: statusColor,
              ),
              _StatusPill(label: registration.override, color: colors.gold),
              if (event.payInFullDiscount.available)
                _StatusPill(
                  label: 'Pay-in-full discount',
                  color: colors.teal,
                ),
            ],
          ),
          if (event.description.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              event.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.muted, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Retreat dates',
                  value: event.dateLabel,
                ),
              ),
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Sales window',
                  value: salesWindow.isEmpty ? 'Not configured' : salesWindow,
                ),
              ),
            ],
          ),
          if (event.supportEmail.trim().isNotEmpty ||
              event.venueAddress.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              [
                if (event.venueAddress.trim().isNotEmpty) event.venueAddress,
                if (event.supportEmail.trim().isNotEmpty)
                  'Support: ${event.supportEmail}',
              ].join('\n'),
              style: TextStyle(
                color: colors.muted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RetreatSetupMetricsGrid extends StatelessWidget {
  const _RetreatSetupMetricsGrid({
    required this.colors,
    required this.event,
  });

  final _ManagementPalette colors;
  final GoshenRetreatEvent event;

  @override
  Widget build(BuildContext context) {
    final activeDiscount = event.payInFullDiscount.available;
    final items = [
      _MetricData(
        'Schedules',
        _number(event.schedules.length),
        Icons.event_available_outlined,
      ),
      _MetricData(
        'Ticket types',
        _number(event.ticketTypes.length),
        Icons.confirmation_number_outlined,
      ),
      _MetricData(
        'Starting price',
        event.priceLabel,
        Icons.payments_outlined,
      ),
      _MetricData(
        'Discount',
        activeDiscount ? event.payInFullDiscount.label : 'Inactive',
        Icons.discount_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map((item) => SizedBox(
                    width: width,
                    child: _MetricTile(colors: colors, data: item),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _RetreatSetupSchedulesManagerCard extends StatelessWidget {
  const _RetreatSetupSchedulesManagerCard({
    required this.colors,
    required this.schedules,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final _ManagementPalette colors;
  final List<GoshenRetreatSchedule> schedules;
  final VoidCallback onAdd;
  final ValueChanged<GoshenRetreatSchedule> onEdit;
  final ValueChanged<GoshenRetreatSchedule> onDelete;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Schedules',
      subtitle: 'Add, edit, or remove programme sessions.',
      trailing: IconButton(
        tooltip: 'Add schedule',
        onPressed: onAdd,
        icon: const Icon(Icons.add_circle_outline_rounded),
      ),
      child: schedules.isEmpty
          ? _EmptyInline(colors: colors, text: 'No schedule has been added.')
          : Column(
              children: schedules
                  .map(
                    (schedule) => _SetupListTile(
                      colors: colors,
                      icon: Icons.event_available_outlined,
                      title: schedule.title.trim().isEmpty
                          ? 'Day ${schedule.dayNumber}'
                          : schedule.title,
                      subtitle: [
                        'Day ${schedule.dayNumber}',
                        schedule.startsAt == null
                            ? 'Start not set'
                            : _dateTimeLabel(schedule.startsAt!),
                        if (schedule.endsAt != null)
                          'Ends ${_dateTimeLabel(schedule.endsAt!)}',
                        if (schedule.capacity != null)
                          'Capacity ${_number(schedule.capacity!)}',
                      ].join(' • '),
                      onEdit: () => onEdit(schedule),
                      onDelete:
                          schedule.id <= 0 ? null : () => onDelete(schedule),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _RetreatSetupTicketTypesManagerCard extends StatelessWidget {
  const _RetreatSetupTicketTypesManagerCard({
    required this.colors,
    required this.ticketTypes,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final _ManagementPalette colors;
  final List<GoshenTicketType> ticketTypes;
  final VoidCallback onAdd;
  final ValueChanged<GoshenTicketType> onEdit;
  final ValueChanged<GoshenTicketType> onDelete;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Ticket types',
      subtitle: 'Manage ticket price, capacity, and active status.',
      trailing: IconButton(
        tooltip: 'Add ticket type',
        onPressed: onAdd,
        icon: const Icon(Icons.add_circle_outline_rounded),
      ),
      child: ticketTypes.isEmpty
          ? _EmptyInline(colors: colors, text: 'No ticket type has been added.')
          : Column(
              children: ticketTypes
                  .map(
                    (ticket) => _SetupListTile(
                      colors: colors,
                      icon: Icons.confirmation_number_outlined,
                      title:
                          ticket.name.trim().isEmpty ? 'Ticket' : ticket.name,
                      subtitle: [
                        '${ticket.currency} ${_decimalInput(ticket.price)}',
                        ticket.isActive ? 'active' : 'inactive',
                        if (ticket.capacity != null)
                          'Capacity ${_number(ticket.capacity!)}',
                        'Min ${_number(ticket.minPerBooking)}',
                        'Max ${_number(ticket.maxPerBooking)}',
                      ].join(' • '),
                      statusColor:
                          ticket.isActive ? colors.success : colors.danger,
                      onEdit: () => onEdit(ticket),
                      onDelete: () => onDelete(ticket),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _RetreatSetupRegistrationFieldsCard extends StatelessWidget {
  const _RetreatSetupRegistrationFieldsCard({
    required this.colors,
    required this.fields,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final _ManagementPalette colors;
  final List<GoshenRegistrationField> fields;
  final VoidCallback onAdd;
  final ValueChanged<GoshenRegistrationField> onEdit;
  final ValueChanged<GoshenRegistrationField> onDelete;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Registration fields',
      subtitle: 'Control attendee fields shown on the registration form.',
      trailing: IconButton(
        tooltip: 'Add field',
        onPressed: onAdd,
        icon: const Icon(Icons.add_circle_outline_rounded),
      ),
      child: fields.isEmpty
          ? _EmptyInline(
              colors: colors, text: 'No attendee field is configured.')
          : Column(
              children: fields
                  .map(
                    (field) => _SetupListTile(
                      colors: colors,
                      icon: field.isImageSelect
                          ? Icons.image_outlined
                          : field.isColorSelect
                              ? Icons.palette_outlined
                              : field.isSelect
                                  ? Icons.list_alt_outlined
                                  : Icons.short_text_rounded,
                      title: field.label,
                      subtitle: [
                        field.key,
                        field.type.replaceAll('_', ' '),
                        field.isRequired ? 'required' : 'optional',
                        if (field.options.isNotEmpty)
                          '${_number(field.options.length)} options',
                      ].join(' • '),
                      statusColor: field.isRequired ? colors.gold : colors.teal,
                      onEdit: () => onEdit(field),
                      onDelete: field.id <= 0 ? null : () => onDelete(field),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _SetupListTile extends StatelessWidget {
  const _SetupListTile({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onEdit,
    this.onDelete,
    this.statusColor,
  });

  final _ManagementPalette colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    final accent = statusColor ?? colors.gold;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.innerCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            color: colors.danger,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _AccommodationTotalsGrid extends StatelessWidget {
  const _AccommodationTotalsGrid({
    required this.colors,
    required this.totals,
  });

  final _ManagementPalette colors;
  final GoshenAccommodationManagementTotals totals;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        'Eligible',
        _number(totals.eligibleAttendees),
        Icons.groups_2_outlined,
      ),
      _MetricData(
        'Allocated',
        _number(totals.allocated),
        Icons.home_work_outlined,
      ),
      _MetricData(
        'Unallocated',
        _number(totals.unallocated),
        Icons.pending_actions_rounded,
      ),
      _MetricData(
        'Removed',
        _number(totals.removed),
        Icons.remove_circle_outline_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map((item) => SizedBox(
                    width: width,
                    child: _MetricTile(colors: colors, data: item),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _AccommodationProgressCard extends StatelessWidget {
  const _AccommodationProgressCard({
    required this.colors,
    required this.summary,
  });

  final _ManagementPalette colors;
  final GoshenAccommodationManagementSummary summary;

  @override
  Widget build(BuildContext context) {
    final totals = summary.totals;
    final progress = totals.allocationProgress;
    final percent = progress * 100;

    return _Panel(
      colors: colors,
      title: 'Room allocation progress',
      subtitle: summary.generatedAt == null
          ? 'Eligible paid attendees with active tickets'
          : 'Updated ${_dateTimeLabel(summary.generatedAt!)}',
      trailing: Text(
        '${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1)}%',
        style: TextStyle(
          color: colors.text,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.gold),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Assigned',
                  value: _number(totals.assigned),
                ),
              ),
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Changed',
                  value: _number(totals.changed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccommodationEligibleTableCard extends StatelessWidget {
  const _AccommodationEligibleTableCard({
    required this.colors,
    required this.rows,
    required this.savingIds,
    required this.onAssign,
  });

  final _ManagementPalette colors;
  final List<GoshenAccommodationEligibleAttendee> rows;
  final Set<int> savingIds;
  final ValueChanged<GoshenAccommodationEligibleAttendee> onAssign;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Eligible attendees',
      subtitle: 'Only paid attendees with active tickets are listed here',
      child: rows.isEmpty
          ? _EmptyInline(colors: colors, text: 'No eligible attendees yet.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
                dataTextStyle: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w700,
                ),
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Ticket')),
                  DataColumn(label: Text('Booking')),
                  DataColumn(label: Text('Allocation')),
                  DataColumn(label: Text('Action')),
                ],
                rows: rows.take(80).map((row) {
                  final saving = savingIds.contains(row.id);
                  final allocation = row.currentAllocation;
                  return DataRow(
                    cells: [
                      DataCell(Text(row.displayName)),
                      DataCell(Text(row.displayTicket)),
                      DataCell(Text(row.bookingStatus)),
                      DataCell(
                        Text(allocation?.locationLabel ?? 'Not allocated'),
                      ),
                      DataCell(
                        TextButton.icon(
                          onPressed: saving ? null : () => onAssign(row),
                          icon: saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  allocation == null
                                      ? Icons.add_home_work_outlined
                                      : Icons.edit_location_alt_outlined,
                                  size: 18,
                                ),
                          label: Text(allocation == null ? 'Assign' : 'Edit'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class _AccommodationAllocationsTableCard extends StatelessWidget {
  const _AccommodationAllocationsTableCard({
    required this.colors,
    required this.rows,
  });

  final _ManagementPalette colors;
  final List<GoshenAccommodationManagementAllocation> rows;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Current allocations',
      subtitle: 'Room and bed details visible to assigned attendees',
      child: rows.isEmpty
          ? _EmptyInline(
              colors: colors, text: 'No allocations have been saved.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
                dataTextStyle: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w700,
                ),
                columns: const [
                  DataColumn(label: Text('Attendee')),
                  DataColumn(label: Text('Ticket')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Building')),
                  DataColumn(label: Text('Room')),
                  DataColumn(label: Text('Bed')),
                  DataColumn(label: Text('Updated')),
                ],
                rows: rows.take(80).map((row) {
                  return DataRow(
                    cells: [
                      DataCell(Text(row.displayName)),
                      DataCell(Text(row.ticketNumber)),
                      DataCell(
                        _StatusPill(
                          label: row.statusLabel,
                          color: row.status == 'removed'
                              ? colors.danger
                              : row.status == 'changed'
                                  ? colors.teal
                                  : colors.success,
                        ),
                      ),
                      DataCell(Text(row.building)),
                      DataCell(Text(row.room)),
                      DataCell(Text(row.bed)),
                      DataCell(Text(
                        row.updatedAt == null
                            ? 'Not available'
                            : _dateTimeLabel(row.updatedAt!),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class _ScannerTotalsGrid extends StatelessWidget {
  const _ScannerTotalsGrid({
    required this.colors,
    required this.stats,
  });

  final _ManagementPalette colors;
  final GoshenScannerStats stats;

  @override
  Widget build(BuildContext context) {
    final percent = stats.registered <= 0
        ? 0.0
        : (stats.checkedIn / stats.registered) * 100;
    final items = [
      _MetricData(
        'Registered tickets',
        _number(stats.registered),
        Icons.confirmation_number_outlined,
      ),
      _MetricData(
        'Checked in',
        _number(stats.checkedIn),
        Icons.how_to_reg_rounded,
      ),
      _MetricData(
        'Not checked in',
        _number(stats.notYetCheckedIn),
        Icons.pending_actions_rounded,
      ),
      _MetricData(
        'Progress',
        '${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1)}%',
        Icons.trending_up_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map((item) => SizedBox(
                    width: width,
                    child: _MetricTile(colors: colors, data: item),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _ScannerProgressCard extends StatelessWidget {
  const _ScannerProgressCard({
    required this.colors,
    required this.stats,
  });

  final _ManagementPalette colors;
  final GoshenScannerStats stats;

  @override
  Widget build(BuildContext context) {
    final progress = stats.registered <= 0
        ? 0.0
        : (stats.checkedIn / stats.registered).clamp(0.0, 1.0);
    final percent = progress * 100;

    return _Panel(
      colors: colors,
      title: 'Check-in progress',
      subtitle: stats.generatedAt == null
          ? 'Live scanner summary'
          : 'Updated ${_dateTimeLabel(stats.generatedAt!)}',
      trailing: Text(
        '${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1)}%',
        style: TextStyle(
          color: colors.text,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.gold),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Checked in',
                  value: _number(stats.checkedIn),
                ),
              ),
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Remaining',
                  value: _number(stats.notYetCheckedIn),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScannerCheckInBreakdownCard extends StatelessWidget {
  const _ScannerCheckInBreakdownCard({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.rows,
  });

  final _ManagementPalette colors;
  final String title;
  final String subtitle;
  final List<GoshenScannerStatsRow> rows;

  @override
  Widget build(BuildContext context) {
    final donutRows = rows
        .map(
          (row) => GoshenManagementBreakdownRow(
            key: row.code,
            label: row.label,
            count: row.registered,
          ),
        )
        .toList();

    return _Panel(
      colors: colors,
      title: title,
      subtitle: subtitle,
      child: rows.isEmpty
          ? _EmptyInline(colors: colors, text: 'No scanner data yet.')
          : Column(
              children: [
                _DonutSummary(colors: colors, rows: donutRows),
                const SizedBox(height: 14),
                ...rows.map(
                  (row) => _ScannerCheckInRow(colors: colors, row: row),
                ),
              ],
            ),
    );
  }
}

class _ScannerCheckInRow extends StatelessWidget {
  const _ScannerCheckInRow({
    required this.colors,
    required this.row,
  });

  final _ManagementPalette colors;
  final GoshenScannerStatsRow row;

  @override
  Widget build(BuildContext context) {
    final progress = row.registered <= 0
        ? 0.0
        : (row.checkedIn / row.registered).clamp(0.0, 1.0);
    final percent = progress * 100;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_number(row.checkedIn)} / ${_number(row.registered)}',
                style: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.teal),
            ),
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1)}% checked in',
              style: TextStyle(
                color: colors.muted,
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

class GoshenWalletWithdrawalManagementScreen extends StatefulWidget {
  const GoshenWalletWithdrawalManagementScreen({
    super.key,
    required this.user,
  });

  final Userdata user;

  @override
  State<GoshenWalletWithdrawalManagementScreen> createState() =>
      _GoshenWalletWithdrawalManagementScreenState();
}

class _GoshenWalletWithdrawalManagementScreenState
    extends State<GoshenWalletWithdrawalManagementScreen> {
  final _api = GoshenWalletApi();
  late Future<Map<String, dynamic>> _future;
  final Set<int> _busyIds = <int>{};

  @override
  void initState() {
    super.initState();
    _future = _api.fetchWithdrawalManagement(widget.user);
  }

  Future<void> _refresh() async {
    final future = _api.fetchWithdrawalManagement(widget.user);
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _updateStatus(
    GoshenWalletWithdrawalRequest request,
    String status,
  ) async {
    final noteController = TextEditingController();
    final referenceController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_statusActionLabel(status)} withdrawal?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${request.memberName} - ${_managementMoney(request.amount, request.currency)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 14),
              if (status == 'paid') ...[
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Payout reference',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Admin note',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_statusActionLabel(status)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      noteController.dispose();
      referenceController.dispose();
      return;
    }

    setState(() => _busyIds.add(request.id));
    try {
      await _api.updateWithdrawalStatus(
        user: widget.user,
        request: request,
        status: status,
        adminNote: noteController.text,
        payoutReference: referenceController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal request updated.')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      noteController.dispose();
      referenceController.dispose();
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Wallet Withdrawals'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _LoadingCard(colors: colors, label: 'Loading withdrawals...'),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _MessageCard(
                    colors: colors,
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load withdrawals',
                    message: snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  ),
                ],
              );
            }

            final data = snapshot.data ?? const {};
            final totals =
                Map<String, dynamic>.from(data['totals'] as Map? ?? {});
            final requests = ((data['requests'] as List?) ?? const [])
                .map((item) => GoshenWalletWithdrawalRequest.fromJson(
                      Map<String, dynamic>.from(item),
                    ))
                .toList();

            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _Panel(
                  colors: colors,
                  title: 'Withdrawal queue',
                  subtitle:
                      'Funds are reserved when a member submits a request. Rejecting returns the funds automatically.',
                  child: _WithdrawalTotalsGrid(colors: colors, totals: totals),
                ),
                const SizedBox(height: 16),
                _Panel(
                  colors: colors,
                  title: 'Requests',
                  child: requests.isEmpty
                      ? _EmptyInline(
                          colors: colors,
                          text: 'No wallet withdrawal requests yet.',
                        )
                      : Column(
                          children: [
                            for (var index = 0;
                                index < requests.length;
                                index += 1) ...[
                              _WithdrawalManagementTile(
                                colors: colors,
                                request: requests[index],
                                busy: _busyIds.contains(requests[index].id),
                                onApprove: () =>
                                    _updateStatus(requests[index], 'approved'),
                                onReject: () =>
                                    _updateStatus(requests[index], 'rejected'),
                                onPaid: () =>
                                    _updateStatus(requests[index], 'paid'),
                              ),
                              if (index != requests.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

const Map<String, String> _recipientModeLabels = {
  'all': 'All active users',
  'countries': 'Country specific users',
  'genders': 'Male or female users',
  'roles': 'Users by role',
  'goshen_paid': 'Goshen edition: fully paid',
  'goshen_unpaid': 'Goshen edition: not fully paid',
  'goshen_paid_between': 'Goshen edition: paid within date range',
  'goshen_paid_recent_days': 'Goshen edition: paid within recent days',
  'goshen_paid_week': 'Goshen edition: paid within selected week',
  'goshen_paid_month': 'Goshen edition: paid within selected month',
  'fundraising_participants': 'Project support campaign participants',
  'quiz_participants': 'Quiz participants',
};

class ControlHubMessageSenderScreen extends StatefulWidget {
  const ControlHubMessageSenderScreen({
    super.key,
    required this.user,
  });

  final Userdata user;

  @override
  State<ControlHubMessageSenderScreen> createState() =>
      _ControlHubMessageSenderScreenState();
}

class _ControlHubMessageSenderScreenState
    extends State<ControlHubMessageSenderScreen> {
  final _api = ControlHubMessagingApi();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _recentDaysController = TextEditingController(text: '7');
  final _paidMonthController = TextEditingController();
  late Future<ControlHubMessageOptions> _future;
  String _category = 'general';
  String _recipientMode = 'all';
  bool _sendInbox = true;
  bool _sendPush = true;
  bool _sendEmail = false;
  bool _scheduleEnabled = false;
  bool _sending = false;
  final Set<String> _countries = <String>{};
  final Set<String> _genders = <String>{};
  final Set<int> _roleIds = <int>{};
  int? _goshenEventId;
  int? _fundraisingCampaignId;
  int? _goshenQuizId;
  DateTime? _paidFrom;
  DateTime? _paidUntil;
  DateTime? _paidWeek;
  DateTime? _scheduledFor;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchOptions(widget.user);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _recentDaysController.dispose();
    _paidMonthController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      _showSnack('Enter a message title and body.');
      return;
    }
    if (!_sendInbox && !_sendPush && !_sendEmail) {
      _showSnack('Choose at least one delivery channel.');
      return;
    }
    if (_sendPush && !_sendInbox) {
      _showSnack('Push messages must also be published in the app inbox.');
      return;
    }
    if (_recipientMode == 'countries' && _countries.isEmpty) {
      _showSnack('Choose at least one country.');
      return;
    }
    if (_recipientMode == 'genders' && _genders.isEmpty) {
      _showSnack('Choose at least one gender.');
      return;
    }
    if (_recipientMode == 'roles' && _roleIds.isEmpty) {
      _showSnack('Choose at least one role.');
      return;
    }
    if (_isGoshenMode(_recipientMode) && _goshenEventId == null) {
      _showSnack('Choose a Goshen retreat edition.');
      return;
    }
    if (_recipientMode == 'goshen_paid_between' &&
        (_paidFrom == null || _paidUntil == null)) {
      _showSnack('Choose the paid date range.');
      return;
    }
    if (_recipientMode == 'goshen_paid_recent_days' &&
        (int.tryParse(_recentDaysController.text.trim()) ?? 0) <= 0) {
      _showSnack('Enter the number of recent paid days.');
      return;
    }
    if (_recipientMode == 'goshen_paid_week' && _paidWeek == null) {
      _showSnack('Choose the paid week.');
      return;
    }
    if (_recipientMode == 'goshen_paid_month' &&
        !_validMonth(_paidMonthController.text.trim())) {
      _showSnack('Enter the paid month as YYYY-MM.');
      return;
    }
    if (_recipientMode == 'fundraising_participants' &&
        _fundraisingCampaignId == null) {
      _showSnack('Choose a project support campaign.');
      return;
    }
    if (_recipientMode == 'quiz_participants' && _goshenQuizId == null) {
      _showSnack('Choose a quiz.');
      return;
    }
    if (_scheduleEnabled && _scheduledFor == null) {
      _showSnack('Choose when this message should be sent.');
      return;
    }

    setState(() => _sending = true);
    try {
      final result = await _api.send(
        user: widget.user,
        title: title,
        content: content,
        notificationCategory: _category,
        sendInbox: _sendInbox,
        sendPush: _sendPush,
        sendEmail: _sendEmail,
        recipientMode: _recipientMode,
        countries: _countries.toList(),
        genders: _genders.toList(),
        roleIds: _roleIds.toList(),
        goshenEventId: _goshenEventId,
        goshenPaidFrom: _paidFrom?.toIso8601String(),
        goshenPaidUntil: _paidUntil?.toIso8601String(),
        goshenRecentDays: _recipientMode == 'goshen_paid_recent_days'
            ? int.tryParse(_recentDaysController.text.trim())
            : null,
        goshenPaidWeek: _paidWeek == null
            ? null
            : '${_paidWeek!.year.toString().padLeft(4, '0')}-${_paidWeek!.month.toString().padLeft(2, '0')}-${_paidWeek!.day.toString().padLeft(2, '0')}',
        goshenPaidMonth: _recipientMode == 'goshen_paid_month'
            ? _paidMonthController.text.trim()
            : null,
        fundraisingCampaignId: _fundraisingCampaignId,
        goshenQuizId: _goshenQuizId,
        scheduledFor: _scheduleEnabled ? _scheduledFor : null,
      );
      if (!mounted) return;
      _titleController.clear();
      _contentController.clear();
      _showSnack(
        result.scheduled
            ? 'Message scheduled.'
            : 'Message sent. Push: ${result.pushSentCount} sent, ${result.pushFailedCount} failed. Email: ${result.emailSentCount} sent, ${result.emailFailedCount} failed.',
      );
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isGoshenMode(String mode) => mode.startsWith('goshen_');

  bool _validMonth(String value) => RegExp(r'^\d{4}-\d{2}$').hasMatch(value);

  void _setRecipientMode(String mode) {
    setState(() {
      _recipientMode = mode;
      _countries.clear();
      _genders.clear();
      _roleIds.clear();
      _goshenEventId = null;
      _fundraisingCampaignId = null;
      _goshenQuizId = null;
      _paidFrom = null;
      _paidUntil = null;
      _paidWeek = null;
    });
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickScheduledFor() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledFor ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledFor ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null) return;

    setState(() {
      _scheduledFor = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _openTagPicker({
    required ControlHubMessageOptions options,
    required TextEditingController controller,
  }) async {
    if (options.personalizationTags.isEmpty) {
      _showSnack('No personalization tags are available yet.');
      return;
    }

    final colors = _ManagementPalette.of(context);
    final selected = await showModalBottomSheet<ControlHubPersonalizationTag>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: options.personalizationTags.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tag = options.personalizationTags[index];
              return ListTile(
                leading: Icon(Icons.sell_rounded, color: colors.gold),
                title: Text(
                  tag.label,
                  style: TextStyle(
                    color: colors.deep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  tag.example.trim().isEmpty
                      ? tag.tag
                      : '${tag.tag} - ${tag.example}',
                ),
                onTap: () => Navigator.pop(context, tag),
              );
            },
          ),
        );
      },
    );

    if (selected == null) return;
    _insertTag(controller, selected.tag);
  }

  void _insertTag(TextEditingController controller, String tag) {
    final selection = controller.selection;
    final current = controller.text;
    final insertAt = selection.isValid ? selection.start : current.length;
    final endAt = selection.isValid ? selection.end : current.length;
    final prefix = current.substring(0, insertAt);
    final suffix = current.substring(endAt);
    final leadingSpace =
        prefix.isEmpty || RegExp(r'\s$').hasMatch(prefix) ? '' : ' ';
    final trailingSpace =
        suffix.isEmpty || RegExp(r'^\s').hasMatch(suffix) ? '' : ' ';
    final nextText = '$prefix$leadingSpace$tag$trailingSpace$suffix';
    final cursor = (prefix + leadingSpace + tag + trailingSpace).length;

    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Send Message'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<ControlHubMessageOptions>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _LoadingCard(colors: colors, label: 'Loading message tools...'),
              ],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _MessageCard(
                  colors: colors,
                  icon: Icons.cloud_off_rounded,
                  title: 'Unable to load message tools',
                  message:
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                  actionLabel: 'Retry',
                  onAction: () async {
                    final future = _api.fetchOptions(widget.user);
                    setState(() {
                      _future = future;
                    });
                    await future;
                  },
                ),
              ],
            );
          }

          final options = snapshot.data!;
          if (options.categories.isNotEmpty &&
              !options.categories.any((item) => item.key == _category)) {
            _category = options.categories.first.key;
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              32 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              _Panel(
                colors: colors,
                title: 'Admin message',
                subtitle:
                    'Publish an inbox message and optionally send a push notification.',
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          _managementInputDecoration(colors, 'Message title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contentController,
                      minLines: 5,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          _managementInputDecoration(colors, 'Message body'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openTagPicker(
                              options: options,
                              controller: _titleController,
                            ),
                            icon: const Icon(Icons.sell_rounded),
                            label: const Text('Title tag'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openTagPicker(
                              options: options,
                              controller: _contentController,
                            ),
                            icon: const Icon(Icons.sell_rounded),
                            label: const Text('Body tag'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration:
                          _managementInputDecoration(colors, 'Category'),
                      items: options.categories
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.key,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _category = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    _MessageChannelSwitch(
                      colors: colors,
                      title: 'Publish in app inbox',
                      subtitle: 'Members will see it in their Inbox.',
                      value: _sendInbox,
                      onChanged: (value) {
                        setState(() {
                          _sendInbox = value;
                          if (!_sendInbox) _sendPush = false;
                        });
                      },
                    ),
                    _MessageChannelSwitch(
                      colors: colors,
                      title: 'Send push notification',
                      subtitle: 'Requires app inbox delivery.',
                      value: _sendPush,
                      onChanged: (value) {
                        setState(() {
                          _sendPush = value;
                          if (_sendPush) _sendInbox = true;
                        });
                      },
                    ),
                    _MessageChannelSwitch(
                      colors: colors,
                      title: 'Send email',
                      subtitle: 'Uses the backend SMTP settings.',
                      value: _sendEmail,
                      onChanged: (value) => setState(() => _sendEmail = value),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _recipientMode,
                      isExpanded: true,
                      decoration:
                          _managementInputDecoration(colors, 'Recipients'),
                      items: _recipientModeLabels.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) _setRecipientMode(value);
                      },
                    ),
                    const SizedBox(height: 12),
                    _RecipientOptions(
                      colors: colors,
                      mode: _recipientMode,
                      options: options,
                      countries: _countries,
                      genders: _genders,
                      roleIds: _roleIds,
                      goshenEventId: _goshenEventId,
                      fundraisingCampaignId: _fundraisingCampaignId,
                      goshenQuizId: _goshenQuizId,
                      paidFrom: _paidFrom,
                      paidUntil: _paidUntil,
                      paidWeek: _paidWeek,
                      recentDaysController: _recentDaysController,
                      paidMonthController: _paidMonthController,
                      onGoshenEventChanged: (value) =>
                          setState(() => _goshenEventId = value),
                      onFundraisingCampaignChanged: (value) =>
                          setState(() => _fundraisingCampaignId = value),
                      onGoshenQuizChanged: (value) =>
                          setState(() => _goshenQuizId = value),
                      onPickPaidFrom: () => _pickDate(
                        initial: _paidFrom,
                        onPicked: (value) => setState(() => _paidFrom = value),
                      ),
                      onPickPaidUntil: () => _pickDate(
                        initial: _paidUntil,
                        onPicked: (value) => setState(() => _paidUntil = value),
                      ),
                      onPickPaidWeek: () => _pickDate(
                        initial: _paidWeek,
                        onPicked: (value) => setState(() => _paidWeek = value),
                      ),
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _ScheduleMessageControl(
                      colors: colors,
                      enabled: _scheduleEnabled,
                      scheduledFor: _scheduledFor,
                      onEnabledChanged: (value) => setState(() {
                        _scheduleEnabled = value;
                        if (!_scheduleEnabled) _scheduledFor = null;
                      }),
                      onPick: _pickScheduledFor,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(_sending
                          ? 'Sending...'
                          : (_scheduleEnabled
                              ? 'Schedule message'
                              : 'Send message')),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.gold,
                        foregroundColor: colors.deep,
                        minimumSize: const Size.fromHeight(52),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class FundraisingManagementStatsScreen extends StatefulWidget {
  const FundraisingManagementStatsScreen({
    super.key,
    required this.user,
  });

  final Userdata user;

  @override
  State<FundraisingManagementStatsScreen> createState() =>
      _FundraisingManagementStatsScreenState();
}

class _FundraisingManagementStatsScreenState
    extends State<FundraisingManagementStatsScreen> {
  final _api = FundraisingApi();
  final Set<int> _campaignUpdates = <int>{};
  late Future<FundraisingManagementSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchManagementSummary(widget.user);
  }

  Future<void> _refresh() async {
    final future = _api.fetchManagementSummary(widget.user);
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _changeCampaignStatus(
    FundraisingManagementCampaignRow row,
    String status,
  ) async {
    final label = _fundraisingCampaignActionLabel(status).toLowerCase();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update campaign status'),
            content: Text('Do you want to $label "${row.displayTitle}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _campaignUpdates.add(row.id));

    try {
      await _api.updateManagementCampaignStatus(
        user: widget.user,
        campaign: row,
        status: status,
      );

      final future = _api.fetchManagementSummary(widget.user);
      if (!mounted) return;
      setState(() {
        _future = future;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Campaign status updated.')),
      );
      await future;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _campaignUpdates.remove(row.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Project support stats'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<FundraisingManagementSummary>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _LoadingCard(
                    colors: colors,
                    label: 'Loading project support stats...',
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _MessageCard(
                    colors: colors,
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load project support stats',
                    message: snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  ),
                ],
              );
            }

            final summary = snapshot.data!;
            final totals = summary.totals;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _FundraisingTotalsGrid(colors: colors, totals: totals),
                const SizedBox(height: 14),
                _FundraisingProgressCard(colors: colors, totals: totals),
                const SizedBox(height: 14),
                _BreakdownCard(
                  colors: colors,
                  title: 'Campaign status',
                  subtitle: 'Campaigns grouped by current status',
                  rows: _fundraisingRows(summary.breakdowns.campaignStatus),
                  showDonut: true,
                ),
                const SizedBox(height: 14),
                _BreakdownCard(
                  colors: colors,
                  title: 'Contribution status',
                  subtitle: 'Support records by settlement status',
                  rows: _fundraisingRows(summary.breakdowns.contributionStatus),
                  showDonut: true,
                ),
                const SizedBox(height: 14),
                _DualBreakdownCard(
                  colors: colors,
                  leftTitle: 'Payment channels',
                  leftRows: _fundraisingRows(
                    summary.breakdowns.paymentProvider,
                  ),
                  rightTitle: 'Campaign progress',
                  rightRows: _fundraisingRows(
                    summary.breakdowns.campaignProgress,
                  ),
                ),
                const SizedBox(height: 14),
                _FundraisingCampaignsTableCard(
                  colors: colors,
                  rows: summary.campaigns,
                  updatingIds: _campaignUpdates,
                  onStatusChange: _changeCampaignStatus,
                ),
                const SizedBox(height: 14),
                _FundraisingContributionsTableCard(
                  colors: colors,
                  rows: summary.recentContributions,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

List<GoshenManagementBreakdownRow> _fundraisingRows(
  List<FundraisingManagementBreakdownRow> rows,
) {
  return rows
      .map(
        (row) => GoshenManagementBreakdownRow(
          key: row.key,
          label: row.label,
          count: row.count,
          amount: row.amount,
          percentage: row.percentage,
        ),
      )
      .toList();
}

List<GoshenManagementBreakdownRow> _experienceRows(Map<String, int> rows) {
  return rows.entries
      .where((entry) => entry.value > 0)
      .map(
        (entry) => GoshenManagementBreakdownRow(
          key: entry.key,
          label: entry.key.trim().isEmpty ? 'Not specified' : entry.key,
          count: entry.value,
        ),
      )
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));
}

class _WithdrawalTotalsGrid extends StatelessWidget {
  const _WithdrawalTotalsGrid({
    required this.colors,
    required this.totals,
  });

  final _ManagementPalette colors;
  final Map<String, dynamic> totals;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        'Pending',
        _number(int.tryParse('${totals['pending'] ?? 0}') ?? 0),
        Icons.pending_actions_rounded,
      ),
      _MetricData(
        'Approved',
        _number(int.tryParse('${totals['approved'] ?? 0}') ?? 0),
        Icons.verified_outlined,
      ),
      _MetricData(
        'Paid',
        _number(int.tryParse('${totals['paid'] ?? 0}') ?? 0),
        Icons.payments_outlined,
      ),
      _MetricData(
        'Rejected',
        _number(int.tryParse('${totals['rejected'] ?? 0}') ?? 0),
        Icons.cancel_outlined,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 142,
      ),
      itemBuilder: (context, index) =>
          _MetricTile(colors: colors, data: metrics[index]),
    );
  }
}

class _WithdrawalManagementTile extends StatelessWidget {
  const _WithdrawalManagementTile({
    required this.colors,
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onPaid,
  });

  final _ManagementPalette colors;
  final GoshenWalletWithdrawalRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (request.status) {
      'paid' => colors.success,
      'approved' => colors.teal,
      'rejected' || 'cancelled' => colors.danger,
      _ => colors.gold,
    };
    final canAct = !busy && request.isOpen;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  request.memberName.isEmpty
                      ? 'Unknown member'
                      : request.memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(label: request.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _managementMoney(request.amount, request.currency),
            style: TextStyle(
              color: colors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _WithdrawalDetailLine(
            colors: colors,
            icon: Icons.mail_outline_rounded,
            text: request.memberEmail,
          ),
          _WithdrawalDetailLine(
            colors: colors,
            icon: Icons.account_balance_outlined,
            text: [
              request.bankName,
              request.accountName,
              request.accountNumber,
              request.sortCode,
            ].where((value) => value.trim().isNotEmpty).join(' - '),
          ),
          if (request.iban.trim().isNotEmpty)
            _WithdrawalDetailLine(
              colors: colors,
              icon: Icons.public_rounded,
              text: request.iban,
            ),
          if (request.userNote.trim().isNotEmpty)
            _WithdrawalDetailLine(
              colors: colors,
              icon: Icons.notes_rounded,
              text: request.userNote,
            ),
          if (request.payoutReference.trim().isNotEmpty)
            _WithdrawalDetailLine(
              colors: colors,
              icon: Icons.tag_rounded,
              text: request.payoutReference,
            ),
          if (busy) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.gold),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed:
                    canAct && request.status == 'pending' ? onApprove : null,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Approve'),
              ),
              FilledButton.icon(
                onPressed: canAct ? onPaid : null,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Mark paid'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.gold,
                  foregroundColor: colors.deep,
                ),
              ),
              OutlinedButton.icon(
                onPressed: canAct ? onReject : null,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.danger,
                  side: BorderSide(color: colors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WithdrawalDetailLine extends StatelessWidget {
  const _WithdrawalDetailLine({
    required this.colors,
    required this.icon,
    required this.text,
  });

  final _ManagementPalette colors;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colors.muted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.muted,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageChannelSwitch extends StatelessWidget {
  const _MessageChannelSwitch({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final _ManagementPalette colors;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          color: colors.text,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colors.muted, fontWeight: FontWeight.w700),
      ),
      value: value,
      activeColor: colors.gold,
      onChanged: onChanged,
    );
  }
}

class _ScheduleMessageControl extends StatelessWidget {
  const _ScheduleMessageControl({
    required this.colors,
    required this.enabled,
    required this.scheduledFor,
    required this.onEnabledChanged,
    required this.onPick,
  });

  final _ManagementPalette colors;
  final bool enabled;
  final DateTime? scheduledFor;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MessageChannelSwitch(
          colors: colors,
          title: 'Schedule for later',
          subtitle: 'Send this message at a selected date and time.',
          value: enabled,
          onChanged: onEnabledChanged,
        ),
        if (enabled)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.schedule_rounded),
              label: Text(scheduledFor == null
                  ? 'Choose send time'
                  : 'Send ${_dateTimeLabel(scheduledFor!)}'),
            ),
          ),
      ],
    );
  }
}

class _RecipientOptions extends StatelessWidget {
  const _RecipientOptions({
    required this.colors,
    required this.mode,
    required this.options,
    required this.countries,
    required this.genders,
    required this.roleIds,
    required this.goshenEventId,
    required this.fundraisingCampaignId,
    required this.goshenQuizId,
    required this.paidFrom,
    required this.paidUntil,
    required this.paidWeek,
    required this.recentDaysController,
    required this.paidMonthController,
    required this.onGoshenEventChanged,
    required this.onFundraisingCampaignChanged,
    required this.onGoshenQuizChanged,
    required this.onPickPaidFrom,
    required this.onPickPaidUntil,
    required this.onPickPaidWeek,
    required this.onChanged,
  });

  final _ManagementPalette colors;
  final String mode;
  final ControlHubMessageOptions options;
  final Set<String> countries;
  final Set<String> genders;
  final Set<int> roleIds;
  final int? goshenEventId;
  final int? fundraisingCampaignId;
  final int? goshenQuizId;
  final DateTime? paidFrom;
  final DateTime? paidUntil;
  final DateTime? paidWeek;
  final TextEditingController recentDaysController;
  final TextEditingController paidMonthController;
  final ValueChanged<int?> onGoshenEventChanged;
  final ValueChanged<int?> onFundraisingCampaignChanged;
  final ValueChanged<int?> onGoshenQuizChanged;
  final VoidCallback onPickPaidFrom;
  final VoidCallback onPickPaidUntil;
  final VoidCallback onPickPaidWeek;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (mode == 'all') {
      return _EmptyInline(
        colors: colors,
        text: 'This message will go to all active app users.',
      );
    }

    if (mode == 'countries') {
      return _OptionWrap<String>(
        colors: colors,
        options: options.countries,
        selected: countries,
        labelFor: (value) => value,
        onChanged: onChanged,
      );
    }

    if (mode == 'genders') {
      return _OptionWrap<String>(
        colors: colors,
        options: options.genders,
        selected: genders,
        labelFor: (value) => value,
        onChanged: onChanged,
      );
    }

    if (mode == 'roles') {
      return _OptionWrap<int>(
        colors: colors,
        options: options.roles.map((role) => role.id).toList(),
        selected: roleIds,
        labelFor: (value) => options.roles
            .firstWhere(
              (role) => role.id == value,
              orElse: () => ControlHubRoleOption(id: value, name: '$value'),
            )
            .name,
        onChanged: onChanged,
      );
    }

    if (mode.startsWith('goshen_')) {
      return _GoshenAudienceOptions(
        colors: colors,
        mode: mode,
        events: options.goshenEvents,
        selectedEventId: goshenEventId,
        paidFrom: paidFrom,
        paidUntil: paidUntil,
        paidWeek: paidWeek,
        recentDaysController: recentDaysController,
        paidMonthController: paidMonthController,
        onEventChanged: onGoshenEventChanged,
        onPickPaidFrom: onPickPaidFrom,
        onPickPaidUntil: onPickPaidUntil,
        onPickPaidWeek: onPickPaidWeek,
      );
    }

    if (mode == 'fundraising_participants') {
      return _IdDropdown(
        colors: colors,
        label: 'Project support campaign',
        options: options.fundraisingCampaigns,
        value: fundraisingCampaignId,
        onChanged: onFundraisingCampaignChanged,
      );
    }

    if (mode == 'quiz_participants') {
      return _IdDropdown(
        colors: colors,
        label: 'Quiz',
        options: options.quizzes,
        value: goshenQuizId,
        onChanged: onGoshenQuizChanged,
      );
    }

    return _EmptyInline(
      colors: colors,
      text: 'Choose a recipient audience.',
    );
  }
}

class _OptionWrap<T> extends StatelessWidget {
  const _OptionWrap({
    required this.colors,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
  });

  final _ManagementPalette colors;
  final List<T> options;
  final Set<T> selected;
  final String Function(T value) labelFor;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return _EmptyInline(
          colors: colors, text: 'No options are available yet.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (value) => FilterChip(
              selected: selected.contains(value),
              label: Text(labelFor(value)),
              onSelected: (isSelected) {
                if (isSelected) {
                  selected.add(value);
                } else {
                  selected.remove(value);
                }
                onChanged();
              },
            ),
          )
          .toList(),
    );
  }
}

class _GoshenAudienceOptions extends StatelessWidget {
  const _GoshenAudienceOptions({
    required this.colors,
    required this.mode,
    required this.events,
    required this.selectedEventId,
    required this.paidFrom,
    required this.paidUntil,
    required this.paidWeek,
    required this.recentDaysController,
    required this.paidMonthController,
    required this.onEventChanged,
    required this.onPickPaidFrom,
    required this.onPickPaidUntil,
    required this.onPickPaidWeek,
  });

  final _ManagementPalette colors;
  final String mode;
  final List<ControlHubIdOption> events;
  final int? selectedEventId;
  final DateTime? paidFrom;
  final DateTime? paidUntil;
  final DateTime? paidWeek;
  final TextEditingController recentDaysController;
  final TextEditingController paidMonthController;
  final ValueChanged<int?> onEventChanged;
  final VoidCallback onPickPaidFrom;
  final VoidCallback onPickPaidUntil;
  final VoidCallback onPickPaidWeek;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IdDropdown(
          colors: colors,
          label: 'Goshen retreat edition',
          options: events,
          value: selectedEventId,
          onChanged: onEventChanged,
        ),
        if (mode == 'goshen_paid_between') ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickPaidFrom,
                  icon: const Icon(Icons.event_rounded),
                  label: Text(paidFrom == null
                      ? 'Paid from'
                      : _compactDateLabel(paidFrom!)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickPaidUntil,
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(paidUntil == null
                      ? 'Paid until'
                      : _compactDateLabel(paidUntil!)),
                ),
              ),
            ],
          ),
        ],
        if (mode == 'goshen_paid_recent_days') ...[
          const SizedBox(height: 10),
          TextField(
            controller: recentDaysController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration:
                _managementInputDecoration(colors, 'Number of recent days'),
          ),
        ],
        if (mode == 'goshen_paid_week') ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPickPaidWeek,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(paidWeek == null
                  ? 'Choose week'
                  : 'Week of ${_compactDateLabel(paidWeek!)}'),
            ),
          ),
        ],
        if (mode == 'goshen_paid_month') ...[
          const SizedBox(height: 10),
          TextField(
            controller: paidMonthController,
            keyboardType: TextInputType.datetime,
            decoration:
                _managementInputDecoration(colors, 'Paid month YYYY-MM'),
          ),
        ],
      ],
    );
  }
}

class _IdDropdown extends StatelessWidget {
  const _IdDropdown({
    required this.colors,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final _ManagementPalette colors;
  final String label;
  final List<ControlHubIdOption> options;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return _EmptyInline(
        colors: colors,
        text: 'No $label options are available yet.',
      );
    }

    return DropdownButtonFormField<int>(
      value: options.any((item) => item.id == value) ? value : null,
      isExpanded: true,
      decoration: _managementInputDecoration(colors, label),
      items: options
          .map(
            (item) => DropdownMenuItem<int>(
              value: item.id,
              child: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _FundraisingTotalsGrid extends StatelessWidget {
  const _FundraisingTotalsGrid({
    required this.colors,
    required this.totals,
  });

  final _ManagementPalette colors;
  final FundraisingManagementTotals totals;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        'Campaigns',
        _number(totals.campaigns),
        Icons.campaign_outlined,
      ),
      _MetricData(
        'Active',
        _number(totals.activeCampaigns),
        Icons.play_circle_outline_rounded,
      ),
      _MetricData(
        'Raised',
        totals.money(totals.raisedAmount),
        Icons.savings_outlined,
      ),
      _MetricData(
        'All time',
        totals.money(totals.allTimeRaisedAmount),
        Icons.timeline_rounded,
      ),
      _MetricData(
        'Supporters',
        _number(totals.succeededContributions),
        Icons.groups_2_outlined,
      ),
      _MetricData(
        'Pending',
        totals.money(totals.pendingAmount),
        Icons.hourglass_bottom_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map((item) => SizedBox(
                    width: width,
                    child: _MetricTile(colors: colors, data: item),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _FundraisingProgressCard extends StatelessWidget {
  const _FundraisingProgressCard({
    required this.colors,
    required this.totals,
  });

  final _ManagementPalette colors;
  final FundraisingManagementTotals totals;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Project support progress',
      trailing: Text(
        '${(totals.raisedProgress * 100).round()}%',
        style: TextStyle(
          color: colors.text,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: totals.raisedProgress,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.gold),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Goal',
                  value: totals.money(totals.goalAmount),
                ),
              ),
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Raised',
                  value: totals.money(totals.raisedAmount),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Wallet',
                  value: totals.money(totals.walletAmount),
                ),
              ),
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Card',
                  value: totals.money(totals.stripeAmount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FundraisingCampaignsTableCard extends StatelessWidget {
  const _FundraisingCampaignsTableCard({
    required this.colors,
    required this.rows,
    required this.updatingIds,
    required this.onStatusChange,
  });

  final _ManagementPalette colors;
  final List<FundraisingManagementCampaignRow> rows;
  final Set<int> updatingIds;
  final Future<void> Function(
    FundraisingManagementCampaignRow row,
    String status,
  ) onStatusChange;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Campaigns',
      subtitle: 'Recent campaigns and progress',
      child: rows.isEmpty
          ? _EmptyInline(colors: colors, text: 'No campaigns yet.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
                dataTextStyle: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w700,
                ),
                columns: const [
                  DataColumn(label: Text('Campaign')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Raised')),
                  DataColumn(label: Text('Goal')),
                  DataColumn(label: Text('Progress')),
                  DataColumn(label: Text('Donors')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: rows.take(20).map((row) {
                  final updating = updatingIds.contains(row.id);
                  return DataRow(
                    cells: [
                      DataCell(Text(row.displayTitle)),
                      DataCell(Text(row.status)),
                      DataCell(Text(row.money(row.raisedAmount))),
                      DataCell(Text(row.money(row.goalAmount))),
                      DataCell(Text('${row.progressPercentage.round()}%')),
                      DataCell(Text(_number(row.donorCount))),
                      DataCell(
                        _FundraisingCampaignActions(
                          colors: colors,
                          row: row,
                          updating: updating,
                          onStatusChange: onStatusChange,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class _FundraisingCampaignActions extends StatelessWidget {
  const _FundraisingCampaignActions({
    required this.colors,
    required this.row,
    required this.updating,
    required this.onStatusChange,
  });

  final _ManagementPalette colors;
  final FundraisingManagementCampaignRow row;
  final bool updating;
  final Future<void> Function(
    FundraisingManagementCampaignRow row,
    String status,
  ) onStatusChange;

  @override
  Widget build(BuildContext context) {
    final actions = row.availableActions;
    if (actions.isEmpty) {
      return Text(
        'No actions',
        style: TextStyle(color: colors.muted),
      );
    }

    if (updating) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(colors.gold),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      children: actions.map((action) {
        final label = _fundraisingCampaignActionLabel(action);
        return TextButton.icon(
          onPressed: () => onStatusChange(row, action),
          icon: Icon(_fundraisingCampaignActionIcon(action), size: 16),
          label: Text(label),
          style: TextButton.styleFrom(
            foregroundColor:
                action == 'closed' ? Colors.red.shade700 : colors.deep,
            visualDensity: VisualDensity.compact,
          ),
        );
      }).toList(),
    );
  }
}

String _fundraisingCampaignActionLabel(String action) {
  switch (action) {
    case 'active':
      return 'Publish';
    case 'paused':
      return 'Pause';
    case 'closed':
      return 'Close';
    default:
      return _managementSentenceLabel(action);
  }
}

String _managementSentenceLabel(String value) {
  final clean = value.replaceAll('_', ' ').trim();
  if (clean.isEmpty) return 'Update';
  return clean[0].toUpperCase() + clean.substring(1);
}

IconData _fundraisingCampaignActionIcon(String action) {
  switch (action) {
    case 'active':
      return Icons.play_circle_outline_rounded;
    case 'paused':
      return Icons.pause_circle_outline_rounded;
    case 'closed':
      return Icons.lock_outline_rounded;
    default:
      return Icons.tune_rounded;
  }
}

class _FundraisingContributionsTableCard extends StatelessWidget {
  const _FundraisingContributionsTableCard({
    required this.colors,
    required this.rows,
  });

  final _ManagementPalette colors;
  final List<FundraisingManagementContributionRow> rows;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Recent contributions',
      subtitle: 'Latest wallet and card support records',
      child: rows.isEmpty
          ? _EmptyInline(colors: colors, text: 'No contributions yet.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
                dataTextStyle: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w700,
                ),
                columns: const [
                  DataColumn(label: Text('Campaign')),
                  DataColumn(label: Text('Supporter')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Provider')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Date')),
                ],
                rows: rows.take(25).map((row) {
                  return DataRow(
                    cells: [
                      DataCell(Text(row.campaignTitle)),
                      DataCell(Text(row.displayName)),
                      DataCell(Text(row.amountLabel)),
                      DataCell(Text(row.paymentProvider)),
                      DataCell(Text(row.status)),
                      DataCell(Text(row.paidAtLabel)),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class _ManagementHeroCard extends StatelessWidget {
  const _ManagementHeroCard({required this.colors});

  final _ManagementPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.deep, const Color(0xFF14513F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.22 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.admin_panel_settings_rounded,
                color: colors.gold, size: 30),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Goshen control hub',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Registration insight, scanner operations, and event tools for approved managers.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
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

class _HubActionCard extends StatelessWidget {
  const _HubActionCard({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.accent,
    this.disabledSubtitle,
  });

  final _ManagementPalette colors;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? accent;
  final String? disabledSubtitle;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent ?? colors.gold;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: enabled ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: enabled ? colors.card : colors.innerCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: effectiveAccent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: effectiveAccent, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled ? colors.text : colors.muted,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      enabled
                          ? subtitle
                          : (disabledSubtitle ??
                              'No retreat event is available yet.'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.muted,
                        height: 1.32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: enabled ? colors.muted : colors.border, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventSelector extends StatelessWidget {
  const _EventSelector({
    required this.colors,
    required this.events,
    required this.selected,
    required this.onChanged,
  });

  final _ManagementPalette colors;
  final List<GoshenRetreatEvent> events;
  final GoshenRetreatEvent selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonFormField<String>(
        value: selected.publicId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Event',
          border: InputBorder.none,
          isDense: true,
        ),
        items: events
            .map(
              (event) => DropdownMenuItem<String>(
                value: event.publicId,
                child: Text(
                  event.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _RegistrationStatusCard extends StatelessWidget {
  const _RegistrationStatusCard({
    required this.colors,
    required this.summary,
  });

  final _ManagementPalette colors;
  final GoshenManagementSummary summary;

  @override
  Widget build(BuildContext context) {
    final registration = summary.event.registration;
    final statusColor = registration.open ? colors.success : colors.danger;
    return _Panel(
      colors: colors,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              registration.open
                  ? Icons.lock_open_rounded
                  : Icons.lock_outline_rounded,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.event.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusPill(
                      label: registration.open ? 'Registration open' : 'Closed',
                      color: statusColor,
                    ),
                    _StatusPill(
                      label: registration.override,
                      color: colors.gold,
                    ),
                  ],
                ),
                if (registration.message.trim().isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    registration.message,
                    style: TextStyle(color: colors.muted, height: 1.35),
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

class _RegistrationControlCard extends StatefulWidget {
  const _RegistrationControlCard({
    required this.colors,
    required this.event,
    required this.summary,
    required this.onSetOpen,
  });

  final _ManagementPalette colors;
  final GoshenRetreatEvent event;
  final GoshenManagementSummary summary;
  final Future<void> Function(bool open) onSetOpen;

  @override
  State<_RegistrationControlCard> createState() =>
      _RegistrationControlCardState();
}

class _RegistrationControlCardState extends State<_RegistrationControlCard> {
  bool _busy = false;

  Future<void> _setOpen(bool open) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSetOpen(open);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registration = widget.summary.event.registration;
    final open = registration.open;
    final statusColor = open ? widget.colors.success : widget.colors.danger;

    return _Panel(
      colors: widget.colors,
      title: 'Registration control',
      subtitle: open
          ? 'Close registration immediately when the retreat is full or paused.'
          : 'Reopen registration when members can book again.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  open ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  registration.message.trim().isNotEmpty
                      ? registration.message
                      : (open
                          ? 'Registration is open.'
                          : 'Registration is closed.'),
                  style: TextStyle(
                    color: widget.colors.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: open ? widget.colors.danger : widget.colors.gold,
              foregroundColor: open ? Colors.white : widget.colors.text,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _busy ? null : () => _setOpen(!open),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Icon(open ? Icons.lock_rounded : Icons.lock_open_rounded),
            label: Text(
              _busy
                  ? 'Updating...'
                  : open
                      ? 'Close registration'
                      : 'Reopen registration',
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsGrid extends StatelessWidget {
  const _TotalsGrid({
    required this.colors,
    required this.totals,
  });

  final _ManagementPalette colors;
  final GoshenManagementTotals totals;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData('Registrations', _number(totals.registrations),
          Icons.receipt_long_outlined),
      _MetricData(
          'Attendees', _number(totals.attendees), Icons.groups_2_outlined),
      _MetricData('Paid', _number(totals.paidRegistrations),
          Icons.check_circle_outline_rounded),
      _MetricData('Pending', _number(totals.pendingRegistrations),
          Icons.hourglass_bottom_rounded),
      _MetricData('Cancelled', _number(totals.cancelledRegistrations),
          Icons.cancel_outlined),
      _MetricData('Total value', totals.money(totals.totalAmount),
          Icons.account_balance_wallet_outlined),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map((item) => SizedBox(
                    width: width,
                    child: _MetricTile(colors: colors, data: item),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _PaymentProgressCard extends StatelessWidget {
  const _PaymentProgressCard({
    required this.colors,
    required this.totals,
  });

  final _ManagementPalette colors;
  final GoshenManagementTotals totals;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Payment progress',
      trailing: Text(
        '${(totals.paidProgress * 100).round()}%',
        style: TextStyle(
          color: colors.text,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: totals.paidProgress,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.gold),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Paid',
                  value: totals.money(totals.paidAmount),
                ),
              ),
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Balance',
                  value: totals.money(totals.balanceAmount),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Wallet',
                  value: totals.money(totals.walletPaidAmount),
                ),
              ),
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Voucher',
                  value: totals.money(totals.voucherPaidAmount),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AmountLine(
                  colors: colors,
                  label: 'Online',
                  value: totals.money(totals.onlinePaidAmount),
                ),
              ),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.rows,
    this.showDonut = false,
  });

  final _ManagementPalette colors;
  final String title;
  final String subtitle;
  final List<GoshenManagementBreakdownRow> rows;
  final bool showDonut;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: title,
      subtitle: subtitle,
      child: rows.isEmpty
          ? _EmptyInline(colors: colors, text: 'No response data yet.')
          : Column(
              children: [
                if (showDonut) ...[
                  _DonutSummary(colors: colors, rows: rows),
                  const SizedBox(height: 14),
                ],
                ...rows.map(
                  (row) => _BreakdownProgressRow(
                    colors: colors,
                    row: row,
                    total: _totalCount(rows),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DualBreakdownCard extends StatelessWidget {
  const _DualBreakdownCard({
    required this.colors,
    required this.leftTitle,
    required this.leftRows,
    required this.rightTitle,
    required this.rightRows,
  });

  final _ManagementPalette colors;
  final String leftTitle;
  final List<GoshenManagementBreakdownRow> leftRows;
  final String rightTitle;
  final List<GoshenManagementBreakdownRow> rightRows;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Operational summary',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 420;
          final left = _CompactBreakdown(
            colors: colors,
            title: leftTitle,
            rows: leftRows,
          );
          final right = _CompactBreakdown(
            colors: colors,
            title: rightTitle,
            rows: rightRows,
          );
          if (stack) {
            return Column(
              children: [
                left,
                const SizedBox(height: 14),
                right,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 14),
              Expanded(child: right),
            ],
          );
        },
      ),
    );
  }
}

class _RegistrationsTableCard extends StatelessWidget {
  const _RegistrationsTableCard({
    required this.colors,
    required this.rows,
    required this.totals,
  });

  final _ManagementPalette colors;
  final List<GoshenManagementRegistrationRow> rows;
  final GoshenManagementTotals totals;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Registration table',
      subtitle: 'Recent bookings and payment status',
      child: rows.isEmpty
          ? _EmptyInline(colors: colors, text: 'No registrations yet.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
                dataTextStyle: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w700,
                ),
                columns: const [
                  DataColumn(label: Text('Ref')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Mode')),
                  DataColumn(label: Text('Att')),
                  DataColumn(label: Text('Paid')),
                  DataColumn(label: Text('Bal')),
                ],
                rows: rows.take(20).map((row) {
                  return DataRow(
                    cells: [
                      DataCell(Text(row.displayReference)),
                      DataCell(Text(row.displayName)),
                      DataCell(Text(row.status)),
                      DataCell(Text(row.paymentMode)),
                      DataCell(Text(_number(row.attendeesCount))),
                      DataCell(Text(totals.money(row.paidAmount))),
                      DataCell(Text(totals.money(row.balanceAmount))),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class _AttendeesTableCard extends StatelessWidget {
  const _AttendeesTableCard({
    required this.colors,
    required this.rows,
  });

  final _ManagementPalette colors;
  final List<GoshenManagementAttendeeRow> rows;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Attendee answers',
      subtitle:
          'Registration answers, optional company details, and ticket choices',
      child: rows.isEmpty
          ? _EmptyInline(colors: colors, text: 'No attendee answers yet.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
                dataTextStyle: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w700,
                ),
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Contact')),
                  DataColumn(label: Text('Gender')),
                  DataColumn(label: Text('Age')),
                  DataColumn(label: Text('Bus')),
                  DataColumn(label: Text('Volunteer')),
                  DataColumn(label: Text('Company')),
                  DataColumn(label: Text('Designation')),
                  DataColumn(label: Text('Ticket')),
                ],
                rows: rows.take(25).map((row) {
                  final contact = [
                    row.email,
                    row.phone,
                  ].where((value) => value.trim().isNotEmpty).join('\n');
                  return DataRow(
                    cells: [
                      DataCell(Text(row.displayName)),
                      DataCell(
                          Text(contact.isEmpty ? 'Not provided' : contact)),
                      DataCell(Text(row.gender)),
                      DataCell(Text(row.ageGroup)),
                      DataCell(Text(row.freeChurchBusInterest)),
                      DataCell(Text(row.volunteerDepartment)),
                      DataCell(Text(row.displayCompany)),
                      DataCell(Text(row.displayDesignation)),
                      DataCell(Text(row.ticketType)),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class _VoucherVerifyPanel extends StatelessWidget {
  const _VoucherVerifyPanel({
    required this.colors,
    required this.controller,
    required this.verifying,
    required this.verification,
    required this.onVerify,
  });

  final _ManagementPalette colors;
  final TextEditingController controller;
  final bool verifying;
  final GoshenVoucherVerification? verification;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final result = verification;
    return _Panel(
      colors: colors,
      title: 'Verify voucher',
      subtitle: 'Check a voucher before accepting offline payment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Voucher code',
              filled: true,
              fillColor: colors.innerCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.gold,
                foregroundColor: colors.deep,
              ),
              onPressed: verifying ? null : onVerify,
              icon: verifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: Text(verifying ? 'Checking...' : 'Verify voucher'),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: result.valid
                    ? colors.teal.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: result.valid ? colors.teal : Colors.red.shade300,
                ),
              ),
              child: Text(
                result.voucher == null
                    ? result.message
                    : '${result.message}\n${result.voucher!.statusLabel} · ${result.voucher!.redemptionSummary}',
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoucherGeneratePanel extends StatelessWidget {
  const _VoucherGeneratePanel({
    required this.colors,
    required this.labelController,
    required this.amountController,
    required this.currencyController,
    required this.quantityController,
    required this.maxUsesController,
    required this.purpose,
    required this.redemptionType,
    required this.generating,
    required this.generated,
    required this.onPurposeChanged,
    required this.onRedemptionTypeChanged,
    required this.onGenerate,
    required this.onCopyGenerated,
  });

  final _ManagementPalette colors;
  final TextEditingController labelController;
  final TextEditingController amountController;
  final TextEditingController currencyController;
  final TextEditingController quantityController;
  final TextEditingController maxUsesController;
  final String purpose;
  final String redemptionType;
  final bool generating;
  final List<GoshenGeneratedVoucher> generated;
  final ValueChanged<String> onPurposeChanged;
  final ValueChanged<String> onRedemptionTypeChanged;
  final VoidCallback onGenerate;
  final VoidCallback onCopyGenerated;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Generate vouchers',
      subtitle:
          'Wallet security verification is required before codes are created',
      child: Column(
        children: [
          _VoucherTextField(
            colors: colors,
            controller: labelController,
            label: 'Batch label',
          ),
          const SizedBox(height: 10),
          _ManagedDropdown(
            colors: colors,
            label: 'Purpose',
            value: purpose,
            items: const {
              GoshenVoucherInfo.purposePayments: 'For Payments',
              GoshenVoucherInfo.purposeWalletFunding: 'Wallet Funding',
            },
            onChanged: onPurposeChanged,
          ),
          const SizedBox(height: 10),
          if (purpose == GoshenVoucherInfo.purposePayments) ...[
            _ManagedDropdown(
              colors: colors,
              label: 'Voucher category',
              value: redemptionType,
              items: const {
                GoshenVoucherInfo.redemptionFixed: 'Fixed amount voucher',
                GoshenVoucherInfo.redemptionPool: 'Pool balance voucher',
              },
              onChanged: onRedemptionTypeChanged,
            ),
            const SizedBox(height: 8),
            _EmptyInline(
              colors: colors,
              text: redemptionType == GoshenVoucherInfo.redemptionPool
                  ? 'Pool balance: one shared pot. A family booking deducts the full attendee total; each individual ticket deducts its own total until the pool reaches zero.'
                  : 'Fixed amount: each redemption can cover up to this amount and consumes one use. This is the current voucher behaviour.',
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _VoucherTextField(
                  colors: colors,
                  controller: amountController,
                  label: redemptionType == GoshenVoucherInfo.redemptionPool
                      ? 'Pool budget'
                      : 'Amount',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VoucherTextField(
                  colors: colors,
                  controller: currencyController,
                  label: 'Currency',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _VoucherTextField(
                  colors: colors,
                  controller: quantityController,
                  label: 'Quantity',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VoucherTextField(
                  colors: colors,
                  controller: maxUsesController,
                  label: redemptionType == GoshenVoucherInfo.redemptionPool
                      ? 'Max redemptions'
                      : 'Uses/code',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.gold,
                foregroundColor: colors.deep,
              ),
              onPressed: generating ? null : onGenerate,
              icon: generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fingerprint_rounded),
              label: Text(generating ? 'Generating...' : 'Generate vouchers'),
            ),
          ),
          if (generated.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Generated codes',
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onCopyGenerated,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...generated.take(20).map(
                  (item) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.innerCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: SelectableText(
                      '${item.code}  ·  ${item.voucher.amountLabel}  ·  ${item.voucher.purposeLabel}  ·  ${item.voucher.categoryLabel}${item.voucher.isPoolVoucher ? '  ·  balance ${item.voucher.remainingAmountLabel}' : ''}',
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            if (generated.length > 20)
              _EmptyInline(
                colors: colors,
                text: 'Showing first 20 of ${_number(generated.length)} codes.',
              ),
          ],
        ],
      ),
    );
  }
}

class _VoucherTextField extends StatelessWidget {
  const _VoucherTextField({
    required this.controller,
    required this.label,
    this.colors,
    this.icon,
    this.keyboardType,
  });

  final _ManagementPalette? colors;
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final palette = colors ?? _ManagementPalette.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: palette.innerCard,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _ManagedDropdown extends StatelessWidget {
  const _ManagedDropdown({
    required this.colors,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final _ManagementPalette colors;
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.containsKey(value)
        ? value
        : (items.isEmpty ? '' : items.keys.first);
    return DropdownButtonFormField<String>(
      value: safeValue.isEmpty ? null : safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: colors.innerCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      items: items.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (selected) {
        if (selected != null && selected.isNotEmpty) onChanged(selected);
      },
    );
  }
}

class _VoucherUsagePanel extends StatelessWidget {
  const _VoucherUsagePanel({
    required this.colors,
    required this.rows,
  });

  final _ManagementPalette colors;
  final List<GoshenVoucherUsage> rows;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Voucher usage',
      subtitle: 'Latest redeemed vouchers for the selected retreat edition',
      child: rows.isEmpty
          ? _EmptyInline(colors: colors, text: 'No voucher usage yet.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
                dataTextStyle: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w700,
                ),
                columns: const [
                  DataColumn(label: Text('Code')),
                  DataColumn(label: Text('Member')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Source')),
                  DataColumn(label: Text('Date')),
                ],
                rows: rows.take(50).map((row) {
                  final member = [
                    row.memberName,
                    row.memberEmail,
                  ].where((value) => value.trim().isNotEmpty).join('\n');
                  return DataRow(
                    cells: [
                      DataCell(Text(row.codeSuffix)),
                      DataCell(Text(member.isEmpty ? 'Unknown' : member)),
                      DataCell(Text(row.amountLabel)),
                      DataCell(Text(row.sourceLabel)),
                      DataCell(Text(row.dateLabel)),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class _QuizManagementTotalsGrid extends StatelessWidget {
  const _QuizManagementTotalsGrid({
    required this.colors,
    required this.totals,
  });

  final _ManagementPalette colors;
  final GoshenQuizManagementTotals totals;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData('Quizzes', _number(totals.quizzes), Icons.quiz_rounded),
      _MetricData(
        'Active',
        _number(totals.activeQuizzes),
        Icons.play_circle_outline_rounded,
      ),
      _MetricData(
        'Attempts',
        _number(totals.attempts),
        Icons.fact_check_outlined,
      ),
      _MetricData(
        'Submitted',
        _number(totals.submittedAttempts),
        Icons.check_circle_outline_rounded,
      ),
      _MetricData(
        'Timed out',
        _number(totals.timedOutAttempts),
        Icons.hourglass_bottom_rounded,
      ),
      _MetricData(
        'Winners',
        _number(totals.winners),
        Icons.emoji_events_outlined,
      ),
      _MetricData(
        'Prize pending',
        _number(totals.pendingWalletPrizes),
        Icons.pending_actions_rounded,
      ),
      _MetricData(
        'Prize paid',
        _number(totals.paidWalletPrizes),
        Icons.account_balance_wallet_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 142,
          ),
          itemBuilder: (context, index) => _MetricTile(
            colors: colors,
            data: metrics[index],
          ),
        );
      },
    );
  }
}

class _QuizManagementList extends StatelessWidget {
  const _QuizManagementList({
    required this.colors,
    required this.quizzes,
    required this.busyQuizIds,
    required this.onActiveChanged,
    required this.onAutoSelectChanged,
    required this.onShowWinnersChanged,
    required this.onWalletPrizeChanged,
    required this.onPayWinnerPrize,
  });

  final _ManagementPalette colors;
  final List<GoshenQuizManagementRow> quizzes;
  final Set<int> busyQuizIds;
  final void Function(GoshenQuizManagementRow quiz, bool value) onActiveChanged;
  final void Function(GoshenQuizManagementRow quiz, bool value)
      onAutoSelectChanged;
  final void Function(GoshenQuizManagementRow quiz, bool value)
      onShowWinnersChanged;
  final void Function(GoshenQuizManagementRow quiz, bool value)
      onWalletPrizeChanged;
  final void Function(GoshenQuizManagementRow quiz, GoshenQuizWinner winner)
      onPayWinnerPrize;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Quiz controls',
      subtitle:
          'Open or close quizzes, choose winner handling, and monitor current results.',
      child: quizzes.isEmpty
          ? _EmptyInline(colors: colors, text: 'No quiz has been created yet.')
          : Column(
              children: [
                for (var index = 0; index < quizzes.length; index += 1) ...[
                  _QuizManagementCard(
                    colors: colors,
                    quiz: quizzes[index],
                    busy: busyQuizIds.contains(quizzes[index].id),
                    onActiveChanged: onActiveChanged,
                    onAutoSelectChanged: onAutoSelectChanged,
                    onShowWinnersChanged: onShowWinnersChanged,
                    onWalletPrizeChanged: onWalletPrizeChanged,
                    onPayWinnerPrize: onPayWinnerPrize,
                  ),
                  if (index != quizzes.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _QuizManagementCard extends StatelessWidget {
  const _QuizManagementCard({
    required this.colors,
    required this.quiz,
    required this.busy,
    required this.onActiveChanged,
    required this.onAutoSelectChanged,
    required this.onShowWinnersChanged,
    required this.onWalletPrizeChanged,
    required this.onPayWinnerPrize,
  });

  final _ManagementPalette colors;
  final GoshenQuizManagementRow quiz;
  final bool busy;
  final void Function(GoshenQuizManagementRow quiz, bool value) onActiveChanged;
  final void Function(GoshenQuizManagementRow quiz, bool value)
      onAutoSelectChanged;
  final void Function(GoshenQuizManagementRow quiz, bool value)
      onShowWinnersChanged;
  final void Function(GoshenQuizManagementRow quiz, bool value)
      onWalletPrizeChanged;
  final void Function(GoshenQuizManagementRow quiz, GoshenQuizWinner winner)
      onPayWinnerPrize;

  @override
  Widget build(BuildContext context) {
    final statusColor = quiz.isActive ? colors.success : colors.danger;
    return Container(
      width: double.infinity,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  quiz.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(label: quiz.statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuizInfoChip(
                colors: colors,
                icon: Icons.event_outlined,
                label:
                    quiz.eventName.trim().isEmpty ? 'No event' : quiz.eventName,
              ),
              _QuizInfoChip(
                colors: colors,
                icon: Icons.help_outline_rounded,
                label: '${_number(quiz.questionsCount)} questions',
              ),
              _QuizInfoChip(
                colors: colors,
                icon: Icons.fact_check_outlined,
                label: '${_number(quiz.submittedAttemptsCount)} submitted',
              ),
              _QuizInfoChip(
                colors: colors,
                icon: Icons.emoji_events_outlined,
                label:
                    '${_number(quiz.selectedWinnersCount)} of ${_number(quiz.winnersCount)} winners',
              ),
              _QuizInfoChip(
                colors: colors,
                icon: Icons.account_balance_wallet_outlined,
                label: quiz.prizeLabel,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (busy) ...[
            LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.gold),
            ),
            const SizedBox(height: 8),
          ],
          _QuizSwitchTile(
            colors: colors,
            title: 'Active quiz',
            subtitle: quiz.isActive
                ? 'Members can see and start this quiz.'
                : 'Hidden from members until reopened.',
            value: quiz.isActive,
            enabled: !busy,
            onChanged: (value) => onActiveChanged(quiz, value),
          ),
          _QuizSwitchTile(
            colors: colors,
            title: 'Auto-select winners',
            subtitle: 'Sync winners from submitted quiz attempts.',
            value: quiz.autoSelectWinners,
            enabled: !busy,
            onChanged: (value) => onAutoSelectChanged(quiz, value),
          ),
          _QuizSwitchTile(
            colors: colors,
            title: 'Show winners immediately',
            subtitle: 'Allow members to view the winners list after results.',
            value: quiz.showWinnersImmediately,
            enabled: !busy,
            onChanged: (value) => onShowWinnersChanged(quiz, value),
          ),
          _QuizSwitchTile(
            colors: colors,
            title: 'Wallet prize',
            subtitle: 'Permit wallet prize transfers for selected winners.',
            value: quiz.walletPrizeEnabled,
            enabled: !busy,
            onChanged: (value) => onWalletPrizeChanged(quiz, value),
          ),
          if (quiz.winners.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Winners',
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ...quiz.winners.take(3).map(
                  (winner) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: colors.gold.withValues(alpha: 0.16),
                          child: Text(
                            '${winner.rank}',
                            style: TextStyle(
                              color: colors.deep,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            winner.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            winner.walletPrizeStatus.isEmpty
                                ? 'No prize'
                                : winner.walletPrizeStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (quiz.walletPrizeEnabled &&
                            winner.walletPrizeStatus.toLowerCase() ==
                                'pending') ...[
                          const SizedBox(width: 6),
                          IconButton.filledTonal(
                            tooltip: 'Pay wallet prize',
                            onPressed: busy
                                ? null
                                : () => onPayWinnerPrize(quiz, winner),
                            icon: const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _QuizSwitchTile extends StatelessWidget {
  const _QuizSwitchTile({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final _ManagementPalette colors;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
      activeColor: colors.gold,
      title: Text(
        title,
        style: TextStyle(color: colors.text, fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colors.muted, height: 1.25),
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _QuizInfoChip extends StatelessWidget {
  const _QuizInfoChip({
    required this.colors,
    required this.icon,
    required this.label,
  });

  final _ManagementPalette colors;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.gold, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.muted,
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

class _Panel extends StatelessWidget {
  const _Panel({
    required this.colors,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
  });

  final _ManagementPalette colors;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.16 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(color: colors.muted, height: 1.35),
              ),
            ],
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.colors,
    required this.data,
  });

  final _ManagementPalette colors;
  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: colors.gold, size: 22),
          const SizedBox(height: 12),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.muted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.colors,
    required this.label,
    required this.value,
  });

  final _ManagementPalette colors;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutSummary extends StatelessWidget {
  const _DonutSummary({
    required this.colors,
    required this.rows,
  });

  final _ManagementPalette colors;
  final List<GoshenManagementBreakdownRow> rows;

  @override
  Widget build(BuildContext context) {
    final total = _totalCount(rows);
    return Row(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(
            painter: _DonutPainter(
              rows: rows,
              colors: colors,
            ),
            child: Center(
              child: Text(
                _number(total),
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows.take(4).map((row) {
              final color = _segmentColor(colors, rows.indexOf(row));
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _number(row.count),
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.rows,
    required this.colors,
  });

  final List<GoshenManagementBreakdownRow> rows;
  final _ManagementPalette colors;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.13;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final total = _totalCount(rows);
    final track = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (var index = 0; index < rows.length; index += 1) {
      final row = rows[index];
      if (row.count <= 0) continue;
      final sweep = (row.count / total) * math.pi * 2;
      final paint = Paint()
        ..color = _segmentColor(colors, index)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.rows != rows || oldDelegate.colors != colors;
  }
}

class _BreakdownProgressRow extends StatelessWidget {
  const _BreakdownProgressRow({
    required this.colors,
    required this.row,
    required this.total,
  });

  final _ManagementPalette colors;
  final GoshenManagementBreakdownRow row;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent =
        row.percentage ?? (total <= 0 ? 0 : (row.count / total) * 100);
    final progress = (percent / 100).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_number(row.count)}  ${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.teal),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBreakdown extends StatelessWidget {
  const _CompactBreakdown({
    required this.colors,
    required this.title,
    required this.rows,
  });

  final _ManagementPalette colors;
  final String title;
  final List<GoshenManagementBreakdownRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.innerCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            _EmptyInline(colors: colors, text: 'No data yet.')
          else ...[
            _DonutSummary(colors: colors, rows: rows),
            const SizedBox(height: 12),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _number(row.count),
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
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({
    required this.colors,
    required this.label,
  });

  final _ManagementPalette colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: colors.gold,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final _ManagementPalette colors;
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.gold, size: 34),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: colors.muted, height: 1.38),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(
                backgroundColor: colors.gold,
                foregroundColor: colors.deep,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ControlHubMobileUsersScreen extends StatefulWidget {
  const ControlHubMobileUsersScreen({super.key, required this.user});

  final Userdata user;

  @override
  State<ControlHubMobileUsersScreen> createState() =>
      _ControlHubMobileUsersScreenState();
}

class _ControlHubMobileUsersScreenState
    extends State<ControlHubMobileUsersScreen> {
  final _api = ControlHubUsersApi();
  final _searchController = TextEditingController();
  late Future<List<ControlHubMobileUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchUsers(widget.user);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final future = _api.fetchUsers(
      widget.user,
      query: _searchController.text,
    );
    setState(() => _future = future);
    await future;
  }

  Future<void> _openForm([ControlHubMobileUser? user]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MobileUserFormSheet(
        manager: widget.user,
        mobileUser: user,
        api: _api,
      ),
    );
    if (changed == true && mounted) {
      await _reload();
    }
  }

  Future<void> _delete(ControlHubMobileUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete mobile user?'),
        content: Text(
          'This will remove ${user.displayName} from the mobile user list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.deleteUser(user: widget.user, userId: user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mobile user deleted.')),
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mobileUsersError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Mobile Users'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Add user',
            onPressed: () => _openForm(),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add user'),
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _reload,
        child: FutureBuilder<List<ControlHubMobileUser>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _LoadingCard(
                      colors: colors, label: 'Loading mobile users...'),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _MobileUserSearchPanel(
                    colors: colors,
                    controller: _searchController,
                    onSearch: _reload,
                  ),
                  const SizedBox(height: 14),
                  _MessageCard(
                    colors: colors,
                    icon: snapshot.error is ControlHubUsersUnavailableException
                        ? Icons.construction_rounded
                        : Icons.cloud_off_rounded,
                    title: snapshot.error is ControlHubUsersUnavailableException
                        ? 'Mobile user backend pending'
                        : 'Unable to load mobile users',
                    message: _mobileUsersError(snapshot.error),
                    actionLabel: 'Retry',
                    onAction: _reload,
                  ),
                ],
              );
            }

            final users = snapshot.data ?? const <ControlHubMobileUser>[];
            return ListView(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                96 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _MobileUserSearchPanel(
                  colors: colors,
                  controller: _searchController,
                  onSearch: _reload,
                ),
                const SizedBox(height: 14),
                if (users.isEmpty)
                  _EmptyInline(colors: colors, text: 'No mobile users found.')
                else
                  ...users.map(
                    (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MobileUserTile(
                        user: user,
                        colors: colors,
                        onEdit: () => _openForm(user),
                        onDelete: () => _delete(user),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MobileUserSearchPanel extends StatelessWidget {
  const _MobileUserSearchPanel({
    required this.colors,
    required this.controller,
    required this.onSearch,
  });

  final _ManagementPalette colors;
  final TextEditingController controller;
  final Future<void> Function() onSearch;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      colors: colors,
      title: 'Search users',
      subtitle: 'Find users by name, email, phone, or Triumphant ID.',
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: _managementInputDecoration(colors, 'Search'),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
    );
  }
}

class _MobileUserTile extends StatelessWidget {
  const _MobileUserTile({
    required this.user,
    required this.colors,
    required this.onEdit,
    required this.onDelete,
  });

  final ControlHubMobileUser user;
  final _ManagementPalette colors;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (user.email.trim().isNotEmpty) user.email,
      if (user.phone.trim().isNotEmpty) user.phone,
      if (user.profileTitle.trim().isNotEmpty) user.profileTitle,
      if (user.maritalStatus.trim().isNotEmpty) user.maritalStatus,
    ].join(' | ');
    return _Panel(
      colors: colors,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.gold.withValues(alpha: 0.18),
            child: Icon(Icons.person_rounded, color: colors.deep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details.isEmpty ? user.statusLabel : details,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
          ),
        ],
      ),
    );
  }
}

class _MobileUserFormSheet extends StatefulWidget {
  const _MobileUserFormSheet({
    required this.manager,
    required this.api,
    this.mobileUser,
  });

  final Userdata manager;
  final ControlHubUsersApi api;
  final ControlHubMobileUser? mobileUser;

  @override
  State<_MobileUserFormSheet> createState() => _MobileUserFormSheetState();
}

class _MobileUserFormSheetState extends State<_MobileUserFormSheet> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _profileTitle = '';
  String _maritalStatus = '';
  String _gender = 'Male';
  String _memberType = 'church_member';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.mobileUser;
    if (user == null) return;
    _nameController.text = user.name;
    _emailController.text = user.email;
    _phoneController.text = user.phone;
    _profileTitle = user.profileTitle;
    _maritalStatus = user.maritalStatus;
    _gender = user.gender.trim().isEmpty ? 'Male' : user.gender;
    _memberType =
        user.memberType.trim().isEmpty ? 'church_member' : user.memberType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final isCreating = widget.mobileUser == null;
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _profileTitle.trim().isEmpty ||
        _maritalStatus.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name, email, title, and marital status are required.'),
        ),
      );
      return;
    }
    if (isCreating && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a temporary password for this new user.'),
        ),
      );
      return;
    }
    if (password.isNotEmpty && password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 8 characters.')),
      );
      return;
    }
    if (password.isNotEmpty && password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password confirmation does not match.')),
      );
      return;
    }

    setState(() => _saving = true);
    final payload = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'title': _profileTitle,
      'profile_title': _profileTitle,
      'salutation': _profileTitle,
      'marital_status': _maritalStatus,
      'gender': _gender,
      'member_type': _memberType,
      if (password.isNotEmpty) 'password': password,
    };

    try {
      final existing = widget.mobileUser;
      if (existing == null) {
        await widget.api.createUser(user: widget.manager, profile: payload);
      } else {
        await widget.api.updateUser(
          user: widget.manager,
          userId: existing.id,
          profile: payload,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mobileUsersError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ManagementPalette.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.mobileUser == null ? 'Add mobile user' : 'Edit user',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                decoration: _managementInputDecoration(colors, 'Full name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _managementInputDecoration(colors, 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _managementInputDecoration(colors, 'Phone'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: _managementInputDecoration(
                  colors,
                  widget.mobileUser == null
                      ? 'Temporary password'
                      : 'New password (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: _managementInputDecoration(
                  colors,
                  widget.mobileUser == null
                      ? 'Confirm temporary password'
                      : 'Confirm new password',
                ),
              ),
              const SizedBox(height: 10),
              _ManagedDropdown(
                colors: colors,
                label: 'Title',
                value: _profileTitle,
                items: const {'Mr.': 'Mr.', 'Mrs.': 'Mrs.', 'Miss': 'Miss'},
                onChanged: (value) => setState(() => _profileTitle = value),
              ),
              const SizedBox(height: 10),
              _ManagedDropdown(
                colors: colors,
                label: 'Marital status',
                value: _maritalStatus,
                items: const {
                  'Single': 'Single',
                  'Married': 'Married',
                  'Widowed': 'Widowed',
                  'Divorced/Separated': 'Divorced/Separated',
                  'Prefer not to say': 'Prefer not to say',
                },
                onChanged: (value) => setState(() => _maritalStatus = value),
              ),
              const SizedBox(height: 10),
              _ManagedDropdown(
                colors: colors,
                label: 'Gender',
                value: _gender,
                items: const {'Male': 'Male', 'Female': 'Female'},
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: 10),
              _ManagedDropdown(
                colors: colors,
                label: 'Member type',
                value: _memberType,
                items: const {
                  'church_member': 'Church member',
                  'visitor': 'Visitor',
                },
                onChanged: (value) => setState(() => _memberType = value),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Saving...' : 'Save user'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.gold,
                    foregroundColor: colors.deep,
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

String _mobileUsersError(Object? error) {
  if (error is ControlHubUsersUnavailableException) {
    return 'The mobile user management endpoint is not available yet. The Flutter control hub UI is ready and will activate when the backend route is enabled.';
  }
  return error.toString().replaceFirst('Exception: ', '');
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({
    required this.colors,
    required this.text,
  });

  final _ManagementPalette colors;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.innerCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        text,
        style: TextStyle(color: colors.muted, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ManagementPalette {
  const _ManagementPalette({
    required this.isDark,
    required this.background,
    required this.card,
    required this.innerCard,
    required this.text,
    required this.muted,
    required this.border,
    required this.deep,
    required this.gold,
    required this.teal,
    required this.success,
    required this.danger,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color innerCard;
  final Color text;
  final Color muted;
  final Color border;
  final Color deep;
  final Color gold;
  final Color teal;
  final Color success;
  final Color danger;

  static _ManagementPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ManagementPalette(
      isDark: isDark,
      background: isDark ? const Color(0xFF071720) : const Color(0xFFF3F8FA),
      card: isDark ? const Color(0xFF0C2733) : Colors.white,
      innerCard: isDark ? const Color(0xFF0B202B) : const Color(0xFFF3F7FA),
      text: isDark ? Colors.white : const Color(0xFF0C2230),
      muted: isDark ? Colors.white70 : const Color(0xFF5D6D77),
      border: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE2EAF0),
      deep: const Color(0xFF0C2230),
      gold: const Color(0xFFFFB522),
      teal: const Color(0xFF2C9B88),
      success: const Color(0xFF188B67),
      danger: const Color(0xFFD1495B),
    );
  }
}

int _totalCount(List<GoshenManagementBreakdownRow> rows) =>
    rows.fold<int>(0, (sum, row) => sum + row.count);

Color _segmentColor(_ManagementPalette colors, int index) {
  final palette = [
    colors.gold,
    colors.teal,
    const Color(0xFF5B7CFA),
    const Color(0xFFD1495B),
    const Color(0xFF7B61FF),
    const Color(0xFF188B67),
  ];
  return palette[index % palette.length];
}

String _number(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index += 1) {
    final remaining = raw.length - index;
    buffer.write(raw[index]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String _managementMoney(double value, String currency) {
  final amount = value.toStringAsFixed(2);
  return '${currency.toUpperCase()} $amount';
}

String _statusActionLabel(String status) {
  return switch (status) {
    'approved' => 'Approve',
    'rejected' => 'Reject',
    'paid' => 'Mark paid',
    _ => 'Update',
  };
}

InputDecoration _managementInputDecoration(
  _ManagementPalette colors,
  String label,
) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: colors.innerCard,
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
      borderSide: BorderSide(color: colors.gold, width: 1.5),
    ),
  );
}

const _setupFieldTypes = [
  'text',
  'textarea',
  'select',
  'image_select',
  'color_select',
];

String? _requiredValidator(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;

Widget _setupSheet({
  required BuildContext context,
  required _ManagementPalette colors,
  required String title,
  required Widget child,
}) {
  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _setupTextField({
  required _ManagementPalette colors,
  required TextEditingController controller,
  required String label,
  String? helperText,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
  int minLines = 1,
  int maxLines = 1,
  Widget? suffixIcon,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _managementInputDecoration(colors, label).copyWith(
        helperText: helperText,
        suffixIcon: suffixIcon,
      ),
    ),
  );
}

Widget _setupDropdown({
  required _ManagementPalette colors,
  required String label,
  required String value,
  required Map<String, String> values,
  required ValueChanged<String> onChanged,
}) {
  final effectiveValue = values.containsKey(value) ? value : values.keys.first;
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      value: effectiveValue,
      isExpanded: true,
      decoration: _managementInputDecoration(colors, label),
      items: values.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    ),
  );
}

Widget _setupSaveButton({
  required _ManagementPalette colors,
  required bool saving,
  required String label,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
      label: Text(saving ? 'Saving...' : label),
      style: FilledButton.styleFrom(
        backgroundColor: colors.gold,
        foregroundColor: colors.deep,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  );
}

String _dateInput(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-${day}T$hour:$minute';
}

String _decimalInput(double value) {
  if (value == 0) return '0';
  return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}

String? _nullableTextValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _optionsToLines(List<GoshenRegistrationFieldOption> options) {
  return options.map((option) {
    final values = [
      option.label,
      option.value,
      option.imagePath,
      option.colorHex,
      option.fee == 0 ? '' : _decimalInput(option.fee),
      option.feeLabel,
    ];
    while (values.isNotEmpty && values.last.trim().isEmpty) {
      values.removeLast();
    }
    return values.join('|');
  }).join('\n');
}

List<Map<String, dynamic>> _parseOptionsLines(String raw) {
  final lines = raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  return [
    for (var index = 0; index < lines.length; index += 1)
      _parseOptionLine(lines[index], index),
  ];
}

Map<String, dynamic> _parseOptionLine(String line, int index) {
  final parts = line.split('|').map((part) => part.trim()).toList();
  String part(int i) => i < parts.length ? parts[i] : '';
  final label = part(0);
  final explicitValue = part(1);
  return {
    'label': label,
    'value': explicitValue.isNotEmpty
        ? explicitValue
        : label.toLowerCase() == 'please select'
            ? ''
            : label
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                .replaceAll(RegExp(r'_+'), '_')
                .replaceAll(RegExp(r'^_|_$'), ''),
    'image_path': part(2),
    'color_hex': part(3),
    'fee_amount': double.tryParse(part(4)) ?? 0,
    'fee_label': part(5),
    'sort_order': index + 1,
  };
}

Color? _parseColor(String? value) {
  final raw = (value ?? '').trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(raw)) return null;
  return Color(int.parse('ff$raw', radix: 16));
}

String _durationLabel(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (minutes <= 0) return '${remainingSeconds}s';
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

String _dateTimeLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} $hour:$minute';
}

String _compactDateLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

Future<void> _launchExternalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Media link is not available.')),
    );
    return;
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open media link.')),
    );
  }
}
