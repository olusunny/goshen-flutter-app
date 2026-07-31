import 'package:flutter/material.dart';

import '../../models/Userdata.dart';
import 'church_birthday_celebration_api.dart';
import 'church_birthday_celebration_models.dart';

class ChurchBirthdayCelebrationPreferencesScreen extends StatefulWidget {
  const ChurchBirthdayCelebrationPreferencesScreen({
    super.key,
    required this.user,
    required this.initial,
    required this.templates,
    required this.verses,
  });

  final Userdata user;
  final BirthdayCelebrationPreferences initial;
  final List<BirthdayPresentationChoice> templates;
  final List<BirthdayPresentationChoice> verses;

  @override
  State<ChurchBirthdayCelebrationPreferencesScreen> createState() =>
      _ChurchBirthdayCelebrationPreferencesScreenState();
}

class _ChurchBirthdayCelebrationPreferencesScreenState
    extends State<ChurchBirthdayCelebrationPreferencesScreen> {
  final _api = ChurchBirthdayCelebrationApi();
  late BirthdayCelebrationPreferences _preferences;
  late final TextEditingController _name;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _preferences = widget.initial;
    if (widget.templates.isNotEmpty &&
        !widget.templates
            .any((choice) => choice.id == _preferences.templateId)) {
      _preferences = _preferences.copyWith(clearTemplate: true);
    }
    if (widget.verses.isNotEmpty &&
        !widget.verses.any((choice) => choice.id == _preferences.verseId)) {
      _preferences = _preferences.copyWith(clearVerse: true);
    }
    _name = TextEditingController(text: widget.initial.preferredName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final result = await _api.updatePreferences(
        widget.user,
        _preferences.copyWith(preferredName: _name.text.trim()),
      );
      if (!mounted) return;
      Navigator.pop(context, result.preferences);
    } on BirthdayApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _requestCorrection() async {
    var month = 1;
    var day = 1;
    final reason = TextEditingController();
    final values = await showDialog<(int, int, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Correct my birthday'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'Share the correct month and day. Birth year and age are never requested.'),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: month,
              decoration: const InputDecoration(labelText: 'Birth month'),
              items: List.generate(
                  12,
                  (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      )),
              onChanged: (value) =>
                  setDialogState(() => month = value ?? month),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: day,
              decoration: const InputDecoration(labelText: 'Birth day'),
              items: List.generate(
                  31,
                  (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      )),
              onChanged: (value) => setDialogState(() => day = value ?? day),
            ),
            TextField(
              controller: reason,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (month, day, reason.text)),
              child: const Text('Send correction'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    if (values == null) return;
    setState(() => _saving = true);
    try {
      await _api.requestCorrection(widget.user,
          month: values.$1, day: values.$2, reason: values.$3);
      if (mounted) _message('Your birthday correction request has been sent.');
    } on BirthdayApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Birthday preferences')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Your birthday stays private. These choices control the church-member celebration card only.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: _preferences.visibilityEnabled,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                        _preferences =
                            _preferences.copyWith(visibilityEnabled: value);
                      }),
              title: const Text('Show my birthday celebration'),
              subtitle: const Text(
                  'Turn this off to opt out of member birthday lists.'),
            ),
            SwitchListTile.adaptive(
              value: _preferences.greetingsEnabled,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                        _preferences =
                            _preferences.copyWith(greetingsEnabled: value);
                      }),
              title: const Text('Allow member greetings'),
              subtitle: const Text(
                  'You will still receive a private church greeting.'),
            ),
            SwitchListTile.adaptive(
              value: _preferences.useProfilePhoto,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                        _preferences =
                            _preferences.copyWith(useProfilePhoto: value);
                      }),
              title: const Text('Use my profile photo'),
              subtitle:
                  const Text('A branded fallback is used when this is off.'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              enabled: !_saving,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Preferred display name',
                hintText: 'Leave blank to use your profile name',
              ),
            ),
            if (widget.templates.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _preferences.templateId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Birthday card design'),
                items: widget.templates
                    .map((choice) => DropdownMenuItem(
                          value: choice.id,
                          child: Text(choice.label),
                        ))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                          _preferences = value == null
                              ? _preferences.copyWith(clearTemplate: true)
                              : _preferences.copyWith(templateId: value);
                        }),
              ),
            ],
            if (widget.verses.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _preferences.verseId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Birthday Bible verse'),
                items: widget.verses
                    .map((choice) => DropdownMenuItem(
                          value: choice.id,
                          child: Text(choice.label),
                        ))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                          _preferences = value == null
                              ? _preferences.copyWith(clearVerse: true)
                              : _preferences.copyWith(verseId: value);
                        }),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _saving ? null : _requestCorrection,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Correct my birthday'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save preferences'),
            ),
          ],
        ),
      );
}
