import 'package:flutter/material.dart';

import '../../models/Userdata.dart';
import '../../socials/UpdateUserProfile.dart';
import '../../utils/member_profile_presentation.dart';
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

  @override
  Widget build(BuildContext context) {
    final savedBirthday = formatBirthdayMonthDay(
      widget.user.birthdayMonthDay ?? widget.user.dateOfBirth,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Birthday preferences')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Your birthday stays private. These choices control the church-member celebration card only.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cake_outlined),
              title: const Text('Saved birthday'),
              subtitle: Text(
                savedBirthday.isEmpty ? 'Not set yet' : savedBirthday,
              ),
              trailing: TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  UpdateUserProfile.routeName,
                ),
                child: const Text('Update profile'),
              ),
            ),
          ),
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
            subtitle:
                const Text('You will still receive a private church greeting.'),
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
}
