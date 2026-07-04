import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/DynamicForm.dart';
import '../models/Userdata.dart';
import '../service/DynamicFormApi.dart';

class DynamicFormManagementScreen extends StatefulWidget {
  const DynamicFormManagementScreen({
    super.key,
    required this.user,
  });

  final Userdata user;

  @override
  State<DynamicFormManagementScreen> createState() =>
      _DynamicFormManagementScreenState();
}

class _DynamicFormManagementScreenState
    extends State<DynamicFormManagementScreen> {
  final _api = DynamicFormApi();
  late Future<List<DynamicForm>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DynamicForm>> _load() => _api.fetchManagementForms(widget.user);

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openEditor([DynamicForm? form]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DynamicFormEditorScreen(
          user: widget.user,
          initialForm: form,
        ),
      ),
    );
    if (changed == true && mounted) await _refresh();
  }

  Future<void> _openSubmissions(DynamicForm form) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DynamicFormSubmissionsScreen(
          user: widget.user,
          form: form,
        ),
      ),
    );
  }

  Future<void> _toggleStatus(DynamicForm form, bool active) async {
    try {
      await _api.updateManagementStatus(
        user: widget.user,
        form: form,
        isActive: active,
      );
      if (mounted) await _refresh();
    } catch (error) {
      _showMessage(error);
    }
  }

  Future<void> _deleteForm(DynamicForm form) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this form?'),
        content: Text(
          form.submissionsCount > 0
              ? 'Forms with submissions are kept for record safety. Deactivate this form instead.'
              : 'This removes the form and its fields. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: form.submissionsCount > 0
                ? null
                : () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteManagementForm(user: widget.user, form: form);
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
    final colors = _FormManagementPalette.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Forms Management'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Add form',
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
        label: const Text('Add form'),
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<List<DynamicForm>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ManagementMessage(
                colors: colors,
                title: 'Unable to load forms',
                message:
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                onRetry: _refresh,
              );
            }

            final forms = snapshot.data ?? const [];
            if (forms.isEmpty) {
              return _ManagementMessage(
                colors: colors,
                title: 'No forms yet',
                message: 'Create the first on-demand form from here.',
                actionLabel: 'Add form',
                onRetry: () => _openEditor(),
              );
            }

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                96 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: forms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final form = forms[index];
                return _ManagedFormCard(
                  colors: colors,
                  form: form,
                  onEdit: () => _openEditor(form),
                  onSubmissions: () => _openSubmissions(form),
                  onDelete: () => _deleteForm(form),
                  onActiveChanged: (active) => _toggleStatus(form, active),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class DynamicFormEditorScreen extends StatefulWidget {
  const DynamicFormEditorScreen({
    super.key,
    required this.user,
    this.initialForm,
  });

  final Userdata user;
  final DynamicForm? initialForm;

  @override
  State<DynamicFormEditorScreen> createState() =>
      _DynamicFormEditorScreenState();
}

class _DynamicFormEditorScreenState extends State<DynamicFormEditorScreen> {
  final _api = DynamicFormApi();
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _slug = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _currency = TextEditingController(text: 'GBP');
  final _maxSubmissions = TextEditingController();
  final _submitLabel = TextEditingController(text: 'Submit');
  final _thankYou = TextEditingController();
  final _opensAt = TextEditingController();
  final _closesAt = TextEditingController();

  late bool _isActive;
  late bool _oneSubmissionPerUser;
  late bool _allowStripe;
  late bool _allowWallet;
  late String _visibility;
  late String _paymentType;
  late List<_FieldDraft> _fields;
  bool _saving = false;

  bool get _editing => widget.initialForm != null;

  @override
  void initState() {
    super.initState();
    final form = widget.initialForm;
    _isActive = form?.isActive ?? false;
    _oneSubmissionPerUser = form?.oneSubmissionPerUser ?? false;
    _allowStripe = form?.payment.allowStripe ?? true;
    _allowWallet = form?.payment.allowWallet ?? true;
    _visibility = form?.visibility ?? 'public';
    _paymentType = form?.payment.type ?? 'free';

    if (form != null) {
      _title.text = form.title;
      _slug.text = form.slug;
      _description.text = form.description;
      _amount.text =
          form.payment.amount > 0 ? form.payment.amount.toStringAsFixed(2) : '';
      _currency.text =
          form.payment.currency.trim().isEmpty ? 'GBP' : form.payment.currency;
      _maxSubmissions.text = form.maxSubmissions?.toString() ?? '';
      _submitLabel.text = form.submitButtonLabel;
      _thankYou.text = form.thankYouMessage;
      _opensAt.text = _dateInputText(form.opensAt);
      _closesAt.text = _dateInputText(form.closesAt);
      _fields = form.fields.map(_FieldDraft.fromField).toList();
    } else {
      _fields = [
        _FieldDraft(
          label: 'Your Name',
          keyName: 'your_name',
          type: 'text',
          isRequired: true,
          sortOrder: 1,
        ),
      ];
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _description.dispose();
    _amount.dispose();
    _currency.dispose();
    _maxSubmissions.dispose();
    _submitLabel.dispose();
    _thankYou.dispose();
    _opensAt.dispose();
    _closesAt.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
      initialDate: initial,
    );
    if (picked == null) return;
    controller.text = picked.toIso8601String().split('T').first;
  }

  Future<void> _editField(int index) async {
    final edited = await showModalBottomSheet<_FieldDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FieldDraftEditor(
        initial: _fields[index].copy(),
      ),
    );
    if (edited == null) return;
    setState(() => _fields[index] = edited);
  }

  Future<void> _addField() async {
    final next = _FieldDraft(
      label: 'New field',
      keyName: 'field_${_fields.length + 1}',
      type: 'text',
      sortOrder: _fields.length + 1,
    );
    final edited = await showModalBottomSheet<_FieldDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FieldDraftEditor(initial: next),
    );
    if (edited == null) return;
    setState(() => _fields.add(edited));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_fields.isEmpty) {
      _showMessage('Please add at least one field.');
      return;
    }

    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'slug': _slug.text.trim(),
      'description': _description.text.trim(),
      'is_active': _isActive,
      'visibility': _visibility,
      'one_submission_per_user': _oneSubmissionPerUser,
      'max_submissions': int.tryParse(_maxSubmissions.text.trim()),
      'payment_type': _paymentType,
      'fixed_amount': double.tryParse(_amount.text.trim()),
      'currency': _currency.text.trim().isEmpty ? 'GBP' : _currency.text.trim(),
      'allow_stripe': _allowStripe,
      'allow_wallet': _allowWallet,
      'opens_at': _opensAt.text.trim().isEmpty ? null : _opensAt.text.trim(),
      'closes_at': _closesAt.text.trim().isEmpty ? null : _closesAt.text.trim(),
      'submit_button_label': _submitLabel.text.trim().isEmpty
          ? 'Submit'
          : _submitLabel.text.trim(),
      'thank_you_message': _thankYou.text.trim(),
      'fields': _fields.asMap().entries.map((entry) {
        return entry.value.toPayload(entry.key + 1);
      }).toList(),
    };

    setState(() => _saving = true);
    try {
      if (_editing) {
        await _api.updateManagementForm(
          user: widget.user,
          form: widget.initialForm!,
          payload: payload,
        );
      } else {
        await _api.createManagementForm(user: widget.user, payload: payload);
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
    final colors = _FormManagementPalette.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_editing ? 'Edit form' : 'Add form'),
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
            _EditorCard(
              colors: colors,
              children: [
                _FormTextField(
                  controller: _title,
                  label: 'Form title',
                  required: true,
                ),
                const SizedBox(height: 12),
                _FormTextField(
                  controller: _slug,
                  label: 'Slug',
                  helper: 'Leave blank to generate from the title.',
                ),
                const SizedBox(height: 12),
                _FormTextField(
                  controller: _description,
                  label: 'Description',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text('Active'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: _oneSubmissionPerUser,
                  onChanged: (value) =>
                      setState(() => _oneSubmissionPerUser = value),
                  title: const Text('One submission per user'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _EditorCard(
              colors: colors,
              children: [
                _FormDropdown(
                  label: 'Visibility',
                  value: _visibility,
                  options: const {
                    'public': 'Public',
                    'authenticated': 'Members only',
                  },
                  onChanged: (value) => setState(() => _visibility = value),
                ),
                const SizedBox(height: 12),
                _FormDropdown(
                  label: 'Payment',
                  value: _paymentType,
                  options: const {
                    'free': 'Free',
                    'fixed': 'Fixed paid',
                  },
                  onChanged: (value) => setState(() => _paymentType = value),
                ),
                if (_paymentType == 'fixed') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FormTextField(
                          controller: _amount,
                          label: 'Amount',
                          keyboardType: TextInputType.number,
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 96,
                        child: _FormTextField(
                          controller: _currency,
                          label: 'Currency',
                          required: true,
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    value: _allowStripe,
                    onChanged: (value) => setState(() => _allowStripe = value),
                    title: const Text('Allow Stripe'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: _allowWallet,
                    onChanged: (value) => setState(() => _allowWallet = value),
                    title: const Text('Allow wallet'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _EditorCard(
              colors: colors,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FormTextField(
                        controller: _opensAt,
                        label: 'Opens at',
                        readOnly: true,
                        onTap: () => _pickDate(_opensAt),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FormTextField(
                        controller: _closesAt,
                        label: 'Closes at',
                        readOnly: true,
                        onTap: () => _pickDate(_closesAt),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _FormTextField(
                  controller: _maxSubmissions,
                  label: 'Maximum submissions',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _FormTextField(
                  controller: _submitLabel,
                  label: 'Submit button label',
                ),
                const SizedBox(height: 12),
                _FormTextField(
                  controller: _thankYou,
                  label: 'Thank you message',
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _EditorCard(
              colors: colors,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fields',
                        style: TextStyle(
                          color: colors.deep,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add field',
                      onPressed: _addField,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < _fields.length; index++) ...[
                  _FieldDraftTile(
                    colors: colors,
                    draft: _fields[index],
                    onEdit: () => _editField(index),
                    onDelete: () => setState(() => _fields.removeAt(index)),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save form'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DynamicFormSubmissionsScreen extends StatefulWidget {
  const DynamicFormSubmissionsScreen({
    super.key,
    required this.user,
    required this.form,
  });

  final Userdata user;
  final DynamicForm form;

  @override
  State<DynamicFormSubmissionsScreen> createState() =>
      _DynamicFormSubmissionsScreenState();
}

class _DynamicFormSubmissionsScreenState
    extends State<DynamicFormSubmissionsScreen> {
  final _api = DynamicFormApi();
  late Future<List<DynamicFormSubmissionRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchManagementSubmissions(
      user: widget.user,
      form: widget.form,
    );
  }

  Future<void> _refresh() async {
    final future = _api.fetchManagementSubmissions(
      user: widget.user,
      form: widget.form,
    );
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _FormManagementPalette.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Form Submissions'),
        backgroundColor: colors.deep,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: colors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<List<DynamicFormSubmissionRecord>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ManagementMessage(
                colors: colors,
                title: 'Unable to load submissions',
                message:
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                onRetry: _refresh,
              );
            }

            final submissions = snapshot.data ?? const [];
            if (submissions.isEmpty) {
              return _ManagementMessage(
                colors: colors,
                title: 'No submissions yet',
                message: 'Responses will appear here when users submit.',
                onRetry: _refresh,
              );
            }

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: submissions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _SubmissionTile(
                  colors: colors,
                  submission: submissions[index],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ManagedFormCard extends StatelessWidget {
  const _ManagedFormCard({
    required this.colors,
    required this.form,
    required this.onEdit,
    required this.onSubmissions,
    required this.onDelete,
    required this.onActiveChanged,
  });

  final _FormManagementPalette colors;
  final DynamicForm form;
  final VoidCallback onEdit;
  final VoidCallback onSubmissions;
  final VoidCallback onDelete;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ManagementIcon(colors: colors, icon: Icons.dynamic_form_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  form.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.deep,
                    fontSize: 20,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Switch(
                value: form.isActive,
                activeColor: colors.gold,
                onChanged: onActiveChanged,
              ),
            ],
          ),
          if (form.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              form.description.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.muted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(
                colors: colors,
                label: form.isActive ? 'Active' : 'Inactive',
                gold: form.isActive,
              ),
              _MiniChip(
                colors: colors,
                label: form.requiresLogin ? 'Members only' : 'Public',
              ),
              _MiniChip(colors: colors, label: '${form.fields.length} fields'),
              _MiniChip(
                colors: colors,
                label: '${form.submissionsCount} submissions',
              ),
              if (form.requiresPayment)
                _MiniChip(
                  colors: colors,
                  gold: true,
                  label:
                      '${form.payment.currency} ${form.payment.amount.toStringAsFixed(2)}',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSubmissions,
                  icon: const Icon(Icons.inbox_outlined),
                  label: const Text('Submissions'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Edit',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({
    required this.colors,
    required this.submission,
  });

  final _FormManagementPalette colors;
  final DynamicFormSubmissionRecord submission;

  @override
  Widget build(BuildContext context) {
    final title = submission.name.trim().isNotEmpty
        ? submission.name.trim()
        : submission.email.trim().isNotEmpty
            ? submission.email.trim()
            : submission.reference;

    return Container(
      decoration: _cardDecoration(colors),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          title,
          style: TextStyle(
            color: colors.deep,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          [
            _friendlyDate(submission.submittedAt),
            submission.status,
            if (submission.paymentStatus.isNotEmpty) submission.paymentStatus,
          ].where((item) => item.trim().isNotEmpty).join(' • '),
          style: TextStyle(color: colors.muted, fontWeight: FontWeight.w600),
        ),
        children: [
          if (submission.email.trim().isNotEmpty)
            _AnswerLine(label: 'Email', value: submission.email),
          if (submission.phone.trim().isNotEmpty)
            _AnswerLine(label: 'Phone', value: submission.phone),
          if (submission.amount != null)
            _AnswerLine(
              label: 'Amount',
              value:
                  '${submission.currency} ${submission.amount!.toStringAsFixed(2)}',
            ),
          for (final answer in submission.answers.values)
            _AnswerLine(
              label: answer.label,
              value: answer.displayValue.isEmpty ? '-' : answer.displayValue,
              downloadUrl: answer.downloadUrl,
            ),
        ],
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.label,
    required this.value,
    this.downloadUrl = '',
  });

  final String label;
  final String value;
  final String downloadUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: Text(value)),
          if (downloadUrl.isNotEmpty)
            IconButton(
              tooltip: 'Open file',
              onPressed: () => launchUrl(
                Uri.parse(downloadUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
        ],
      ),
    );
  }
}

class _FieldDraftTile extends StatelessWidget {
  const _FieldDraftTile({
    required this.colors,
    required this.draft,
    required this.onEdit,
    required this.onDelete,
  });

  final _FormManagementPalette colors;
  final _FieldDraft draft;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator_rounded, color: colors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.deep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${draft.keyName} • ${draft.typeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit field',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete field',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _FieldDraftEditor extends StatefulWidget {
  const _FieldDraftEditor({required this.initial});

  final _FieldDraft initial;

  @override
  State<_FieldDraftEditor> createState() => _FieldDraftEditorState();
}

class _FieldDraftEditorState extends State<_FieldDraftEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _keyName;
  late final TextEditingController _placeholder;
  late final TextEditingController _help;
  late final TextEditingController _options;
  late final TextEditingController _maxLength;
  late final TextEditingController _maxKb;
  late final TextEditingController _extensions;
  late bool _required;
  late String _type;

  @override
  void initState() {
    super.initState();
    final draft = widget.initial;
    _label = TextEditingController(text: draft.label);
    _keyName = TextEditingController(text: draft.keyName);
    _placeholder = TextEditingController(text: draft.placeholder);
    _help = TextEditingController(text: draft.helpText);
    _options = TextEditingController(text: draft.optionsText);
    _maxLength = TextEditingController(text: draft.maxLengthText);
    _maxKb = TextEditingController(text: draft.maxKbText);
    _extensions = TextEditingController(text: draft.allowedExtensionsText);
    _required = draft.isRequired;
    _type = draft.type;
  }

  @override
  void dispose() {
    _label.dispose();
    _keyName.dispose();
    _placeholder.dispose();
    _help.dispose();
    _options.dispose();
    _maxLength.dispose();
    _maxKb.dispose();
    _extensions.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      widget.initial.copy(
        label: _label.text.trim(),
        keyName: _keyName.text.trim(),
        type: _type,
        placeholder: _placeholder.text.trim(),
        helpText: _help.text.trim(),
        optionsText: _options.text.trim(),
        maxLengthText: _maxLength.text.trim(),
        maxKbText: _maxKb.text.trim(),
        allowedExtensionsText: _extensions.text.trim(),
        isRequired: _required,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _FormManagementPalette.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final hasOptions = _type == 'choice' || _type == 'multi_choice';
    final isText = const {'text', 'textarea', 'email', 'phone'}.contains(_type);
    final isFile = _type == 'file';

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Field setup',
                style: TextStyle(
                  color: colors.deep,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              _FormTextField(
                controller: _label,
                label: 'Label',
                required: true,
              ),
              const SizedBox(height: 12),
              _FormTextField(
                controller: _keyName,
                label: 'Answer key',
                helper: 'Use letters, numbers, and underscores.',
              ),
              const SizedBox(height: 12),
              _FormDropdown(
                label: 'Type',
                value: _type,
                options: _fieldTypeLabels,
                onChanged: (value) => setState(() => _type = value),
              ),
              const SizedBox(height: 12),
              _FormTextField(
                controller: _placeholder,
                label: 'Placeholder',
              ),
              const SizedBox(height: 12),
              _FormTextField(
                controller: _help,
                label: 'Help text',
                maxLines: 2,
              ),
              if (hasOptions) ...[
                const SizedBox(height: 12),
                _FormTextField(
                  controller: _options,
                  label: 'Options',
                  helper: 'One option per line.',
                  maxLines: 4,
                  required: true,
                ),
              ],
              if (isText) ...[
                const SizedBox(height: 12),
                _FormTextField(
                  controller: _maxLength,
                  label: 'Maximum text length',
                  keyboardType: TextInputType.number,
                ),
              ],
              if (isFile) ...[
                const SizedBox(height: 12),
                _FormTextField(
                  controller: _maxKb,
                  label: 'Maximum file size KB',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _FormTextField(
                  controller: _extensions,
                  label: 'Allowed file extensions',
                  helper: 'Example: pdf, png, jpg, jpeg',
                ),
              ],
              SwitchListTile(
                value: _required,
                onChanged: (value) => setState(() => _required = value),
                title: const Text('Required'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save field'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldDraft {
  _FieldDraft({
    this.id,
    required this.label,
    required this.keyName,
    required this.type,
    this.placeholder = '',
    this.helpText = '',
    this.optionsText = '',
    this.maxLengthText = '',
    this.maxKbText = '10240',
    this.allowedExtensionsText = 'pdf, jpg, jpeg, png, webp',
    this.isRequired = false,
    this.sortOrder = 0,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? conditionalLogic,
  })  : settings = settings ?? <String, dynamic>{},
        conditionalLogic = conditionalLogic ?? <String, dynamic>{};

  final int? id;
  final String label;
  final String keyName;
  final String type;
  final String placeholder;
  final String helpText;
  final String optionsText;
  final String maxLengthText;
  final String maxKbText;
  final String allowedExtensionsText;
  final bool isRequired;
  final int sortOrder;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> conditionalLogic;

  String get typeLabel => _fieldTypeLabels[type] ?? type;

  factory _FieldDraft.fromField(DynamicFormField field) {
    return _FieldDraft(
      id: field.id == 0 ? null : field.id,
      label: field.label,
      keyName: field.key,
      type: field.type,
      placeholder: field.placeholder,
      helpText: field.helpText,
      optionsText: field.options.map((option) => option.label).join('\n'),
      maxLengthText: '${field.settings['max_length'] ?? ''}',
      maxKbText: '${field.settings['max_kb'] ?? field.maxFileSizeKb}',
      allowedExtensionsText: field.allowedFileExtensions.join(', '),
      isRequired: field.isRequired,
      sortOrder: field.sortOrder,
      settings: Map<String, dynamic>.from(field.settings),
      conditionalLogic: Map<String, dynamic>.from(field.conditionalLogic),
    );
  }

  _FieldDraft copy({
    String? label,
    String? keyName,
    String? type,
    String? placeholder,
    String? helpText,
    String? optionsText,
    String? maxLengthText,
    String? maxKbText,
    String? allowedExtensionsText,
    bool? isRequired,
  }) {
    return _FieldDraft(
      id: id,
      label: label ?? this.label,
      keyName: keyName ?? this.keyName,
      type: type ?? this.type,
      placeholder: placeholder ?? this.placeholder,
      helpText: helpText ?? this.helpText,
      optionsText: optionsText ?? this.optionsText,
      maxLengthText: maxLengthText ?? this.maxLengthText,
      maxKbText: maxKbText ?? this.maxKbText,
      allowedExtensionsText:
          allowedExtensionsText ?? this.allowedExtensionsText,
      isRequired: isRequired ?? this.isRequired,
      sortOrder: sortOrder,
      settings: Map<String, dynamic>.from(settings),
      conditionalLogic: Map<String, dynamic>.from(conditionalLogic),
    );
  }

  Map<String, dynamic> toPayload(int fallbackSortOrder) {
    final payloadSettings = Map<String, dynamic>.from(settings);
    if (const {'text', 'textarea', 'email', 'phone'}.contains(type)) {
      payloadSettings['max_length'] = int.tryParse(maxLengthText.trim());
    }
    if (type == 'file') {
      payloadSettings['max_kb'] = int.tryParse(maxKbText.trim()) ?? 10240;
      payloadSettings['allowed_extensions'] = _splitLinesOrCommas(
        allowedExtensionsText,
      );
    }

    return {
      if (id != null) 'id': id,
      'label': label,
      'key': keyName,
      'type': type,
      'placeholder': placeholder,
      'help_text': helpText,
      'options': _splitLinesOrCommas(optionsText),
      'settings': payloadSettings,
      'conditional_logic': conditionalLogic,
      'is_required': isRequired,
      'sort_order': sortOrder > 0 ? sortOrder : fallbackSortOrder,
    };
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.colors,
    required this.children,
  });

  final _FormManagementPalette colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _FormTextField extends StatelessWidget {
  const _FormTextField({
    required this.controller,
    required this.label,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.helper,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? helper;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      validator: (value) {
        if (required && (value ?? '').trim().isEmpty) {
          return 'Please enter $label.';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        helperText: helper,
      ),
    );
  }
}

class _FormDropdown extends StatelessWidget {
  const _FormDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: options.containsKey(value) ? value : options.keys.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.colors,
    required this.label,
    this.gold = false,
  });

  final _FormManagementPalette colors;
  final String label;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: gold ? colors.gold.withValues(alpha: 0.16) : colors.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: gold ? colors.deep : colors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ManagementIcon extends StatelessWidget {
  const _ManagementIcon({
    required this.colors,
    required this.icon,
  });

  final _FormManagementPalette colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: colors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: colors.gold),
    );
  }
}

class _ManagementMessage extends StatelessWidget {
  const _ManagementMessage({
    required this.colors,
    required this.title,
    required this.message,
    this.actionLabel = 'Retry',
    this.onRetry,
  });

  final _FormManagementPalette colors;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 34),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: _cardDecoration(colors),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_rounded, color: colors.gold, size: 38),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: colors.deep,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FormManagementPalette {
  const _FormManagementPalette({
    required this.deep,
    required this.gold,
    required this.teal,
    required this.background,
    required this.soft,
    required this.line,
    required this.muted,
  });

  final Color deep;
  final Color gold;
  final Color teal;
  final Color background;
  final Color soft;
  final Color line;
  final Color muted;

  static _FormManagementPalette of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _FormManagementPalette(
      deep: const Color(0xFF08293A),
      gold: const Color(0xFFFFB629),
      teal: const Color(0xFF2C9B88),
      background: scheme.surface,
      soft: const Color(0xFFF2F8FB),
      line: const Color(0xFFDDE9EE),
      muted: const Color(0xFF687782),
    );
  }
}

BoxDecoration _cardDecoration(_FormManagementPalette colors) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: colors.line),
    boxShadow: [
      BoxShadow(
        color: colors.deep.withValues(alpha: 0.06),
        blurRadius: 22,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

const _fieldTypeLabels = <String, String>{
  'text': 'Short text',
  'textarea': 'Long text',
  'email': 'Email',
  'phone': 'Phone',
  'number': 'Number',
  'date': 'Date',
  'choice': 'Single choice',
  'multi_choice': 'Multiple choice',
  'checkbox': 'Checkbox',
  'consent': 'Consent checkbox',
  'image_choice': 'Image choice',
  'color_choice': 'Colour choice',
  'file': 'File upload',
};

List<String> _splitLinesOrCommas(String value) {
  return value
      .split(RegExp(r'[\r\n,]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

String _dateInputText(DateTime? date) {
  if (date == null) return '';
  return date.toIso8601String().split('T').first;
}

String _friendlyDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} $hour:$minute';
}
