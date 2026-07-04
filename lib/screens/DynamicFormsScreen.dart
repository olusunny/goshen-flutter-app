import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/LoginScreen.dart';
import '../models/DynamicForm.dart';
import '../models/Userdata.dart';
import '../providers/AppStateManager.dart';
import '../service/DynamicFormApi.dart';
import '../wallet_security/wallet_security_guard.dart';

class DynamicFormsScreen extends StatefulWidget {
  const DynamicFormsScreen({super.key});

  static const routeName = '/dynamic-forms';

  @override
  State<DynamicFormsScreen> createState() => _DynamicFormsScreenState();
}

class _DynamicFormsScreenState extends State<DynamicFormsScreen> {
  final _api = DynamicFormApi();
  late Future<List<DynamicForm>> _future;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    final cached = _api.cachedForms(user);
    _future = cached == null ? _load() : Future.value(cached);
    if (cached != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _refresh(silent: true));
    }
  }

  Future<List<DynamicForm>> _load() {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    return _api.fetchForms(user);
  }

  Future<void> _refresh({bool silent = false}) async {
    final next = _load();
    if (!silent) {
      setState(() {
        _future = next;
      });
    }

    try {
      final forms = await next;
      if (mounted && silent) {
        setState(() {
          _future = Future.value(forms);
        });
      }
    } catch (_) {
      if (!silent) rethrow;
    }
  }

  Future<void> _openForm(DynamicForm form) async {
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DynamicFormDetailScreen(initialForm: form),
      ),
    );
    if (refreshed == true && mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _DynamicFormsPalette.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Active Forms')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DynamicForm>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _MessageState(
                colors: colors,
                icon: Icons.cloud_off_rounded,
                title: 'Unable to load forms',
                message:
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                actionLabel: 'Retry',
                onAction: () => _refresh(),
              );
            }

            final forms = snapshot.data ?? const [];
            if (forms.isEmpty) {
              return _MessageState(
                colors: colors,
                icon: Icons.dynamic_form_rounded,
                title: 'No open forms right now',
                message: 'When a form is available, it will appear here.',
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
              children: [
                _FormsHero(colors: colors),
                const SizedBox(height: 18),
                for (final form in forms) ...[
                  _DynamicFormCard(
                    form: form,
                    colors: colors,
                    onTap: () => _openForm(form),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class DynamicFormDetailScreen extends StatefulWidget {
  const DynamicFormDetailScreen({
    super.key,
    required this.initialForm,
  });

  final DynamicForm initialForm;

  @override
  State<DynamicFormDetailScreen> createState() =>
      _DynamicFormDetailScreenState();
}

class _DynamicFormDetailScreenState extends State<DynamicFormDetailScreen> {
  final _api = DynamicFormApi();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _contactKey = GlobalKey();
  final _paymentKey = GlobalKey();
  final _fieldKeys = <String, GlobalKey>{};
  final _fieldControllers = <String, TextEditingController>{};
  final _answers = <String, dynamic>{};
  final _files = <String, PlatformFile>{};
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  late Future<DynamicForm> _future;
  String _paymentMethod = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    _prefillContact(user);
    _selectDefaultPayment(widget.initialForm);
    _future = _api.fetchForm(
      form: widget.initialForm.identifier,
      user: user,
    );
  }

  @override
  void dispose() {
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _prefillContact(Userdata? user) {
    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';
    _phoneController.text = user?.phone ?? '';
  }

  void _selectDefaultPayment(DynamicForm form) {
    if (!form.requiresPayment) {
      _paymentMethod = '';
    } else if (form.payment.allowStripe) {
      _paymentMethod = 'stripe';
    } else if (form.payment.allowWallet) {
      _paymentMethod = 'wallet';
    }
  }

  void _ensureControllers(DynamicForm form) {
    for (final field in form.fields) {
      _fieldKeys.putIfAbsent(field.key, () => GlobalKey());
      if (!field.isTextLike) continue;
      _fieldControllers.putIfAbsent(field.key, () => TextEditingController());
    }
  }

  Future<void> _submit(DynamicForm form) async {
    if (_submitting) return;
    if (form.alreadySubmitted) {
      _showMessage('You have already submitted this form.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _scrollToFirstInvalid(form);
      return;
    }

    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (form.requiresPayment && _paymentMethod.isEmpty) {
      _showMessage('Please choose a payment method.');
      _scrollToKey(_paymentKey);
      return;
    }

    if (_paymentMethod == 'wallet') {
      if (user == null || (user.apiToken ?? '').trim().isEmpty) {
        _showSignInPrompt();
        return;
      }

      final unlocked = await WalletSecurityGuard.ensureWalletUnlocked(
        context,
        requireFreshVerification: true,
      );
      if (!unlocked || !mounted) return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _api.submitForm(
        form: form,
        answers: _collectAnswers(form),
        files: _visibleFiles(form),
        paymentMethod: _paymentMethod,
        user: user,
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
      );

      if (!mounted) return;
      if (result.hasCheckout) {
        final launched = await launchUrl(
          Uri.parse(result.checkoutUrl),
          mode: LaunchMode.externalApplication,
        );

        if (!mounted) return;
        if (!launched) {
          _showMessage('Could not open the secure payment page.');
          return;
        }

        await _showSuccessDialog(
          title: 'Complete secure checkout',
          message:
              'Stripe Checkout has opened in your browser. Return to the app after payment is complete.',
        );
        if (mounted) Navigator.pop(context, true);
        return;
      }

      await _showSuccessDialog(
        title: 'Form submitted',
        message: result.reference.isEmpty
            ? result.message
            : '${result.message}\n\nReference: ${result.reference}',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Map<String, dynamic> _collectAnswers(DynamicForm form) {
    final answers = <String, dynamic>{};
    for (final field in _visibleFields(form)) {
      if (field.type == 'file') continue;

      dynamic value;
      if (field.isTextLike) {
        value = _fieldControllers[field.key]?.text.trim();
      } else {
        value = _answers[field.key];
      }

      if (_isBlank(value)) continue;
      answers[field.key] = value;
    }
    return answers;
  }

  Map<String, PlatformFile> _visibleFiles(DynamicForm form) {
    final keys = _visibleFields(form)
        .where((field) => field.type == 'file')
        .map((field) => field.key)
        .toSet();
    return Map<String, PlatformFile>.fromEntries(
      _files.entries.where((entry) => keys.contains(entry.key)),
    );
  }

  List<DynamicFormField> _visibleFields(DynamicForm form) {
    return form.fields.where(_fieldIsVisible).toList();
  }

  void _scrollToFirstInvalid(DynamicForm form) {
    final target = _firstInvalidKey(form);
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToKey(target));
  }

  GlobalKey? _firstInvalidKey(DynamicForm form) {
    if (form.requiresPayment) {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      if (name.isEmpty || email.isEmpty || !email.contains('@')) {
        return _contactKey;
      }
      if (_paymentMethod.isEmpty) {
        return _paymentKey;
      }
    }

    for (final field in _visibleFields(form)) {
      final value = field.type == 'file'
          ? _files[field.key]
          : (field.isTextLike
              ? _fieldControllers[field.key]?.text.trim()
              : _answers[field.key]);

      if (field.isRequired &&
          (field.type == 'checkbox' || field.type == 'consent')) {
        if (value != true) return _fieldKeys[field.key];
      } else if (field.isRequired && _isBlank(value)) {
        return _fieldKeys[field.key];
      }

      if (field.type == 'email' &&
          !_isBlank(value) &&
          !('$value').contains('@')) {
        return _fieldKeys[field.key];
      }
      if (field.type == 'number' &&
          !_isBlank(value) &&
          double.tryParse('$value') == null) {
        return _fieldKeys[field.key];
      }
    }

    return null;
  }

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  bool _fieldIsVisible(DynamicFormField field) {
    final logic = field.conditionalLogic;
    if (!_readBool(logic['enabled'])) return true;

    final sourceKey =
        '${logic['field_key'] ?? logic['question_key'] ?? ''}'.trim();
    if (sourceKey.isEmpty) return true;

    final expected = '${logic['value'] ?? ''}'.trim().toLowerCase();
    final values = _comparisonValues(_answerForKey(sourceKey));
    final answered = values.any((value) => value.trim().isNotEmpty);
    final operator = '${logic['operator'] ?? 'equals'}';

    switch (operator) {
      case 'answered':
        return answered;
      case 'not_answered':
        return !answered;
      case 'not_equals':
        return !values.any((value) => value.toLowerCase() == expected);
      case 'contains':
        return values.any((value) => value.toLowerCase().contains(expected));
      case 'not_contains':
        return !values.any((value) => value.toLowerCase().contains(expected));
      case 'equals':
      default:
        return values.any((value) => value.toLowerCase() == expected);
    }
  }

  dynamic _answerForKey(String key) {
    final controller = _fieldControllers[key];
    if (controller != null) return controller.text.trim();
    return _answers[key];
  }

  List<String> _comparisonValues(dynamic value) {
    if (value is List) return value.map((item) => '$item').toList();
    if (value is Map && value.containsKey('value'))
      return ['${value['value']}'];
    if (value == null) return [''];
    return ['$value'];
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSignInPrompt() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign in required'),
        content: const Text('Please sign in before using wallet payment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, LoginScreen.routeName);
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessDialog({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _DynamicFormsPalette.of(context);
    final user = Provider.of<AppStateManager>(context).userdata;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text(widget.initialForm.title)),
      body: FutureBuilder<DynamicForm>(
        future: _future,
        builder: (context, snapshot) {
          final form = snapshot.data ?? widget.initialForm;
          _ensureControllers(form);
          if (snapshot.hasData && _paymentMethod.isEmpty) {
            _selectDefaultPayment(form);
          }

          return Form(
            key: _formKey,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
              children: [
                if (snapshot.hasError)
                  _InlineNotice(
                    colors: colors,
                    icon: Icons.info_outline_rounded,
                    message:
                        'Showing the last loaded version. Pull down from the forms list to refresh.',
                  ),
                _FormHeaderCard(form: form, colors: colors),
                const SizedBox(height: 16),
                if (form.alreadySubmitted)
                  _InlineNotice(
                    colors: colors,
                    icon: Icons.check_circle_outline_rounded,
                    message: 'You have already submitted this form.',
                  ),
                if (form.requiresLogin && user == null)
                  _InlineNotice(
                    colors: colors,
                    icon: Icons.lock_outline_rounded,
                    message: 'Please sign in before submitting this form.',
                  ),
                if (form.requiresPayment) ...[
                  _PaymentCard(
                    key: _paymentKey,
                    form: form,
                    colors: colors,
                    selectedMethod: _paymentMethod,
                    onChanged: (method) {
                      setState(() {
                        _paymentMethod = method;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _ContactCard(
                    key: _contactKey,
                    colors: colors,
                    nameController: _nameController,
                    emailController: _emailController,
                    phoneController: _phoneController,
                  ),
                  const SizedBox(height: 16),
                ],
                _QuestionCard(
                  colors: colors,
                  children: [
                    for (final field in _visibleFields(form)) ...[
                      KeyedSubtree(
                        key: _fieldKeys.putIfAbsent(
                            field.key, () => GlobalKey()),
                        child: _buildField(field, colors),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ||
                            form.alreadySubmitted ||
                            (form.requiresLogin && user == null)
                        ? null
                        : () => _submit(form),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(form.requiresPayment
                            ? Icons.lock_outline_rounded
                            : Icons.send_rounded),
                    label: Text(
                      _submitting
                          ? 'Submitting...'
                          : (form.submitButtonLabel.trim().isEmpty
                              ? 'Submit'
                              : form.submitButtonLabel),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.gold,
                      foregroundColor: colors.primary,
                      disabledBackgroundColor:
                          colors.gold.withValues(alpha: 0.45),
                      disabledForegroundColor:
                          colors.primary.withValues(alpha: 0.55),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildField(DynamicFormField field, _DynamicFormsPalette colors) {
    switch (field.type) {
      case 'textarea':
        return _TextInput(
          field: field,
          controller: _fieldControllers[field.key]!,
          colors: colors,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
        );
      case 'email':
        return _TextInput(
          field: field,
          controller: _fieldControllers[field.key]!,
          colors: colors,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            final text = (value ?? '').trim();
            if (field.isRequired && text.isEmpty) {
              return 'Please answer: ${field.label}';
            }
            if (text.isNotEmpty && !text.contains('@')) {
              return 'Please enter a valid email address.';
            }
            return null;
          },
          onChanged: (_) => setState(() {}),
        );
      case 'phone':
        return _TextInput(
          field: field,
          controller: _fieldControllers[field.key]!,
          colors: colors,
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
        );
      case 'number':
        return _TextInput(
          field: field,
          controller: _fieldControllers[field.key]!,
          colors: colors,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            final text = (value ?? '').trim();
            if (field.isRequired && text.isEmpty) {
              return 'Please answer: ${field.label}';
            }
            if (text.isNotEmpty && double.tryParse(text) == null) {
              return 'Please enter a valid number.';
            }
            return null;
          },
          onChanged: (_) => setState(() {}),
        );
      case 'date':
        return _DateInput(
          field: field,
          controller: _fieldControllers[field.key]!,
          colors: colors,
          onChanged: () => setState(() {}),
        );
      case 'choice':
        return _DropdownInput(
          field: field,
          colors: colors,
          value: _answers[field.key] as String?,
          onChanged: (value) => setState(() => _answers[field.key] = value),
        );
      case 'multi_choice':
        return _MultiChoiceInput(
          field: field,
          colors: colors,
          values: ((_answers[field.key] as List?) ?? const [])
              .map((item) => '$item')
              .toSet(),
          onChanged: (values) =>
              setState(() => _answers[field.key] = values.toList()),
        );
      case 'checkbox':
      case 'consent':
        return _CheckboxInput(
          field: field,
          colors: colors,
          value: _answers[field.key] == true,
          onChanged: (value) => setState(() => _answers[field.key] = value),
        );
      case 'image_choice':
        return _ImageChoiceInput(
          field: field,
          colors: colors,
          value: _answers[field.key] as String?,
          onChanged: (value) => setState(() => _answers[field.key] = value),
        );
      case 'color_choice':
        return _ColorChoiceInput(
          field: field,
          colors: colors,
          value: _answers[field.key] as String?,
          onChanged: (value) => setState(() => _answers[field.key] = value),
        );
      case 'file':
        return _FileInput(
          field: field,
          colors: colors,
          file: _files[field.key],
          onPick: () async {
            final allowed = field.allowedFileExtensions;
            final result = await FilePicker.platform.pickFiles(
              type: allowed.isEmpty ? FileType.any : FileType.custom,
              allowedExtensions: allowed.isEmpty ? null : allowed,
            );
            final file = result?.files.first;
            if (file != null) {
              setState(() => _files[field.key] = file);
            }
            return file;
          },
          onClear: () => setState(() => _files.remove(field.key)),
        );
      case 'text':
      default:
        return _TextInput(
          field: field,
          controller: _fieldControllers[field.key]!,
          colors: colors,
          onChanged: (_) => setState(() {}),
        );
    }
  }
}

class _FormsHero extends StatelessWidget {
  const _FormsHero({required this.colors});

  final _DynamicFormsPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, const Color(0xFF175246)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          _IconBadge(
            icon: Icons.dynamic_form_rounded,
            colors: colors,
            gold: true,
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Forms',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Complete open church forms and requests.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicFormCard extends StatelessWidget {
  const _DynamicFormCard({
    required this.form,
    required this.colors,
    required this.onTap,
  });

  final DynamicForm form;
  final _DynamicFormsPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.line),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            _IconBadge(
              icon: form.requiresPayment
                  ? Icons.payments_outlined
                  : Icons.assignment_turned_in_outlined,
              colors: colors,
              gold: form.requiresPayment,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    form.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                    ),
                  ),
                  if (form.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      form.description.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChipLabel(
                        label: '${form.fields.length} fields',
                        colors: colors,
                      ),
                      if (form.requiresPayment)
                        _ChipLabel(
                          label:
                              '${form.payment.currency} ${form.payment.amount.toStringAsFixed(2)}',
                          colors: colors,
                          gold: true,
                        ),
                      if (form.requiresLogin)
                        _ChipLabel(label: 'Members only', colors: colors),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: colors.muted),
          ],
        ),
      ),
    );
  }
}

class _FormHeaderCard extends StatelessWidget {
  const _FormHeaderCard({required this.form, required this.colors});

  final DynamicForm form;
  final _DynamicFormsPalette colors;

  @override
  Widget build(BuildContext context) {
    return _QuestionCard(
      colors: colors,
      children: [
        Row(
          children: [
            _IconBadge(
              icon: form.requiresPayment
                  ? Icons.payments_outlined
                  : Icons.dynamic_form_rounded,
              colors: colors,
              gold: form.requiresPayment,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                form.title,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
            ),
          ],
        ),
        if (form.description.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            form.description.trim(),
            style: TextStyle(
              color: colors.muted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    super.key,
    required this.form,
    required this.colors,
    required this.selectedMethod,
    required this.onChanged,
  });

  final DynamicForm form;
  final _DynamicFormsPalette colors;
  final String selectedMethod;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _QuestionCard(
      colors: colors,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Payment',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${form.payment.currency} ${form.payment.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: colors.primary,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (form.payment.allowStripe)
          _PaymentTile(
            colors: colors,
            icon: Icons.credit_card_rounded,
            title: 'Pay with card',
            subtitle: 'Open secure Stripe Checkout.',
            selected: selectedMethod == 'stripe',
            onTap: () => onChanged('stripe'),
          ),
        if (form.payment.allowStripe && form.payment.allowWallet)
          const SizedBox(height: 10),
        if (form.payment.allowWallet)
          _PaymentTile(
            colors: colors,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Pay with wallet',
            subtitle: 'Requires sign-in and a fresh wallet unlock.',
            selected: selectedMethod == 'wallet',
            onTap: () => onChanged('wallet'),
          ),
        if (!form.payment.allowStripe && !form.payment.allowWallet)
          Text(
            'Payment is required, but no payment method is enabled yet.',
            style: TextStyle(color: colors.muted, fontWeight: FontWeight.w700),
          ),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final _DynamicFormsPalette colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? colors.gold.withValues(alpha: 0.16)
              : colors.softBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colors.gold : colors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: selected,
              onChanged: (_) => onTap(),
              activeColor: colors.gold,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    super.key,
    required this.colors,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
  });

  final _DynamicFormsPalette colors;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;

  @override
  Widget build(BuildContext context) {
    return _QuestionCard(
      colors: colors,
      children: [
        Text(
          'Your details',
          style: TextStyle(
            color: colors.primary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        _PlainTextInput(
          label: 'Full name',
          controller: nameController,
          colors: colors,
          required: true,
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 14),
        _PlainTextInput(
          label: 'Email address',
          controller: emailController,
          colors: colors,
          required: true,
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) return 'Please enter your email address.';
            if (!text.contains('@')) return 'Please enter a valid email.';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _PlainTextInput(
          label: 'Phone number',
          controller: phoneController,
          colors: colors,
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.colors,
    required this.children,
  });

  final _DynamicFormsPalette colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.line),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.field,
    required this.controller,
    required this.colors,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  final DynamicFormField field;
  final TextEditingController controller;
  final _DynamicFormsPalette colors;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _LabeledField(
      field: field,
      colors: colors,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        validator: validator ??
            (value) {
              if (field.isRequired && (value ?? '').trim().isEmpty) {
                return 'Please answer: ${field.label}';
              }
              return null;
            },
        decoration: _inputDecoration(
          colors,
          hint: field.placeholder.trim().isEmpty
              ? field.label
              : field.placeholder,
        ),
      ),
    );
  }
}

class _DateInput extends StatelessWidget {
  const _DateInput({
    required this.field,
    required this.controller,
    required this.colors,
    required this.onChanged,
  });

  final DynamicFormField field;
  final TextEditingController controller;
  final _DynamicFormsPalette colors;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _LabeledField(
      field: field,
      colors: colors,
      child: TextFormField(
        controller: controller,
        readOnly: true,
        validator: (value) {
          if (field.isRequired && (value ?? '').trim().isEmpty) {
            return 'Please choose: ${field.label}';
          }
          return null;
        },
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(1900),
            lastDate: DateTime(DateTime.now().year + 15),
            initialDate: DateTime.now(),
          );
          if (picked != null) {
            controller.text = picked.toIso8601String().split('T').first;
            onChanged();
          }
        },
        decoration: _inputDecoration(
          colors,
          hint: field.placeholder.trim().isEmpty
              ? field.label
              : field.placeholder,
          icon: Icons.calendar_month_outlined,
        ),
      ),
    );
  }
}

class _PlainTextInput extends StatelessWidget {
  const _PlainTextInput({
    required this.label,
    required this.controller,
    required this.colors,
    this.required = false,
    this.icon,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final _DynamicFormsPalette colors;
  final bool required;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator ??
          (value) {
            if (required && (value ?? '').trim().isEmpty) {
              return 'Please enter $label.';
            }
            return null;
          },
      decoration: _inputDecoration(colors, hint: label, icon: icon),
    );
  }
}

class _DropdownInput extends StatelessWidget {
  const _DropdownInput({
    required this.field,
    required this.colors,
    required this.value,
    required this.onChanged,
  });

  final DynamicFormField field;
  final _DynamicFormsPalette colors;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _LabeledField(
      field: field,
      colors: colors,
      child: DropdownButtonFormField<String>(
        value: value?.isEmpty == true ? null : value,
        isExpanded: true,
        validator: (selected) {
          if (field.isRequired && (selected ?? '').trim().isEmpty) {
            return 'Please choose: ${field.label}';
          }
          return null;
        },
        decoration: _inputDecoration(colors, hint: 'Please Select'),
        items: [
          const DropdownMenuItem<String>(
            value: '',
            child: Text('Please Select', overflow: TextOverflow.ellipsis),
          ),
          for (final option in field.options)
            DropdownMenuItem<String>(
              value: option.value,
              child: Text(option.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _MultiChoiceInput extends StatelessWidget {
  const _MultiChoiceInput({
    required this.field,
    required this.colors,
    required this.values,
    required this.onChanged,
  });

  final DynamicFormField field;
  final _DynamicFormsPalette colors;
  final Set<String> values;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormField<Set<String>>(
      initialValue: values,
      validator: (selected) {
        if (field.isRequired && (selected == null || selected.isEmpty)) {
          return 'Please choose at least one: ${field.label}';
        }
        return null;
      },
      builder: (state) => _LabeledField(
        field: field,
        colors: colors,
        errorText: state.errorText,
        child: Column(
          children: [
            for (final option in field.options)
              _OptionTile(
                colors: colors,
                label: option.label,
                selected: values.contains(option.value),
                leading: Checkbox(
                  value: values.contains(option.value),
                  activeColor: colors.gold,
                  onChanged: (selected) {
                    final next = Set<String>.from(values);
                    if (selected == true) {
                      next.add(option.value);
                    } else {
                      next.remove(option.value);
                    }
                    onChanged(next);
                    state.didChange(next);
                  },
                ),
                onTap: () {
                  final next = Set<String>.from(values);
                  if (next.contains(option.value)) {
                    next.remove(option.value);
                  } else {
                    next.add(option.value);
                  }
                  onChanged(next);
                  state.didChange(next);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckboxInput extends StatelessWidget {
  const _CheckboxInput({
    required this.field,
    required this.colors,
    required this.value,
    required this.onChanged,
  });

  final DynamicFormField field;
  final _DynamicFormsPalette colors;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      initialValue: value,
      validator: (selected) {
        if (field.isRequired && selected != true) {
          return 'Please confirm: ${field.label}';
        }
        return null;
      },
      builder: (state) => _LabeledField(
        field: field,
        colors: colors,
        errorText: state.errorText,
        child: _OptionTile(
          colors: colors,
          label: field.helpText.trim().isEmpty ? 'I agree' : field.helpText,
          selected: value,
          leading: Checkbox(
            value: value,
            activeColor: colors.gold,
            onChanged: (selected) {
              final next = selected == true;
              onChanged(next);
              state.didChange(next);
            },
          ),
          onTap: () {
            final next = !value;
            onChanged(next);
            state.didChange(next);
          },
        ),
      ),
    );
  }
}

class _ImageChoiceInput extends StatelessWidget {
  const _ImageChoiceInput({
    required this.field,
    required this.colors,
    required this.value,
    required this.onChanged,
  });

  final DynamicFormField field;
  final _DynamicFormsPalette colors;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: value,
      validator: (selected) {
        if (field.isRequired && (selected ?? '').trim().isEmpty) {
          return 'Please choose: ${field.label}';
        }
        return null;
      },
      builder: (state) => _LabeledField(
        field: field,
        colors: colors,
        errorText: state.errorText,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth > 430;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final option in field.options)
                  SizedBox(
                    width: twoColumns
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        onChanged(option.value);
                        state.didChange(option.value);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.softBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: value == option.value
                                ? colors.gold
                                : colors.line,
                            width: value == option.value ? 1.6 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (option.imageUrl.isNotEmpty)
                              AspectRatio(
                                aspectRatio: 16 / 10,
                                child: CachedNetworkImage(
                                  imageUrl: option.imageUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: colors.background,
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: colors.muted,
                                    ),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: option.value,
                                    groupValue: value,
                                    activeColor: colors.gold,
                                    onChanged: (selected) {
                                      if (selected == null) return;
                                      onChanged(selected);
                                      state.didChange(selected);
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

class _ColorChoiceInput extends StatelessWidget {
  const _ColorChoiceInput({
    required this.field,
    required this.colors,
    required this.value,
    required this.onChanged,
  });

  final DynamicFormField field;
  final _DynamicFormsPalette colors;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: value,
      validator: (selected) {
        if (field.isRequired && (selected ?? '').trim().isEmpty) {
          return 'Please choose: ${field.label}';
        }
        return null;
      },
      builder: (state) => _LabeledField(
        field: field,
        colors: colors,
        errorText: state.errorText,
        child: Column(
          children: [
            for (final option in field.options)
              _OptionTile(
                colors: colors,
                label: option.label,
                selected: value == option.value,
                leading: Radio<String>(
                  value: option.value,
                  groupValue: value,
                  activeColor: colors.gold,
                  onChanged: (selected) {
                    if (selected == null) return;
                    onChanged(selected);
                    state.didChange(selected);
                  },
                ),
                trailing: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _colorFromHex(option.colorHex),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.line),
                  ),
                ),
                onTap: () {
                  onChanged(option.value);
                  state.didChange(option.value);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FileInput extends StatelessWidget {
  const _FileInput({
    required this.field,
    required this.colors,
    required this.file,
    required this.onPick,
    required this.onClear,
  });

  final DynamicFormField field;
  final _DynamicFormsPalette colors;
  final PlatformFile? file;
  final Future<PlatformFile?> Function() onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return FormField<PlatformFile>(
      initialValue: file,
      validator: (_) {
        if (field.isRequired && file == null) {
          return 'Please upload: ${field.label}';
        }
        final selectedFile = file;
        if (selectedFile != null) {
          final allowed = field.allowedFileExtensions;
          final extension = _fileExtension(selectedFile);
          if (allowed.isNotEmpty && !allowed.contains(extension)) {
            return '${field.label} must be one of: ${allowed.join(', ')}.';
          }
          if (selectedFile.size > field.maxFileSizeKb * 1024) {
            return '${field.label} must not be larger than ${field.maxFileSizeKb}KB.';
          }
        }
        return null;
      },
      builder: (state) => _LabeledField(
        field: field,
        colors: colors,
        errorText: state.errorText,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.softBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.line),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_file_rounded, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      file?.name ?? 'Choose file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: file == null ? colors.muted : colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (file != null)
                    IconButton(
                      onPressed: () {
                        onClear();
                        state.didChange(null);
                      },
                      icon: const Icon(Icons.close_rounded),
                      color: colors.muted,
                    )
                  else
                    TextButton(
                      onPressed: () async {
                        final picked = await onPick();
                        state.didChange(picked);
                      },
                      child: const Text('Browse'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _fileRuleText(field),
              style: TextStyle(
                color: colors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fileExtension(PlatformFile file) {
  final explicit = (file.extension ?? '').toLowerCase().replaceFirst('.', '');
  if (explicit.isNotEmpty) return explicit;
  final name = file.name;
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

String _fileRuleText(DynamicFormField field) {
  final allowed = field.allowedFileExtensions;
  final typeText = allowed.isEmpty ? 'any file type' : allowed.join(', ');
  return 'Allowed: $typeText. Max: ${field.maxFileSizeKb}KB.';
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.colors,
    required this.label,
    required this.selected,
    required this.leading,
    required this.onTap,
    this.trailing,
  });

  final _DynamicFormsPalette colors;
  final String label;
  final bool selected;
  final Widget leading;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? colors.gold.withValues(alpha: 0.12)
                : colors.softBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? colors.gold : colors.line),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.field,
    required this.colors,
    required this.child,
    this.errorText,
  });

  final DynamicFormField field;
  final _DynamicFormsPalette colors;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: field.label,
            style: TextStyle(
              color: colors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
            children: [
              if (field.isRequired)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: colors.danger),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        child,
        if (field.helpText.trim().isNotEmpty &&
            field.type != 'checkbox' &&
            field.type != 'consent') ...[
          const SizedBox(height: 6),
          Text(
            field.helpText,
            style: TextStyle(
              color: colors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(
              color: colors.danger,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

InputDecoration _inputDecoration(
  _DynamicFormsPalette colors, {
  required String hint,
  IconData? icon,
}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, color: colors.muted),
    filled: true,
    fillColor: colors.softBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.gold, width: 1.6),
    ),
  );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.colors,
    required this.icon,
    required this.message,
  });

  final _DynamicFormsPalette colors;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.colors,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final _DynamicFormsPalette colors;
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 34),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.line),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.05),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.gold, size: 42),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.gold,
                    foregroundColor: colors.primary,
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.colors,
    this.gold = false,
  });

  final IconData icon;
  final _DynamicFormsPalette colors;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: gold
            ? colors.gold.withValues(alpha: 0.18)
            : const Color(0xFFE8F7F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: gold ? colors.gold : colors.green, size: 28),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({
    required this.label,
    required this.colors,
    this.gold = false,
  });

  final String label;
  final _DynamicFormsPalette colors;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: gold
            ? colors.gold.withValues(alpha: 0.16)
            : colors.green.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: gold ? colors.primary : colors.green,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DynamicFormsPalette {
  const _DynamicFormsPalette({
    required this.primary,
    required this.gold,
    required this.green,
    required this.muted,
    required this.background,
    required this.softBackground,
    required this.line,
    required this.danger,
  });

  final Color primary;
  final Color gold;
  final Color green;
  final Color muted;
  final Color background;
  final Color softBackground;
  final Color line;
  final Color danger;

  static _DynamicFormsPalette of(BuildContext context) {
    return const _DynamicFormsPalette(
      primary: Color(0xFF0C2230),
      gold: Color(0xFFFFB82E),
      green: Color(0xFF2C9B88),
      muted: Color(0xFF657680),
      background: Color(0xFFF2F8FB),
      softBackground: Color(0xFFF3F8FB),
      line: Color(0xFFDDE9EE),
      danger: Color(0xFFB42318),
    );
  }
}

bool _isBlank(dynamic value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  if (value is Iterable) return value.isEmpty;
  return false;
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = '${value ?? ''}'.toLowerCase().trim();
  return text == '1' || text == 'true' || text == 'yes' || text == 'on';
}

Color _colorFromHex(String value) {
  final hex = value.startsWith('#') ? value.substring(1) : value;
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return Colors.white;
  return Color(int.parse('ff$hex', radix: 16));
}
