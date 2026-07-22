import 'package:flutter/material.dart';

import '../../models/Userdata.dart';
import 'prayer_session_attendance_api.dart';
import 'prayer_session_attendance_models.dart';
import 'prayer_session_attendance_offline_store.dart';
import 'prayer_session_attendance_qr_scanner.dart';
import 'prayer_session_qr_file_service.dart';

class PrayerSessionAttendanceControlHubScreen extends StatefulWidget {
  const PrayerSessionAttendanceControlHubScreen({
    super.key,
    required this.user,
    required this.capability,
  });

  final Userdata user;
  final PrayerAttendanceCapability capability;

  @override
  State<PrayerSessionAttendanceControlHubScreen> createState() =>
      _PrayerSessionAttendanceControlHubScreenState();
}

class _PrayerSessionAttendanceControlHubScreenState
    extends State<PrayerSessionAttendanceControlHubScreen> {
  final _api = PrayerSessionAttendanceApi();
  final _store = PrayerAttendanceOfflineStore();
  late Future<List<PrayerSessionSummary>> _sessions;
  bool _working = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _sessions = _api.controlSessions(widget.user);
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final queue = await _store.load(widget.user);
    if (mounted) setState(() => _pendingCount = queue.length);
  }

  Future<void> _refresh() async {
    setState(() => _sessions = _api.controlSessions(widget.user));
    await Future.wait([_sessions, _loadPendingCount()]);
  }

  Future<void> _scan(PrayerSessionSummary session) async {
    if (!widget.capability.canUseStaffAttendanceTools) return;
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const PrayerSessionAttendanceQrScanner(
        title: 'Scan attendee ticket',
      ),
    ));
    if (code == null || !mounted) return;
    await _lookupAndConfirm(session, code);
  }

  Future<void> _manualLookup(PrayerSessionSummary session) async {
    if (!widget.capability.canUseStaffAttendanceTools) return;
    final controller = TextEditingController();
    final identifier = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Find attendee'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Ticket number or attendee code',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Find'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (identifier == null || identifier.isEmpty || !mounted) return;
    await _lookupAndConfirm(session, identifier);
  }

  Future<void> _lookupAndConfirm(
    PrayerSessionSummary session,
    String identifier,
  ) async {
    if (!widget.capability.canUseStaffAttendanceTools) return;
    setState(() => _working = true);
    try {
      final ticket = await _api.staffLookup(widget.user, session, identifier);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm attendance?'),
          content: Text(
            '${ticket.attendeeName.isEmpty ? 'This attendee' : ticket.attendeeName}\n${ticket.ticketNumber}'
                .trim(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm attendance'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final result = await _api.staffConfirm(
        widget.user,
        session,
        ticket.id.isEmpty ? identifier : ticket.id,
        '${DateTime.now().microsecondsSinceEpoch}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.alreadyConfirmed
              ? 'This attendee is already confirmed.'
              : 'Attendance confirmed.'),
        ));
      }
    } catch (error) {
      if (PrayerSessionAttendanceApi.isRetryableConnectionFailure(error)) {
        final queue = await _store.load(widget.user);
        queue.add(_store.record(session.id, identifier));
        await _store.save(widget.user, queue);
        await _loadPendingCount();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
              'No connection. This scan is saved on this device and can be retried from the active session.',
            ),
          ));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _showReport(PrayerSessionSummary session) async {
    setState(() => _working = true);
    try {
      final report = await _api.report(widget.user, session);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            builder: (context, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Text(session.name,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                    'Confirmed: ${report.metrics['confirmed'] ?? report.confirmed.length}'),
                Text('Not confirmed: ${report.metrics['not_confirmed'] ?? 0}'),
                const Divider(height: 28),
                if (report.rows.isEmpty)
                  const Text('There are no eligible attendance records yet.')
                else
                  ...report.rows.map((row) => ListTile(
                        leading: Icon(row['status'] == 'Confirmed'
                            ? Icons.check_circle_outline_rounded
                            : Icons.radio_button_unchecked_rounded),
                        title: Text('${row['ticket_id'] ?? 'Ticket'}'),
                        subtitle: Text([
                          '${row['status'] ?? 'Not Confirmed'}',
                          if ('${row['attendee'] ?? ''}'.isNotEmpty)
                            '${row['attendee']}',
                          if ('${row['confirmed_at'] ?? ''}'.isNotEmpty)
                            '${row['confirmed_at']}',
                        ].join(' - ')),
                      )),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _confirmAction(String title, String message) async =>
      (await showDialog<bool>(
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
              child: Text(title),
            ),
          ],
        ),
      )) ==
      true;

  Future<void> _retryPending(PrayerSessionSummary session) async {
    if (!widget.capability.canUseStaffAttendanceTools) return;
    final queue = await _store.load(widget.user);
    final matching =
        queue.where((item) => item.sessionId == session.id).toList();
    if (matching.isEmpty) return;
    setState(() => _working = true);
    final retained =
        queue.where((item) => item.sessionId != session.id).toList();
    try {
      retained.addAll(await _api.sync(widget.user, matching));
      await _store.save(widget.user, retained);
      await _loadPendingCount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Saved attendance records were retried.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _action(
    PrayerSessionSummary session,
    Future<void> Function() action,
  ) async {
    setState(() => _working = true);
    try {
      await action();
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Prayer Session Attendance')),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<PrayerSessionSummary>>(
            future: _sessions,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'Prayer attendance is unavailable. Pull down to try again.'),
                  ),
                ]);
              }
              final sessions = snapshot.data ?? const [];
              if (sessions.isEmpty) {
                return ListView(children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No prayer sessions are available yet.'),
                  ),
                ]);
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: sessions
                    .map((session) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(session.status),
                                if (session.metrics.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Confirmed: ${session.metrics['confirmed'] ?? 0}   Not confirmed: ${session.metrics['not_confirmed'] ?? 0}',
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (widget.capability
                                            .canUseStaffAttendanceTools &&
                                        session.status == 'active')
                                      FilledButton.icon(
                                        onPressed: _working
                                            ? null
                                            : () => _scan(session),
                                        icon: const Icon(
                                            Icons.qr_code_scanner_rounded),
                                        label: const Text('Scan ticket'),
                                      ),
                                    if (widget.capability
                                            .canUseStaffAttendanceTools &&
                                        session.status == 'active')
                                      OutlinedButton.icon(
                                        onPressed: _working
                                            ? null
                                            : () => _manualLookup(session),
                                        icon: const Icon(
                                            Icons.person_search_rounded),
                                        label: const Text('Find attendee'),
                                      ),
                                    if (widget.capability
                                            .canUseStaffAttendanceTools &&
                                        session.status == 'active' &&
                                        _pendingCount > 0)
                                      OutlinedButton.icon(
                                        onPressed: _working
                                            ? null
                                            : () => _retryPending(session),
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: Text(
                                            'Retry saved scans ($_pendingCount)'),
                                      ),
                                    if (widget.capability.canCoordinate &&
                                        session.status == 'scheduled')
                                      OutlinedButton(
                                        onPressed: _working
                                            ? null
                                            : () async {
                                                if (await _confirmAction(
                                                  'Activate',
                                                  'This opens ${session.name} and sends its activation notice.',
                                                )) {
                                                  await _action(
                                                      session,
                                                      () => _api.activate(
                                                          widget.user,
                                                          session));
                                                }
                                              },
                                        child: const Text('Activate'),
                                      ),
                                    if (widget.capability.canCoordinate &&
                                        session.status == 'active')
                                      OutlinedButton(
                                        onPressed: _working
                                            ? null
                                            : () async {
                                                if (await _confirmAction(
                                                  'Close session',
                                                  'This stops new attendance confirmations for ${session.name}.',
                                                )) {
                                                  await _action(
                                                      session,
                                                      () => _api.close(
                                                          widget.user,
                                                          session));
                                                }
                                              },
                                        child: const Text('Close'),
                                      ),
                                    if (widget.capability.canCoordinate &&
                                        session.status == 'active')
                                      OutlinedButton(
                                        onPressed: _working
                                            ? null
                                            : () async {
                                                if (await _confirmAction(
                                                  'Send reminder',
                                                  'Eligible attendees who have not confirmed will receive one reminder.',
                                                )) {
                                                  await _action(
                                                      session,
                                                      () => _api.remind(
                                                          widget.user,
                                                          session));
                                                }
                                              },
                                        child:
                                            const Text('Remind not confirmed'),
                                      ),
                                    if (widget.capability.canCoordinate &&
                                        session.status == 'active')
                                      IconButton(
                                        tooltip: 'Share session QR',
                                        onPressed: _working
                                            ? null
                                            : () => _action(
                                                  session,
                                                  () =>
                                                      PrayerSessionQrFileService()
                                                          .share(widget.user,
                                                              session.id),
                                                ),
                                        icon: const Icon(Icons.share_rounded),
                                      ),
                                    if (widget.capability.canCoordinate &&
                                        session.status == 'active')
                                      IconButton(
                                        tooltip: 'Save session QR',
                                        onPressed: _working
                                            ? null
                                            : () => _action(
                                                  session,
                                                  () async {
                                                    final file =
                                                        await PrayerSessionQrFileService()
                                                            .save(widget.user,
                                                                session.id);
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                            content: Text(
                                                                'QR saved to ${file.path}')),
                                                      );
                                                    }
                                                  },
                                                ),
                                        icon:
                                            const Icon(Icons.download_rounded),
                                      ),
                                    if (widget.capability.canReport)
                                      OutlinedButton.icon(
                                        onPressed: _working
                                            ? null
                                            : () => _showReport(session),
                                        icon: const Icon(
                                            Icons.assessment_outlined),
                                        label: const Text('Report'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ),
      );
}
