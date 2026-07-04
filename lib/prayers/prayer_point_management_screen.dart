import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/Userdata.dart';
import '../utils/TimUtil.dart';
import 'prayer_api_client.dart';
import 'prayer_models.dart';

class PrayerPointManagementScreen extends StatefulWidget {
  const PrayerPointManagementScreen({
    super.key,
    required this.user,
  });

  final Userdata user;

  @override
  State<PrayerPointManagementScreen> createState() =>
      _PrayerPointManagementScreenState();
}

class _PrayerPointManagementScreenState
    extends State<PrayerPointManagementScreen> {
  final _api = PrayerApiClient();
  late Future<List<PrayerPoint>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PrayerPoint>> _load() =>
      _api.fetchManagedPrayerPoints(widget.user);

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openEditor([PrayerPoint? point]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PrayerPointEditorScreen(
          user: widget.user,
          point: point,
        ),
      ),
    );

    if (changed == true && mounted) await _refresh();
  }

  Future<void> _toggleStatus(PrayerPoint point, bool isPublished) async {
    try {
      await _api.updatePrayerPointStatus(
        user: widget.user,
        point: point,
        isPublished: isPublished,
      );
      if (mounted) await _refresh();
    } catch (error) {
      _showMessage(error);
    }
  }

  Future<void> _deletePoint(PrayerPoint point) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete prayer point?'),
        content: Text(
          'This will remove "${point.title}" from the app prayer points list.',
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
      await _api.deletePrayerPoint(user: widget.user, point: point);
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
    final colors = _PrayerPointManagementPalette.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Prayer Points'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Add prayer point',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add prayer point'),
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<List<PrayerPoint>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _PrayerPointMessage(
                colors: colors,
                title: 'Unable to load prayer points',
                message:
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                actionLabel: 'Retry',
                onAction: _refresh,
              );
            }

            final points = snapshot.data ?? const <PrayerPoint>[];
            if (points.isEmpty) {
              return _PrayerPointMessage(
                colors: colors,
                title: 'No prayer points yet',
                message: 'Create the first prayer point for the app.',
                actionLabel: 'Add prayer point',
                onAction: () => _openEditor(),
              );
            }

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                96 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: points.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final point = points[index];
                return _ManagedPrayerPointCard(
                  colors: colors,
                  point: point,
                  onEdit: () => _openEditor(point),
                  onDelete: () => _deletePoint(point),
                  onPublishedChanged: (value) => _toggleStatus(point, value),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class PrayerPointEditorScreen extends StatefulWidget {
  const PrayerPointEditorScreen({
    super.key,
    required this.user,
    this.point,
  });

  final Userdata user;
  final PrayerPoint? point;

  @override
  State<PrayerPointEditorScreen> createState() =>
      _PrayerPointEditorScreenState();
}

class _PrayerPointEditorScreenState extends State<PrayerPointEditorScreen> {
  final _api = PrayerApiClient();
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _date = TextEditingController();
  final _content = TextEditingController();
  bool _published = true;
  bool _saving = false;

  bool get _editing => widget.point != null;

  @override
  void initState() {
    super.initState();
    final point = widget.point;
    if (point != null) {
      _title.text = point.title;
      _author.text = point.author;
      _date.text = point.rawDate ?? '';
      _content.text = point.content;
      _published = point.isPublished;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _date.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_date.text.trim()) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    _date.text = _dateString(selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'author': _author.text.trim().isEmpty ? null : _author.text.trim(),
      'date': _date.text.trim().isEmpty ? null : _date.text.trim(),
      'content': _content.text.trim(),
      'is_published': _published,
    };

    try {
      if (_editing) {
        await _api.updatePrayerPoint(
          user: widget.user,
          point: widget.point!,
          payload: payload,
        );
      } else {
        await _api.createPrayerPoint(user: widget.user, payload: payload);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PrayerPointManagementPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_editing ? 'Edit Prayer Point' : 'New Prayer Point'),
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
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Title is required.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _author,
              decoration: const InputDecoration(labelText: 'Author'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _date,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Date',
                suffixIcon: IconButton(
                  tooltip: 'Choose date',
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _content,
              decoration: const InputDecoration(labelText: 'Prayer point'),
              minLines: 8,
              maxLines: 14,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Prayer point content is required.'
                  : null,
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              value: _published,
              onChanged: (value) => setState(() => _published = value),
              title: const Text('Publish in app'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving...' : 'Save prayer point'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagedPrayerPointCard extends StatelessWidget {
  const _ManagedPrayerPointCard({
    required this.colors,
    required this.point,
    required this.onEdit,
    required this.onDelete,
    required this.onPublishedChanged,
  });

  final _PrayerPointManagementPalette colors;
  final PrayerPoint point;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onPublishedChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.18 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrayerPointThumb(point: point, colors: colors),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.title,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pointMeta(point),
                      style: TextStyle(
                        color: colors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: point.isPublished,
                onChanged: onPublishedChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _plainText(point.content),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.text.withValues(alpha: 0.82)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit'),
              ),
              const SizedBox(width: 8),
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

class _PrayerPointThumb extends StatelessWidget {
  const _PrayerPointThumb({
    required this.point,
    required this.colors,
  });

  final PrayerPoint point;
  final _PrayerPointManagementPalette colors;

  @override
  Widget build(BuildContext context) {
    if (point.hasThumbnail) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: point.thumbnailUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallback(),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.favorite_border_rounded, color: colors.gold),
    );
  }
}

class _PrayerPointMessage extends StatelessWidget {
  const _PrayerPointMessage({
    required this.colors,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final _PrayerPointManagementPalette colors;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_rounded, color: colors.gold, size: 34),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(message, style: TextStyle(color: colors.muted, height: 1.4)),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
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

class _PrayerPointManagementPalette {
  const _PrayerPointManagementPalette({
    required this.isDark,
    required this.background,
    required this.card,
    required this.deep,
    required this.gold,
    required this.text,
    required this.muted,
    required this.border,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color deep;
  final Color gold;
  final Color text;
  final Color muted;
  final Color border;

  static _PrayerPointManagementPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PrayerPointManagementPalette(
      isDark: isDark,
      background: isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
      card: isDark ? const Color(0xFF102532) : Colors.white,
      deep: const Color(0xFF0C2230),
      gold: const Color(0xFFFFB82E),
      text: isDark ? Colors.white : const Color(0xFF102532),
      muted: isDark ? Colors.white60 : const Color(0xFF667780),
      border: isDark ? Colors.white12 : const Color(0xFFE0E8EE),
    );
  }
}

String _pointMeta(PrayerPoint point) {
  final parts = <String>[];
  if (point.author.trim().isNotEmpty) parts.add(point.author.trim());
  if (point.date > 0) parts.add(TimUtil.formatFullDatestamp(point.date));
  parts.add(point.isPublished ? 'Published' : 'Unpublished');
  return parts.join(' - ');
}

String _plainText(String value) {
  return value
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _dateString(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
