import 'package:flutter/material.dart';

import '../models/Userdata.dart';
import '../models/VerseOfDayManagement.dart';
import '../service/ControlHubVerseOfDayApi.dart';

class VerseOfDayManagementScreen extends StatefulWidget {
  const VerseOfDayManagementScreen({
    super.key,
    required this.user,
  });

  final Userdata user;

  @override
  State<VerseOfDayManagementScreen> createState() =>
      _VerseOfDayManagementScreenState();
}

class _VerseOfDayManagementScreenState
    extends State<VerseOfDayManagementScreen> {
  final _api = ControlHubVerseOfDayApi();
  final _searchController = TextEditingController();
  late Future<List<VerseOfDayManagement>> _future;

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

  Future<List<VerseOfDayManagement>> _load() {
    return _api.fetchVerses(widget.user, query: _searchController.text);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openEditor([VerseOfDayManagement? verse]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VerseOfDayEditorScreen(
          user: widget.user,
          initialVerse: verse,
        ),
      ),
    );

    if (changed == true && mounted) await _refresh();
  }

  Future<void> _toggleStatus(
    VerseOfDayManagement verse,
    bool isPublished,
  ) async {
    try {
      await _api.updateStatus(
        user: widget.user,
        verse: verse,
        isPublished: isPublished,
      );
      if (mounted) await _refresh();
    } catch (error) {
      _showMessage(error);
    }
  }

  Future<void> _deleteVerse(VerseOfDayManagement verse) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this verse?'),
        content: Text(
          'This removes ${verse.reference} from Verse of the Day. This cannot be undone.',
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
      await _api.deleteVerse(user: widget.user, verse: verse);
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
    final colors = _VersePalette.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Verse of the Day'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Add verse',
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
        label: const Text('Add verse'),
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<List<VerseOfDayManagement>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _VerseMessage(
                colors: colors,
                title: 'Unable to load verses',
                message:
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                actionLabel: 'Retry',
                onAction: _refresh,
              );
            }

            final verses = snapshot.data ?? const <VerseOfDayManagement>[];
            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                96 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _VerseSearchPanel(
                  colors: colors,
                  controller: _searchController,
                  onSearch: _refresh,
                ),
                const SizedBox(height: 16),
                if (verses.isEmpty)
                  _VerseMessage(
                    colors: colors,
                    title: 'No verses yet',
                    message:
                        'Create the first Verse of the Day entry for the app.',
                    actionLabel: 'Add verse',
                    onAction: () => _openEditor(),
                  )
                else
                  ...verses.map(
                    (verse) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _VerseCard(
                        colors: colors,
                        verse: verse,
                        onEdit: () => _openEditor(verse),
                        onDelete: () => _deleteVerse(verse),
                        onStatusChanged: (value) => _toggleStatus(verse, value),
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

class VerseOfDayEditorScreen extends StatefulWidget {
  const VerseOfDayEditorScreen({
    super.key,
    required this.user,
    this.initialVerse,
  });

  final Userdata user;
  final VerseOfDayManagement? initialVerse;

  @override
  State<VerseOfDayEditorScreen> createState() => _VerseOfDayEditorScreenState();
}

class _VerseOfDayEditorScreenState extends State<VerseOfDayEditorScreen> {
  final _api = ControlHubVerseOfDayApi();
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _referenceController = TextEditingController();
  final _versionController = TextEditingController(text: 'KJV');
  final _textController = TextEditingController();
  final _reflectionController = TextEditingController();
  final _prayerController = TextEditingController();
  bool _isPublished = true;
  bool _saving = false;

  bool get _editing => widget.initialVerse != null;

  @override
  void initState() {
    super.initState();
    final verse = widget.initialVerse;
    if (verse != null) {
      _dateController.text = verse.date;
      _referenceController.text = verse.reference;
      _versionController.text = verse.version;
      _textController.text = verse.text;
      _reflectionController.text = verse.reflection;
      _prayerController.text = verse.prayer;
      _isPublished = verse.isPublished;
    } else {
      _dateController.text = _dateString(DateTime.now());
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _referenceController.dispose();
    _versionController.dispose();
    _textController.dispose();
    _reflectionController.dispose();
    _prayerController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initialDate =
        DateTime.tryParse(_dateController.text.trim()) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (date == null) return;
    setState(() => _dateController.text = _dateString(date));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final payload = {
      'date': _dateController.text.trim(),
      'reference': _referenceController.text.trim(),
      'version': _versionController.text.trim().isEmpty
          ? 'KJV'
          : _versionController.text.trim(),
      'text': _textController.text.trim(),
      'reflection': _reflectionController.text.trim(),
      'prayer': _prayerController.text.trim(),
      'is_published': _isPublished,
    };

    try {
      if (_editing) {
        await _api.updateVerse(
          user: widget.user,
          verse: widget.initialVerse!,
          payload: payload,
        );
      } else {
        await _api.createVerse(user: widget.user, payload: payload);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _VersePalette.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_editing ? 'Edit Verse' : 'New Verse'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            32 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _verseDecoration(colors),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _referenceController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Reference',
                      hintText: 'Psalm 23:1',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _versionController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Bible version',
                      hintText: 'KJV',
                      prefixIcon: Icon(Icons.bookmark_border_rounded),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _textController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Verse text',
                      alignLabelWithHint: true,
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _reflectionController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Reflection (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _prayerController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Prayer (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: colors.gold,
                    title: const Text('Published'),
                    subtitle:
                        const Text('Show this verse in the app on its date.'),
                    value: _isPublished,
                    onChanged: (value) => setState(() => _isPublished = value),
                  ),
                  const SizedBox(height: 12),
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
                    label: Text(_saving ? 'Saving...' : 'Save verse'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerseSearchPanel extends StatelessWidget {
  const _VerseSearchPanel({
    required this.colors,
    required this.controller,
    required this.onSearch,
  });

  final _VersePalette colors;
  final TextEditingController controller;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _verseDecoration(colors),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: const InputDecoration(
                labelText: 'Search verses',
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

class _VerseCard extends StatelessWidget {
  const _VerseCard({
    required this.colors,
    required this.verse,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final _VersePalette colors;
  final VerseOfDayManagement verse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _verseDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.menu_book_outlined, color: colors.gold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verse.reference,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${verse.date} • ${verse.version}',
                      style: TextStyle(
                        color: colors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: verse.isPublished,
                activeColor: colors.gold,
                onChanged: onStatusChanged,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            verse.text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.muted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _VerseChip(colors: colors, label: verse.statusLabel),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerseChip extends StatelessWidget {
  const _VerseChip({required this.colors, required this.label});

  final _VersePalette colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: colors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.deep,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _VerseMessage extends StatelessWidget {
  const _VerseMessage({
    required this.colors,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final _VersePalette colors;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        32 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: _verseDecoration(colors),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_rounded, color: colors.gold, size: 34),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: colors.muted,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.gold,
                    foregroundColor: colors.deep,
                  ),
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VersePalette {
  const _VersePalette({
    required this.background,
    required this.card,
    required this.border,
    required this.deep,
    required this.gold,
    required this.text,
    required this.muted,
  });

  final Color background;
  final Color card;
  final Color border;
  final Color deep;
  final Color gold;
  final Color text;
  final Color muted;

  static _VersePalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _VersePalette(
      background: isDark ? const Color(0xFF07151D) : const Color(0xFFF4FAFC),
      card: isDark ? const Color(0xFF102A36) : Colors.white,
      border: isDark ? const Color(0xFF24434F) : const Color(0xFFDCE9EE),
      deep: const Color(0xFF0B2A37),
      gold: const Color(0xFFFFB72B),
      text: isDark ? Colors.white : const Color(0xFF0B2530),
      muted: isDark ? const Color(0xFFB8C8CE) : const Color(0xFF61727A),
    );
  }
}

BoxDecoration _verseDecoration(_VersePalette colors) {
  return BoxDecoration(
    color: colors.card,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: colors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

String? _required(String? value) {
  if ((value ?? '').trim().isEmpty) return 'This field is required.';
  return null;
}

String _dateString(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
