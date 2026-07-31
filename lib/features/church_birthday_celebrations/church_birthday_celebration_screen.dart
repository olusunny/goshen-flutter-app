import 'package:flutter/material.dart';

import '../../models/Userdata.dart';
import 'church_birthday_celebration_api.dart';
import 'church_birthday_celebration_availability.dart';
import 'church_birthday_celebration_detail_screen.dart';
import 'church_birthday_celebration_models.dart';
import 'church_birthday_celebration_preferences_screen.dart';

class ChurchBirthdayCelebrationScreen extends StatefulWidget {
  const ChurchBirthdayCelebrationScreen({
    super.key,
    required this.user,
    this.celebrationId,
  });

  static const routeName = '/church-birthday-celebrations';
  final Userdata user;
  final String? celebrationId;

  @override
  State<ChurchBirthdayCelebrationScreen> createState() =>
      _ChurchBirthdayCelebrationScreenState();
}

class _ChurchBirthdayCelebrationScreenState
    extends State<ChurchBirthdayCelebrationScreen> {
  final _api = ChurchBirthdayCelebrationApi();
  final _availability = ChurchBirthdayCelebrationAvailability();
  late Future<_BirthdayScreenData?> _screen;
  bool _handledInitialCelebration = false;

  @override
  void initState() {
    super.initState();
    _screen = _load();
  }

  Future<_BirthdayScreenData?> _load() async {
    final capability = await _availability.check(widget.user);
    if (!capability.canOpenMemberExperience) return null;
    final context = await _api.context(widget.user);
    if (!context.capability.canOpenMemberExperience) return null;
    return _BirthdayScreenData(
      context: context,
      hub: await _api.hub(widget.user),
    );
  }

  Future<void> _refresh() async {
    setState(() => _screen = _load());
    await _screen;
  }

  Future<void> _openPreferences(ChurchBirthdayContext birthdayContext) async {
    final result =
        await Navigator.of(context).push<BirthdayCelebrationPreferences>(
      MaterialPageRoute(
        builder: (_) => ChurchBirthdayCelebrationPreferencesScreen(
          user: widget.user,
          initial: birthdayContext.preferences,
          templates: birthdayContext.templates,
          verses: birthdayContext.verses,
        ),
      ),
    );
    if (result != null && mounted) await _refresh();
  }

  void _openDetail(String id) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChurchBirthdayCelebrationDetailScreen(
        user: widget.user,
        celebrationId: id,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Birthday Celebrations'),
          actions: [
            FutureBuilder<_BirthdayScreenData?>(
              future: _screen,
              builder: (context, snapshot) => IconButton(
                tooltip: 'Birthday preferences',
                onPressed: snapshot.data == null
                    ? null
                    : () => _openPreferences(snapshot.data!.context),
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ],
        ),
        body: FutureBuilder<_BirthdayScreenData?>(
          future: _screen,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _state(
                icon: Icons.cloud_off_rounded,
                message: snapshot.error is BirthdayApiException
                    ? (snapshot.error as BirthdayApiException).message
                    : 'Birthday celebrations are unavailable. Pull down to try again.',
              );
            }
            final screen = snapshot.data;
            if (screen == null) {
              return _state(
                icon: Icons.lock_outline_rounded,
                message:
                    'Birthday celebrations are only available to verified church members.',
              );
            }
            if (widget.celebrationId != null && !_handledInitialCelebration) {
              _handledInitialCelebration = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _openDetail(widget.celebrationId!);
              });
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Celebrating our church family',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Birth years and ages stay private. You can manage your own birthday preferences at any time.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  _section(
                    'Today\'s Birthdays',
                    screen.hub.today,
                    empty: 'No birthdays are being celebrated today.',
                  ),
                  const SizedBox(height: 24),
                  _section(
                    'Upcoming Birthdays',
                    screen.hub.upcomingWithinDays(3),
                    empty: 'No birthdays are coming up in the next 3 days.',
                    openDetails: false,
                  ),
                ],
              ),
            );
          },
        ),
      );

  Widget _state({required IconData icon, required String message}) =>
      RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              Icon(icon, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ]),
          ),
        ]),
      );

  Widget _section(
    String title,
    List<BirthdayCelebrationMember> members, {
    required String empty,
    bool openDetails = true,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (members.isEmpty)
          Text(empty)
        else
          ...members.map((member) => Card(
                child: ListTile(
                  leading: const CircleAvatar(
                      child: Icon(Icons.celebration_outlined)),
                  title: Text(member.displayName),
                  subtitle: Text(member.dayMonth),
                  trailing: openDetails
                      ? const Icon(Icons.chevron_right_rounded)
                      : const Text('Coming soon'),
                  onTap: openDetails ? () => _openDetail(member.id) : null,
                ),
              )),
      ]);
}

class _BirthdayScreenData {
  const _BirthdayScreenData({required this.context, required this.hub});

  final ChurchBirthdayContext context;
  final BirthdayCelebrationHub hub;
}
