import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/LoginScreen.dart';
import '../../models/Userdata.dart';
import '../../providers/AppStateManager.dart';
import 'church_birthday_card_file_service.dart';
import 'church_birthday_celebration_api.dart';
import 'church_birthday_celebration_models.dart';
import 'church_birthday_greeting_store.dart';

class ChurchBirthdayCelebrationDetailScreen extends StatefulWidget {
  const ChurchBirthdayCelebrationDetailScreen({
    super.key,
    required this.user,
    required this.celebrationId,
  });

  final Userdata user;
  final String celebrationId;

  @override
  State<ChurchBirthdayCelebrationDetailScreen> createState() =>
      _ChurchBirthdayCelebrationDetailScreenState();
}

class _ChurchBirthdayCelebrationDetailScreenState
    extends State<ChurchBirthdayCelebrationDetailScreen> {
  static const _reactions = ['celebrate', 'love', 'pray'];
  final _api = ChurchBirthdayCelebrationApi();
  final _cards = ChurchBirthdayCardFileService();
  final _greetingStore = ChurchBirthdayGreetingStore();
  final _greeting = TextEditingController();
  final _thanks = TextEditingController();
  late Future<BirthdayCelebrationDetail> _detail;
  Future<Uint8List>? _previewCard;
  Future<Uint8List>? _shareCardBytes;
  int? _myGreetingId;
  bool _serverGreetingResolved = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _detail = _load();
    _restoreMyGreeting();
  }

  @override
  void dispose() {
    _greeting.dispose();
    _thanks.dispose();
    super.dispose();
  }

  Future<BirthdayCelebrationDetail> _load() async {
    final detail = await _api.detail(widget.user, widget.celebrationId);
    _previewCard ??=
        _api.card(widget.user, widget.celebrationId, variant: 'square');
    await _applyServerGreeting(detail);
    return detail;
  }

  Future<void> _restoreMyGreeting() async {
    final greetingId =
        await _greetingStore.read(widget.user, widget.celebrationId);
    if (mounted && !_serverGreetingResolved) {
      setState(() => _myGreetingId = greetingId);
    }
  }

  Future<void> _applyServerGreeting(BirthdayCelebrationDetail detail) async {
    var greetingId = detail.myGreetingId;
    if (greetingId == null) {
      final mine = detail.greetings.where((greeting) => greeting.isMine);
      greetingId = mine.isEmpty ? null : mine.first.id;
    }
    _serverGreetingResolved = true;
    if (greetingId == null) {
      await _greetingStore.clear(widget.user, detail.id);
    } else {
      await _greetingStore.write(widget.user, detail.id, greetingId);
    }
    if (!mounted) return;
    setState(() {
      _myGreetingId = greetingId;
      if (_greeting.text.trim().isEmpty) {
        final mine = detail.greetings.where((greeting) => greeting.isMine);
        if (mine.isNotEmpty) _greeting.text = mine.first.body;
      }
    });
  }

  Future<void> _refresh() async {
    setState(() => _detail = _load());
    await _detail;
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _working = true);
    try {
      await action();
      if (!mounted) return;
      _message(success);
      await _refresh();
    } on BirthdayApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  Future<void> _saveCard(BirthdayCelebrationDetail detail) async {
    try {
      final file =
          await (_shareCardBytes ??= _api.card(widget.user, detail.id));
      final saved = await _cards.save(detail.id, file);
      if (mounted) _message('Birthday card saved to ${saved.path}.');
    } catch (_) {
      if (mounted) _message('The birthday card could not be saved.');
    }
  }

  Future<void> _shareCard(BirthdayCelebrationDetail detail) async {
    try {
      final file =
          await (_shareCardBytes ??= _api.card(widget.user, detail.id));
      await _cards.share(detail.id, file, detail.displayName);
    } catch (_) {
      if (mounted) _message('The birthday card could not be shared.');
    }
  }

  Future<void> _report(BirthdayGreeting greeting) async {
    final reason = TextEditingController();
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report greeting'),
        content: TextField(
          controller: reason,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
              labelText: 'Tell the church team what is wrong'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, reason.text.trim()),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    final report = submitted?.trim() ?? '';
    reason.dispose();
    if (report.isEmpty) return;
    await _run(
      () => _api.report(widget.user, widget.celebrationId, greeting.id, report),
      'Thank you. The greeting has been reported.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Birthday celebration')),
        body: FutureBuilder<BirthdayCelebrationDetail>(
          future: _detail,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              final birthdayError =
                  error is BirthdayApiException ? error : null;
              return _state(
                birthdayError?.requiresSignIn == true
                    ? Icons.login_rounded
                    : Icons.cloud_off_rounded,
                birthdayError?.message ??
                    'We could not open this birthday celebration. Pull down to try again.',
                requiresSignIn: birthdayError?.requiresSignIn == true,
              );
            }
            final detail = snapshot.requireData;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _cardPreview(detail),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _working ? null : () => _saveCard(detail),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Save card'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _working ? null : () => _shareCard(detail),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share card'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Celebrate ${detail.displayName}',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (detail.dayMonth.isNotEmpty) Text(detail.dayMonth),
                  const SizedBox(height: 8),
                  Text(
                    detail.isInteractive
                        ? 'Share a short greeting while this celebration is open.'
                        : 'This celebration has closed. Thank you for celebrating with the church family.',
                  ),
                  const SizedBox(height: 20),
                  _reactionsView(detail),
                  if (detail.thankYou != null) ...[
                    const SizedBox(height: 24),
                    _thankYouCard(detail),
                  ],
                  if (detail.isInteractive && detail.isCelebrant) ...[
                    const SizedBox(height: 24),
                    _thankYouEditor(detail),
                  ],
                  if (detail.isInteractive && !detail.isCelebrant) ...[
                    const SizedBox(height: 24),
                    _greetingEditor(detail),
                  ],
                  const SizedBox(height: 24),
                  Text('Member greetings',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (detail.greetings.isEmpty)
                    const Text('No greetings have been shared yet.')
                  else
                    ...detail.greetings.map(_greetingTile),
                ],
              ),
            );
          },
        ),
      );

  Widget _cardPreview(BirthdayCelebrationDetail detail) => AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: FutureBuilder<Uint8List>(
            future: _previewCard,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    semanticLabel: 'Birthday card for ${detail.displayName}',
                  ),
                );
              }
              if (snapshot.hasError) {
                return const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 44));
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      );

  Widget _reactionsView(BirthdayCelebrationDetail detail) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Celebrate together',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reactions
                .map((reaction) => ActionChip(
                      avatar: Icon(_reactionIcon(reaction), size: 18),
                      label: Text(
                          '${_reactionLabel(reaction)} ${detail.reactions[reaction] ?? 0}'),
                      onPressed: !detail.isInteractive || _working
                          ? null
                          : () => _run(
                                () => _api.react(
                                    widget.user, detail.id, reaction),
                                'Your reaction has been shared.',
                              ),
                    ))
                .toList(),
          ),
        ],
      );

  Widget _thankYouCard(BirthdayCelebrationDetail detail) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('A thank-you from ${detail.displayName}',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(detail.thankYou!),
          ]),
        ),
      );

  Widget _thankYouEditor(BirthdayCelebrationDetail detail) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thank your church family',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _thanks,
            maxLength: 280,
            minLines: 2,
            maxLines: 4,
            enabled: !_working,
            onChanged: (_) => setState(() {}),
            decoration:
                const InputDecoration(labelText: 'Your one general thank-you'),
          ),
          FilledButton(
            onPressed: _working || _thanks.text.trim().isEmpty
                ? null
                : () => _run(
                      () => _api.thank(widget.user, detail.id, _thanks.text),
                      'Your thank-you has been shared.',
                    ),
            child: const Text('Share thank-you'),
          ),
        ],
      );

  Widget _greetingEditor(BirthdayCelebrationDetail detail) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Leave a greeting',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _greeting,
            maxLength: 280,
            minLines: 2,
            maxLines: 4,
            enabled: !_working,
            onChanged: (_) => setState(() {}),
            decoration:
                const InputDecoration(labelText: 'A warm birthday message'),
          ),
          Wrap(spacing: 8, children: [
            FilledButton(
              onPressed: _working || _greeting.text.trim().isEmpty
                  ? null
                  : () => _run(() async {
                        final greeting = await _api.greet(
                            widget.user, detail.id, _greeting.text);
                        await _greetingStore.write(
                            widget.user, detail.id, greeting.id);
                        if (mounted)
                          setState(() => _myGreetingId = greeting.id);
                        _greeting.clear();
                      }, 'Your greeting has been shared.'),
              child: Text(
                  _myGreetingId == null ? 'Share greeting' : 'Update greeting'),
            ),
            if (_myGreetingId != null)
              TextButton(
                onPressed: _working
                    ? null
                    : () => _run(() async {
                          await _api.deleteGreeting(
                              widget.user, detail.id, _myGreetingId!);
                          await _greetingStore.clear(widget.user, detail.id);
                          if (mounted) setState(() => _myGreetingId = null);
                        }, 'Your greeting has been removed.'),
                child: const Text('Remove my greeting'),
              ),
          ]),
        ],
      );

  Widget _greetingTile(BirthdayGreeting greeting) => Card(
        child: ListTile(
          title: Text(greeting.body),
          subtitle: greeting.createdAt == null
              ? null
              : Text(
                  'Shared ${MaterialLocalizations.of(context).formatShortDate(greeting.createdAt!.toLocal())}'),
          trailing: IconButton(
            tooltip: 'Report greeting',
            onPressed: _working ? null : () => _report(greeting),
            icon: const Icon(Icons.flag_outlined),
          ),
        ),
      );

  Future<void> _signInAgain() async {
    await context.read<AppStateManager>().unsetUserData();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
  }

  Widget _state(IconData icon, String message, {bool requiresSignIn = false}) =>
      RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              Icon(icon, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              if (requiresSignIn)
                FilledButton(
                  onPressed: _signInAgain,
                  child: const Text('Sign in again'),
                )
              else
                OutlinedButton(
                  onPressed: _refresh,
                  child: const Text('Try again'),
                ),
            ]),
          ),
        ]),
      );

  IconData _reactionIcon(String reaction) => switch (reaction) {
        'love' => Icons.favorite_outline_rounded,
        'pray' => Icons.volunteer_activism_outlined,
        _ => Icons.celebration_outlined,
      };

  String _reactionLabel(String reaction) => switch (reaction) {
        'love' => 'Love',
        'pray' => 'Pray',
        _ => 'Celebrate',
      };
}
