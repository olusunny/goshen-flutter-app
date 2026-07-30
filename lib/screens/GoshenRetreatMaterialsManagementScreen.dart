import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/GoshenRetreat.dart';
import '../models/Userdata.dart';
import '../service/GoshenRetreatApi.dart';

class GoshenRetreatMaterialsManagementScreen extends StatefulWidget {
  const GoshenRetreatMaterialsManagementScreen({
    super.key,
    required this.user,
    required this.initialEvent,
    required this.events,
  });

  final Userdata user;
  final GoshenRetreatEvent initialEvent;
  final List<GoshenRetreatEvent> events;

  @override
  State<GoshenRetreatMaterialsManagementScreen> createState() =>
      _GoshenRetreatMaterialsManagementScreenState();
}

class _GoshenRetreatMaterialsManagementScreenState
    extends State<GoshenRetreatMaterialsManagementScreen> {
  final _api = GoshenRetreatApi();
  late GoshenRetreatEvent _event;
  late Future<List<GoshenRetreatMaterial>> _future;

  @override
  void initState() {
    super.initState();
    _event = widget.initialEvent;
    _future = _load();
  }

  Future<List<GoshenRetreatMaterial>> _load() => _api.fetchEventMaterials(
        user: widget.user,
        event: _event,
      );

  Future<void> _reload() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _edit([GoshenRetreatMaterial? material]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MaterialEditorSheet(
        user: widget.user,
        event: _event,
        material: material,
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _delete(GoshenRetreatMaterial material) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete retreat material?'),
        content: Text('“${material.label}” will no longer be available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    try {
      await _api.deleteEventMaterial(
        user: widget.user,
        event: _event,
        material: material,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retreat material deleted.')),
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _MaterialsPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Retreat materials'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Upload material',
            onPressed: () => _edit(),
            icon: const Icon(Icons.upload_file_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            28 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: DropdownButtonFormField<String>(
                value: _event.publicId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Retreat event',
                  border: InputBorder.none,
                ),
                items: widget.events
                    .map((event) => DropdownMenuItem<String>(
                          value: event.publicId,
                          child: Text(
                            event.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (id) {
                  final selected = widget.events.where(
                    (event) => event.publicId == id,
                  );
                  if (selected.isEmpty) return;
                  setState(() {
                    _event = selected.first;
                    _future = _load();
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<GoshenRetreatMaterial>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _MaterialsMessage(
                    colors: colors,
                    icon: Icons.cloud_off_rounded,
                    title: 'Materials need a refresh',
                    message: _message(snapshot.error),
                    actionLabel: 'Retry',
                    onAction: _reload,
                  );
                }
                final materials =
                    snapshot.data ?? const <GoshenRetreatMaterial>[];
                if (materials.isEmpty) {
                  return _MaterialsMessage(
                    colors: colors,
                    icon: Icons.folder_open_rounded,
                    title: 'No materials yet',
                    message:
                        'Upload a PDF or image and publish it for ticket holders.',
                    actionLabel: 'Upload material',
                    onAction: () => _edit(),
                  );
                }
                return Column(
                  children: materials
                      .map((material) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _MaterialRow(
                              colors: colors,
                              material: material,
                              onEdit: () => _edit(material),
                              onDelete: () => _delete(material),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.colors,
    required this.material,
    required this.onEdit,
    required this.onDelete,
  });

  final _MaterialsPalette colors;
  final GoshenRetreatMaterial material;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final published = material.isPublished;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (material.isPdf ? colors.gold : colors.teal)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              material.isPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.image_outlined,
              color: material.isPdf ? colors.gold : colors.teal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.label.isEmpty ? 'Retreat material' : material.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${material.fileTypeLabel} · ${material.sizeLabel}',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  published ? 'Published' : 'Hidden',
                  style: TextStyle(
                    color: published ? colors.success : colors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit material',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete material',
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: colors.danger),
          ),
        ],
      ),
    );
  }
}

class _MaterialEditorSheet extends StatefulWidget {
  const _MaterialEditorSheet({
    required this.user,
    required this.event,
    this.material,
  });

  final Userdata user;
  final GoshenRetreatEvent event;
  final GoshenRetreatMaterial? material;

  @override
  State<_MaterialEditorSheet> createState() => _MaterialEditorSheetState();
}

class _MaterialEditorSheetState extends State<_MaterialEditorSheet> {
  final _api = GoshenRetreatApi();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  PlatformFile? _file;
  bool _published = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.material?.label ?? '');
    _published = widget.material?.isPublished ?? true;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: false,
    );
    final file = result?.files.isEmpty ?? true ? null : result!.files.first;
    if (file != null) setState(() => _file = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.material == null && _file == null) {
      _show('Choose a PDF or image to upload.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.saveEventMaterial(
        user: widget.user,
        event: widget.event,
        label: _label.text,
        isPublished: _published,
        file: _file,
        material: widget.material,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _show(_message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = _MaterialsPalette.of(context);
    final material = widget.material;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    material == null
                        ? 'Upload retreat material'
                        : 'Edit retreat material',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _label,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a label.'
                        : null,
                    decoration: _input(colors, 'Label'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.innerCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attach_file_rounded, color: colors.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _file?.name ?? material?.fileName ?? 'PDF or image',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Choose PDF or image',
                          onPressed: _saving ? null : _pickFile,
                          icon: const Icon(Icons.upload_file_outlined),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _published,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _published = value),
                    title: Text(
                      'Published for ticket holders',
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving...' : 'Save material'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialsMessage extends StatelessWidget {
  const _MaterialsMessage({
    required this.colors,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final _MaterialsPalette colors;
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: colors.gold, size: 38),
          const SizedBox(height: 12),
          Text(title,
              style:
                  TextStyle(color: colors.text, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.muted, height: 1.35)),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.gold,
              foregroundColor: colors.deep,
            ),
            onPressed: onAction,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _MaterialsPalette {
  const _MaterialsPalette({
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

  static _MaterialsPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _MaterialsPalette(
      background: dark ? const Color(0xFF071720) : const Color(0xFFF3F8FA),
      card: dark ? const Color(0xFF0C2733) : Colors.white,
      innerCard: dark ? const Color(0xFF0B202B) : const Color(0xFFF3F7FA),
      text: dark ? Colors.white : const Color(0xFF0C2230),
      muted: dark ? Colors.white70 : const Color(0xFF5D6D77),
      border:
          dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2EAF0),
      deep: const Color(0xFF0C2230),
      gold: const Color(0xFFFFB522),
      teal: const Color(0xFF2C9B88),
      success: const Color(0xFF188B67),
      danger: const Color(0xFFD1495B),
    );
  }
}

InputDecoration _input(_MaterialsPalette colors, String label) =>
    InputDecoration(
      labelText: label,
      filled: true,
      fillColor: colors.innerCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.border),
      ),
    );

String _message(Object? error) =>
    error.toString().replaceFirst('Exception: ', '');
