import 'package:flutter/material.dart';

import '../../models/Userdata.dart';
import 'prayer_session_attendance_api.dart';
import 'prayer_session_attendance_models.dart';
import 'prayer_session_attendance_qr_scanner.dart';

class PrayerSessionAttendanceScreen extends StatefulWidget {
  const PrayerSessionAttendanceScreen({super.key, required this.user});

  static const routeName = '/prayer-session-attendance';
  final Userdata user;

  @override
  State<PrayerSessionAttendanceScreen> createState() =>
      _PrayerSessionAttendanceScreenState();
}

class _PrayerSessionAttendanceScreenState
    extends State<PrayerSessionAttendanceScreen> {
  final _api = PrayerSessionAttendanceApi();
  late Future<List<PrayerSessionSummary>> _sessions;
  PrayerSessionSummary? _selectedSession;
  PrayerSessionTicket? _selectedTicket;
  bool _working = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _sessions = _loadSessions();
  }

  Future<List<PrayerSessionSummary>> _loadSessions() async {
    final sessions = await _api.activeSessions(widget.user);
    final eligible =
        sessions.where((session) => session.isEligibleForAttendee).toList();
    if (!mounted) return eligible;
    setState(() {
      _selectedSession = eligible.length == 1 ? eligible.single : null;
      _selectedTicket = _selectedSession?.eligibleTickets.length == 1
          ? _selectedSession!.eligibleTickets.single
          : null;
    });
    return eligible;
  }

  Future<void> _refresh() async {
    setState(() {
      _message = null;
      _sessions = _loadSessions();
    });
    await _sessions;
  }

  Future<void> _scan() async {
    final session = _selectedSession;
    if (session == null) {
      setState(() => _message = 'Choose the prayer session you are attending.');
      return;
    }
    if (session.eligibleTickets.length > 1 && _selectedTicket == null) {
      setState(() => _message = 'Choose the ticket you are confirming.');
      return;
    }
    final token = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const PrayerSessionAttendanceQrScanner(
        title: 'Scan prayer session QR',
      ),
    ));
    if (token == null || !mounted) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final result = await _api.confirmSelf(
        widget.user,
        token,
        _selectedTicket?.id,
        '${DateTime.now().microsecondsSinceEpoch}',
        sessionName: session.name,
      );
      if (!mounted) return;
      setState(() => _message = result.alreadyConfirmed
          ? 'Attendance is already confirmed for ${result.sessionName}.'
          : 'Attendance confirmed. Thank you for joining ${result.sessionName}.');
    } catch (error) {
      if (mounted) {
        setState(
            () => _message = error.toString().replaceFirst('Exception: ', ''));
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
                return ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Prayer attendance is unavailable. Pull down to try again.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ]);
              }
              final sessions = snapshot.data ?? const [];
              if (sessions.isEmpty) {
                return ListView(children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'There is no active prayer session available for your ticket right now.',
                    ),
                  ),
                ]);
              }
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.volunteer_activism_rounded, size: 58),
                  const SizedBox(height: 18),
                  const Text(
                    'When you arrive at the prayer venue, select your session and scan its QR code to confirm your attendance.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<PrayerSessionSummary>(
                    value: _selectedSession,
                    decoration:
                        const InputDecoration(labelText: 'Prayer session'),
                    items: sessions
                        .map((session) => DropdownMenuItem(
                              value: session,
                              child: Text(session.name),
                            ))
                        .toList(),
                    onChanged: _working
                        ? null
                        : (session) => setState(() {
                              _selectedSession = session;
                              _selectedTicket =
                                  session?.eligibleTickets.length == 1
                                      ? session!.eligibleTickets.single
                                      : null;
                            }),
                  ),
                  if ((_selectedSession?.eligibleTickets.length ?? 0) > 1) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<PrayerSessionTicket>(
                      value: _selectedTicket,
                      decoration: const InputDecoration(labelText: 'Ticket'),
                      items: _selectedSession!.eligibleTickets
                          .map((ticket) => DropdownMenuItem(
                                value: ticket,
                                child: Text(
                                  '${ticket.ticketNumber} ${ticket.attendeeName}'
                                      .trim(),
                                ),
                              ))
                          .toList(),
                      onChanged: _working
                          ? null
                          : (ticket) =>
                              setState(() => _selectedTicket = ticket),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _working ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(_working ? 'Confirming...' : 'Scan session QR'),
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(_message!, textAlign: TextAlign.center),
                    ),
                ],
              );
            },
          ),
        ),
      );
}
