import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/ChurchEventManagement.dart';
import '../models/Userdata.dart';
import '../service/ControlHubChurchEventsApi.dart';

class ChurchEventManagementScreen extends StatefulWidget {
  const ChurchEventManagementScreen({
    super.key,
    required this.user,
  });

  final Userdata user;

  @override
  State<ChurchEventManagementScreen> createState() =>
      _ChurchEventManagementScreenState();
}

class _ChurchEventManagementScreenState
    extends State<ChurchEventManagementScreen> {
  final _api = ControlHubChurchEventsApi();
  final _searchController = TextEditingController();
  late Future<List<ChurchEventManagement>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ChurchEventManagement>> _load() {
    return _api.fetchEvents(widget.user, query: _searchController.text);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openEditor([ChurchEventManagement? event]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChurchEventEditorScreen(
          user: widget.user,
          initialEvent: event,
        ),
      ),
    );
    if (changed == true && mounted) await _refresh();
  }

  Future<void> _toggleStatus(
    ChurchEventManagement event,
    bool isPublished,
  ) async {
    try {
      await _api.updateStatus(
        user: widget.user,
        event: event,
        isPublished: isPublished,
      );
      if (mounted) await _refresh();
    } catch (error) {
      _showMessage(error);
    }
  }

  Future<void> _deleteEvent(ChurchEventManagement event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this event?'),
        content: const Text(
          'This removes the church event and its uploaded event images. This cannot be undone.',
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
      await _api.deleteEvent(user: widget.user, event: event);
      if (mounted) await _refresh();
    } catch (error) {
      _showMessage(error);
    }
  }

  void _showMessage(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ChurchEventPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Church Events'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Add event',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: colors.gold,
        foregroundColor: colors.deep,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add event'),
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<List<ChurchEventManagement>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ChurchEventMessage(
                colors: colors,
                title: 'Unable to load church events',
                message:
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                onRetry: _refresh,
              );
            }

            final events = snapshot.data ?? const <ChurchEventManagement>[];
            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                96 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _SearchPanel(
                  colors: colors,
                  controller: _searchController,
                  onSearch: _refresh,
                ),
                const SizedBox(height: 16),
                if (events.isEmpty)
                  _ChurchEventMessage(
                    colors: colors,
                    title: 'No church events yet',
                    message:
                        'Create the first church programme, upload its feature image, then publish it when ready.',
                    actionLabel: 'Add event',
                    onRetry: () => _openEditor(),
                  )
                else
                  ...events.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ChurchEventCard(
                        colors: colors,
                        event: event,
                        onEdit: () => _openEditor(event),
                        onDelete: () => _deleteEvent(event),
                        onStatusChanged: (value) => _toggleStatus(event, value),
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

class ChurchEventEditorScreen extends StatefulWidget {
  const ChurchEventEditorScreen({
    super.key,
    required this.user,
    this.initialEvent,
  });

  final Userdata user;
  final ChurchEventManagement? initialEvent;

  @override
  State<ChurchEventEditorScreen> createState() =>
      _ChurchEventEditorScreenState();
}

class _ChurchEventEditorScreenState extends State<ChurchEventEditorScreen> {
  final _api = ControlHubChurchEventsApi();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();
  final _venueController = TextEditingController();
  final _themeController = TextEditingController();
  final _bibleVerseController = TextEditingController();
  final _hostController = TextEditingController();
  final _otherMinistersController = TextEditingController();
  final _registrationUrlController = TextEditingController();

  bool _saving = false;
  bool _isPublished = false;
  bool _isPilgrimage = false;
  bool _removeThumbnail = false;
  bool _removePortraitImage = false;
  String _registrationAvailability = 'everywhere';
  String _recurrenceType = 'none';
  int _recurrenceInterval = 1;
  int _recurrenceWeekday = 0;
  int _recurrenceWeekOfMonth = 1;
  DateTime? _startsAt;
  DateTime? _endsAt;
  DateTime? _recurrenceUntil;
  PlatformFile? _thumbnail;
  PlatformFile? _portraitImage;

  bool get _isEditing => widget.initialEvent != null;

  @override
  void initState() {
    super.initState();
    final event = widget.initialEvent;
    if (event != null) {
      _titleController.text = event.title;
      _detailsController.text = event.details;
      _venueController.text = event.venue;
      _themeController.text = event.theme;
      _bibleVerseController.text = event.bibleVerse;
      _hostController.text = event.host;
      _otherMinistersController.text = event.otherMinisters;
      _registrationUrlController.text = event.registrationUrl;
      _registrationAvailability = event.registrationAvailability.isEmpty
          ? 'everywhere'
          : event.registrationAvailability;
      _recurrenceType =
          event.recurrenceType.isEmpty ? 'none' : event.recurrenceType;
      _recurrenceInterval =
          event.recurrenceInterval < 1 ? 1 : event.recurrenceInterval;
      _recurrenceWeekday = event.recurrenceWeekday ?? 0;
      _recurrenceWeekOfMonth = event.recurrenceWeekOfMonth ?? 1;
      _startsAt = event.startDateTime;
      _endsAt = event.endDateTime;
      _recurrenceUntil = event.recurrenceUntilDate;
      _isPublished = event.isPublished;
      _isPilgrimage = event.isPilgrimage;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _venueController.dispose();
    _themeController.dispose();
    _bibleVerseController.dispose();
    _hostController.dispose();
    _otherMinistersController.dispose();
    _registrationUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String target) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final file =
        result == null || result.files.isEmpty ? null : result.files.first;
    if (file == null) return;

    setState(() {
      if (target == 'thumbnail') {
        _thumbnail = file;
        _removeThumbnail = false;
      } else {
        _portraitImage = file;
        _removePortraitImage = false;
      }
    });
  }

  Future<void> _pickDateTime({
    required DateTime? initial,
    required void Function(DateTime?) onChanged,
    bool dateOnly = false,
  }) async {
    final now = DateTime.now();
    final seed = initial ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null) return;

    if (dateOnly) {
      onChanged(DateTime(date.year, date.month, date.day));
      return;
    }

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
    );
    if (time == null) return;

    onChanged(
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_recurrenceType != 'none' && _startsAt == null) {
      _showMessage('Recurring events need a start date and time.');
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'title': _titleController.text.trim(),
        'details': _detailsController.text.trim(),
        'venue': _venueController.text.trim(),
        'theme': _themeController.text.trim(),
        'bible_verse': _bibleVerseController.text.trim(),
        'host': _hostController.text.trim(),
        'other_ministers': _otherMinistersController.text.trim(),
        'registration_url': _registrationUrlController.text.trim(),
        'registration_availability': _registrationAvailability,
        'starts_at': _startsAt?.toIso8601String(),
        'ends_at': _endsAt?.toIso8601String(),
        'is_published': _isPublished,
        'is_pilgrimage': _isPilgrimage,
        'recurrence_type': _recurrenceType,
        'recurrence_interval': _recurrenceInterval,
        'recurrence_weekday':
            _recurrenceType == 'none' ? null : _recurrenceWeekday,
        'recurrence_week_of_month': _recurrenceType == 'monthly_nth_weekday'
            ? _recurrenceWeekOfMonth
            : null,
        'recurrence_until':
            _recurrenceUntil == null ? null : _dateOnly(_recurrenceUntil!),
        'remove_thumbnail': _removeThumbnail,
        'remove_portrait_image': _removePortraitImage,
      }..removeWhere((_, value) => value == null);

      if (_isEditing) {
        await _api.updateEvent(
          user: widget.user,
          event: widget.initialEvent!,
          payload: payload,
          thumbnail: _thumbnail,
          portraitImage: _portraitImage,
        );
      } else {
        await _api.createEvent(
          user: widget.user,
          payload: payload,
          thumbnail: _thumbnail,
          portraitImage: _portraitImage,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _showMessage(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ChurchEventPalette.of(context);
    final event = widget.initialEvent;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Event' : 'Add Event'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            32 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            _EditorSection(
              colors: colors,
              title: 'Event details',
              children: [
                _TextInput(
                  controller: _titleController,
                  label: 'Title',
                  icon: Icons.event_available_outlined,
                  required: true,
                ),
                _TextInput(
                  controller: _themeController,
                  label: 'Theme',
                  icon: Icons.auto_awesome_outlined,
                ),
                _TextInput(
                  controller: _venueController,
                  label: 'Venue',
                  icon: Icons.place_outlined,
                ),
                _TextInput(
                  controller: _detailsController,
                  label: 'Details',
                  icon: Icons.notes_outlined,
                  maxLines: 5,
                ),
                _TextInput(
                  controller: _bibleVerseController,
                  label: 'Bible verse',
                  icon: Icons.menu_book_outlined,
                ),
                _TextInput(
                  controller: _hostController,
                  label: 'Host',
                  icon: Icons.person_outline,
                ),
                _TextInput(
                  controller: _otherMinistersController,
                  label: 'Other ministers',
                  icon: Icons.groups_outlined,
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _EditorSection(
              colors: colors,
              title: 'Date and recurrence',
              children: [
                _DateTile(
                  colors: colors,
                  label: 'Starts at',
                  value: _startsAt,
                  onTap: () => _pickDateTime(
                    initial: _startsAt,
                    onChanged: (value) => setState(() => _startsAt = value),
                  ),
                  onClear: _startsAt == null
                      ? null
                      : () => setState(() => _startsAt = null),
                ),
                _DateTile(
                  colors: colors,
                  label: 'Ends at',
                  value: _endsAt,
                  onTap: () => _pickDateTime(
                    initial: _endsAt ?? _startsAt,
                    onChanged: (value) => setState(() => _endsAt = value),
                  ),
                  onClear: _endsAt == null
                      ? null
                      : () => setState(() => _endsAt = null),
                ),
                _DropdownInput<String>(
                  label: 'Recurrence',
                  value: _recurrenceType,
                  items: const {
                    'none': 'One-time event',
                    'weekly': 'Weekly Programme',
                    'monthly_nth_weekday': 'Monthly Programme',
                  },
                  onChanged: (value) => setState(() {
                    _recurrenceType = value ?? 'none';
                    if (_startsAt != null)
                      _recurrenceWeekday = _startsAt!.weekday % 7;
                  }),
                ),
                if (_recurrenceType != 'none') ...[
                  _NumberStepper(
                    colors: colors,
                    label: 'Repeat every',
                    value: _recurrenceInterval,
                    suffix:
                        _recurrenceType == 'weekly' ? 'week(s)' : 'month(s)',
                    onChanged: (value) =>
                        setState(() => _recurrenceInterval = value),
                  ),
                  _DropdownInput<int>(
                    label: 'Day of week',
                    value: _recurrenceWeekday,
                    items: const {
                      0: 'Sunday',
                      1: 'Monday',
                      2: 'Tuesday',
                      3: 'Wednesday',
                      4: 'Thursday',
                      5: 'Friday',
                      6: 'Saturday',
                    },
                    onChanged: (value) =>
                        setState(() => _recurrenceWeekday = value ?? 0),
                  ),
                  if (_recurrenceType == 'monthly_nth_weekday')
                    _DropdownInput<int>(
                      label: 'Week of month',
                      value: _recurrenceWeekOfMonth,
                      items: const {
                        1: '1st',
                        2: '2nd',
                        3: '3rd',
                        4: '4th',
                        -1: 'Last',
                      },
                      onChanged: (value) => setState(
                        () => _recurrenceWeekOfMonth = value ?? 1,
                      ),
                    ),
                  _DateTile(
                    colors: colors,
                    label: 'Repeat until',
                    value: _recurrenceUntil,
                    dateOnly: true,
                    onTap: () => _pickDateTime(
                      initial: _recurrenceUntil ?? _startsAt,
                      dateOnly: true,
                      onChanged: (value) =>
                          setState(() => _recurrenceUntil = value),
                    ),
                    onClear: _recurrenceUntil == null
                        ? null
                        : () => setState(() => _recurrenceUntil = null),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _EditorSection(
              colors: colors,
              title: 'Registration and media',
              children: [
                _TextInput(
                  controller: _registrationUrlController,
                  label: 'Registration URL',
                  icon: Icons.link_outlined,
                  keyboardType: TextInputType.url,
                ),
                _DropdownInput<String>(
                  label: 'Registration availability',
                  value: _registrationAvailability,
                  items: const {
                    'everywhere': 'Everyone',
                    'nigeria': 'Nigeria only',
                    'outside_nigeria': 'Outside Nigeria only',
                  },
                  onChanged: (value) => setState(
                    () => _registrationAvailability = value ?? 'everywhere',
                  ),
                ),
                _ImagePickerTile(
                  colors: colors,
                  title: 'Feature image',
                  subtitle: 'Landscape image shown on event lists and banners.',
                  selectedFile: _thumbnail,
                  remoteUrl: _removeThumbnail ? '' : event?.thumbnailUrl ?? '',
                  onPick: () => _pickImage('thumbnail'),
                  onRemove: event?.thumbnailUrl.trim().isNotEmpty == true ||
                          _thumbnail != null
                      ? () => setState(() {
                            _thumbnail = null;
                            _removeThumbnail = true;
                          })
                      : null,
                ),
                _ImagePickerTile(
                  colors: colors,
                  title: 'Portrait image',
                  subtitle: 'Optional tall image for event detail screens.',
                  selectedFile: _portraitImage,
                  remoteUrl:
                      _removePortraitImage ? '' : event?.portraitImageUrl ?? '',
                  onPick: () => _pickImage('portrait'),
                  onRemove: event?.portraitImageUrl.trim().isNotEmpty == true ||
                          _portraitImage != null
                      ? () => setState(() {
                            _portraitImage = null;
                            _removePortraitImage = true;
                          })
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: colors.gold,
                  title: const Text('Published'),
                  subtitle: const Text('Show this event in the public app.'),
                  value: _isPublished,
                  onChanged: (value) => setState(() => _isPublished = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: colors.gold,
                  title: const Text('Pilgrimage event'),
                  subtitle:
                      const Text('Use pilgrimage styling on public pages.'),
                  value: _isPilgrimage,
                  onChanged: (value) => setState(() => _isPilgrimage = value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.gold,
                foregroundColor: colors.deep,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.deep,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save event'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.colors,
    required this.controller,
    required this.onSearch,
  });

  final _ChurchEventPalette colors;
  final TextEditingController controller;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(colors),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: const InputDecoration(
                labelText: 'Search events',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: colors.deep,
              foregroundColor: Colors.white,
            ),
            tooltip: 'Search',
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
    );
  }
}

class _ChurchEventCard extends StatelessWidget {
  const _ChurchEventCard({
    required this.colors,
    required this.event,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final _ChurchEventPalette colors;
  final ChurchEventManagement event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(colors),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.thumbnailUrl.trim().isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                event.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ImageFallback(colors: colors),
              ),
            )
          else
            SizedBox(height: 120, child: _ImageFallback(colors: colors)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      colors: colors,
                      label: event.statusLabel,
                      icon: event.isPublished
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    if (event.recurrenceLabel.trim().isNotEmpty)
                      _StatusChip(
                        colors: colors,
                        label: event.recurrenceLabel,
                        icon: Icons.repeat_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  event.title,
                  style: TextStyle(
                    color: colors.deep,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                if (event.theme.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.theme,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _EventMetaLine(
                  icon: Icons.schedule_outlined,
                  text: _dateRangeLabel(event.startDateTime, event.endDateTime),
                ),
                if (event.venue.trim().isNotEmpty)
                  _EventMetaLine(
                    icon: Icons.place_outlined,
                    text: event.venue,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: colors.gold,
                        title: const Text('Published'),
                        value: event.isPublished,
                        onChanged: onStatusChanged,
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
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.colors,
    required this.title,
    required this.children,
  });

  final _ChurchEventPalette colors;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.deep,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 14),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.required = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: required
          ? (value) =>
              (value ?? '').trim().isEmpty ? '$label is required.' : null
          : null,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _DropdownInput<T> extends StatelessWidget {
  const _DropdownInput({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items.entries
          .map(
            (entry) => DropdownMenuItem<T>(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.colors,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.dateOnly = false,
  });

  final _ChurchEventPalette colors;
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool dateOnly;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, color: colors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: colors.textMuted)),
                  const SizedBox(height: 4),
                  Text(
                    value == null
                        ? 'Select date'
                        : dateOnly
                            ? _dateOnly(value!)
                            : _dateTimeLabel(value!),
                    style: TextStyle(
                      color: colors.deep,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              )
            else
              const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.colors,
    required this.label,
    required this.value,
    required this.suffix,
    required this.onChanged,
  });

  final _ChurchEventPalette colors;
  final String label;
  final int value;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label: $value $suffix',
              style: TextStyle(
                color: colors.deep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Decrease',
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_rounded),
          ),
          IconButton(
            tooltip: 'Increase',
            onPressed: value >= 12 ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.selectedFile,
    required this.remoteUrl,
    required this.onPick,
    required this.onRemove,
  });

  final _ChurchEventPalette colors;
  final String title;
  final String subtitle;
  final PlatformFile? selectedFile;
  final String remoteUrl;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final localPath = selectedFile?.path;
    final hasLocal = localPath != null && localPath.trim().isNotEmpty;
    final hasRemote = remoteUrl.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasLocal)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.file(File(localPath), fit: BoxFit.cover),
            )
          else if (hasRemote)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                remoteUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ImageFallback(colors: colors),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.image_outlined, color: colors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedFile?.name ?? title,
                        style: TextStyle(
                          color: colors.deep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: colors.textMuted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Choose image',
                  onPressed: onPick,
                  icon: const Icon(Icons.upload_file_outlined),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove image',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChurchEventMessage extends StatelessWidget {
  const _ChurchEventMessage({
    required this.colors,
    required this.title,
    required this.message,
    this.actionLabel = 'Retry',
    this.onRetry,
  });

  final _ChurchEventPalette colors;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, color: colors.gold, size: 38),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: colors.deep,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: colors.textMuted)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.gold,
                foregroundColor: colors.deep,
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.colors});

  final _ChurchEventPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.field,
      alignment: Alignment.center,
      child: Icon(Icons.event_outlined, color: colors.gold, size: 44),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.colors,
    required this.label,
    required this.icon,
  });

  final _ChurchEventPalette colors;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.gold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.deep),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.deep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventMetaLine extends StatelessWidget {
  const _EventMetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF65747E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF65747E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration(_ChurchEventPalette colors) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: colors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

String _dateRangeLabel(DateTime? start, DateTime? end) {
  if (start == null && end == null) return 'Date not set';
  if (start != null && end != null) {
    return '${_dateTimeLabel(start)} - ${_dateTimeLabel(end)}';
  }
  return _dateTimeLabel(start ?? end!);
}

String _dateTimeLabel(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${_dateOnly(value)} $hour:$minute $period';
}

String _dateOnly(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _ChurchEventPalette {
  const _ChurchEventPalette({
    required this.deep,
    required this.gold,
    required this.teal,
    required this.background,
    required this.field,
    required this.border,
    required this.textMuted,
    required this.danger,
  });

  final Color deep;
  final Color gold;
  final Color teal;
  final Color background;
  final Color field;
  final Color border;
  final Color textMuted;
  final Color danger;

  static _ChurchEventPalette of(BuildContext context) {
    return const _ChurchEventPalette(
      deep: Color(0xFF092839),
      gold: Color(0xFFFFB72B),
      teal: Color(0xFF2A9D8F),
      background: Color(0xFFF4FAFD),
      field: Color(0xFFF1F6F8),
      border: Color(0xFFDCE8ED),
      textMuted: Color(0xFF65747E),
      danger: Color(0xFFC94C4C),
    );
  }
}
