import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../auth/LoginScreen.dart';
import '../../models/Userdata.dart';
import '../../prayers/voice_recording_dialog.dart';
import '../../providers/AppStateManager.dart';
import '../../socials/UpdateUserProfile.dart';
import '../../utils/Alerts.dart';
import 'counseling_api.dart';
import 'counseling_models.dart';

const _primary = Color(0xFF0C2230);
const _gold = Color(0xFFFFC857);
const _teal = Color(0xFF2C9B88);

class CounselingScreen extends StatefulWidget {
  const CounselingScreen({super.key});

  static const routeName = '/counseling';

  @override
  State<CounselingScreen> createState() => _CounselingScreenState();
}

class _CounselingScreenState extends State<CounselingScreen> {
  final _api = CounselingApi();

  List<CounselingCase> _cases = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Userdata? get _user =>
      Provider.of<AppStateManager>(context, listen: false).userdata;

  Future<void> _load({bool reset = true}) async {
    final user = _user;
    if (user == null || (user.apiToken ?? '').trim().isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
          _cases = [];
        });
      }
      return;
    }

    final nextPage = reset ? 1 : _page + 1;
    if (!reset && nextPage > _lastPage) return;

    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await _api.fetchCases(user, page: nextPage);
      if (!mounted) return;
      setState(() {
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _cases = reset ? result.cases : [..._cases, ...result.cases];
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error, 'Unable to load counseling requests.');
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _openCreate() async {
    final user = _user;
    if (user == null || (user.apiToken ?? '').trim().isEmpty) {
      await _showSignInPrompt();
      return;
    }
    if (!user.isVerified) {
      await _showVerifyPrompt();
      return;
    }

    final created = await Navigator.push<CounselingCase>(
      context,
      MaterialPageRoute(
        builder: (_) => CounselingCreateScreen(api: _api),
      ),
    );
    if (created != null && mounted) {
      setState(() => _cases.insert(0, created));
      await _load(reset: true);
    }
  }

  Future<void> _openCase(CounselingCase item) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CounselingCaseDetailScreen(api: _api, initial: item),
      ),
    );
    if (changed == true && mounted) await _load(reset: true);
  }

  Future<void> _showSignInPrompt() {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Private counseling'),
        content: const Text(
          'Sign in to submit a private counseling request and receive replies from the pastoral care team.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
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

  Future<void> _showVerifyPrompt() {
    return showDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Verify your account'),
        content: const Text(
          'Please verify your account before requesting private counseling.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Later'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Update profile'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, UpdateUserProfile.routeName);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppStateManager>(context).userdata;
    final colors = _CounselingPalette.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Private Counseling')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: _gold,
        foregroundColor: _primary,
        icon: const Icon(Icons.lock_rounded),
        label: const Text('New request'),
      ),
      body: RefreshIndicator(
        color: _gold,
        onRefresh: () => _load(reset: true),
        child: _body(user, colors),
      ),
    );
  }

  Widget _body(Userdata? user, _CounselingPalette colors) {
    if (user == null || (user.apiToken ?? '').trim().isEmpty) {
      return _StatePanel(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in for private counseling',
        message:
            'Your request and replies stay private between you and the pastoral care team.',
        actionLabel: 'Sign in',
        onAction: () => Navigator.pushNamed(context, LoginScreen.routeName),
      );
    }

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _StatePanel(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load counseling',
        message: _error!,
        actionLabel: 'Retry',
        onAction: () => _load(reset: true),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (!_loadingMore &&
            _page < _lastPage &&
            metrics.pixels >= metrics.maxScrollExtent - 140) {
          _load(reset: false);
        }
        return false;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
        children: [
          _HeroPanel(total: _cases.length, colors: colors),
          const SizedBox(height: 16),
          if (_cases.isEmpty)
            _EmptyRequestsCard(onCreate: _openCreate)
          else ...[
            ..._cases.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _CounselingCaseCard(
                  item: item,
                  onTap: () => _openCase(item),
                ),
              ),
            ),
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CupertinoActivityIndicator()),
              ),
          ],
        ],
      ),
    );
  }
}

class CounselingCreateScreen extends StatefulWidget {
  const CounselingCreateScreen({super.key, required this.api});

  final CounselingApi api;

  @override
  State<CounselingCreateScreen> createState() => _CounselingCreateScreenState();
}

class _CounselingCreateScreenState extends State<CounselingCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _category = 'General guidance';
  String _priority = 'normal';
  String? _audioPath;
  int _audioSeconds = 0;
  String? _attachmentPath;
  String? _attachmentName;
  String _attachmentType = 'file';
  bool _submitting = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const VoiceRecordingDialog(
        maxDuration: 300,
        title: 'Record Counseling Note',
      ),
    );
    if (result == null) return;
    setState(() {
      _audioPath = result['path'] as String?;
      _audioSeconds = result['duration'] as int? ?? 0;
      _attachmentPath = null;
      _attachmentName = null;
      _attachmentType = 'file';
    });
  }

  Future<void> _pickAttachment({required bool imageOnly}) async {
    final result = await FilePicker.platform.pickFiles(
      type: imageOnly ? FileType.image : FileType.any,
      withData: false,
    );
    final file = result?.files.single;
    final path = file?.path;
    if (path == null || path.trim().isEmpty) return;

    setState(() {
      _attachmentPath = path;
      _attachmentName = file?.name ?? path.split(RegExp(r'[\\/]')).last;
      _attachmentType = imageOnly ? 'image' : 'file';
      _audioPath = null;
      _audioSeconds = 0;
    });
  }

  Future<void> _submit() async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final body = _body.text.trim();
    if (body.isEmpty &&
        (_audioPath ?? '').isEmpty &&
        (_attachmentPath ?? '').isEmpty) {
      await Alerts.show(context, 'Message required',
          'Please write a message, attach a voice note, image, or file.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final created = await widget.api.createCase(
        user: user,
        subject: _subject.text.trim(),
        category: _category,
        priority: _priority,
        body: body,
        audioPath: _audioPath,
        audioDurationSeconds: _audioSeconds,
        attachmentPath: _attachmentPath,
        attachmentType: _attachmentType,
      );
      if (!mounted) return;
      await Alerts.show(
        context,
        'Request submitted',
        'Your private counseling request has been sent. The pastoral care team can now follow up securely.',
      );
      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (error) {
      if (!mounted) return;
      await Alerts.show(
        context,
        'Unable to submit',
        _friendlyError(error, 'Please try again shortly.'),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _CounselingPalette.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('New Counseling Request'),
        actions: [
          IconButton(
            onPressed: _submitting ? null : _submit,
            tooltip: 'Submit request',
            icon: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _PrivacyHero(colors: colors),
            const SizedBox(height: 18),
            _FieldCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _subject,
                    textInputAction: TextInputAction.next,
                    maxLength: 160,
                    decoration: _inputDecoration(
                      label: 'Subject',
                      icon: Icons.title_rounded,
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      return text.isEmpty ? 'Add a short subject.' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: _inputDecoration(
                      label: 'Area of support',
                      icon: Icons.category_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'General guidance',
                          child: Text('General guidance')),
                      DropdownMenuItem(
                          value: 'Family and relationships',
                          child: Text('Family and relationships')),
                      DropdownMenuItem(
                          value: 'Prayer and spiritual care',
                          child: Text('Prayer and spiritual care')),
                      DropdownMenuItem(
                          value: 'Grief and emotional support',
                          child: Text('Grief and emotional support')),
                      DropdownMenuItem(
                          value: 'Other private matter',
                          child: Text('Other private matter')),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) => setState(
                              () => _category = value ?? _category,
                            ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: _inputDecoration(
                      label: 'Priority',
                      icon: Icons.flag_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) => setState(
                              () => _priority = value ?? _priority,
                            ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _body,
                    minLines: 6,
                    maxLines: 10,
                    maxLength: 5000,
                    decoration: _inputDecoration(
                      label: 'Tell us what is going on',
                      icon: Icons.lock_outline_rounded,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AudioAttachRow(
                    audioPath: _audioPath,
                    audioSeconds: _audioSeconds,
                    onRecord: _record,
                    onRemove: () => setState(() {
                      _audioPath = null;
                      _audioSeconds = 0;
                    }),
                  ),
                  const SizedBox(height: 10),
                  _FileAttachRow(
                    attachmentName: _attachmentName,
                    onPickImage: () => _pickAttachment(imageOnly: true),
                    onPickFile: () => _pickAttachment(imageOnly: false),
                    onRemove: () => setState(() {
                      _attachmentPath = null;
                      _attachmentName = null;
                      _attachmentType = 'file';
                    }),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      style: _primaryButtonStyle(),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_submitting
                          ? 'Submitting...'
                          : 'Send private request'),
                    ),
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

class CounselingCaseDetailScreen extends StatefulWidget {
  const CounselingCaseDetailScreen({
    super.key,
    required this.api,
    required this.initial,
  });

  final CounselingApi api;
  final CounselingCase initial;

  @override
  State<CounselingCaseDetailScreen> createState() =>
      _CounselingCaseDetailScreenState();
}

class _CounselingCaseDetailScreenState
    extends State<CounselingCaseDetailScreen> {
  final _message = TextEditingController();
  CounselingCase? _case;
  bool _loading = true;
  bool _sending = false;
  bool _closing = false;
  String? _error;
  String? _audioPath;
  int _audioSeconds = 0;
  String? _attachmentPath;
  String? _attachmentName;
  String _attachmentType = 'file';
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _case = widget.initial;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Userdata? get _user =>
      Provider.of<AppStateManager>(context, listen: false).userdata;

  Future<void> _load() async {
    final user = _user;
    if (user == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await widget.api.fetchCase(user, widget.initial.id);
      if (!mounted) return;
      setState(() {
        _case = item;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error, 'Unable to load this request.');
        _loading = false;
      });
    }
  }

  Future<void> _record() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const VoiceRecordingDialog(
        maxDuration: 300,
        title: 'Record Reply',
      ),
    );
    if (result == null) return;
    setState(() {
      _audioPath = result['path'] as String?;
      _audioSeconds = result['duration'] as int? ?? 0;
    });
  }

  Future<void> _pickAttachment({required bool imageOnly}) async {
    final result = await FilePicker.platform.pickFiles(
      type: imageOnly ? FileType.image : FileType.any,
      withData: false,
    );
    final file = result?.files.single;
    final path = file?.path;
    if (path == null || path.trim().isEmpty) return;

    setState(() {
      _attachmentPath = path;
      _attachmentName = file?.name ?? path.split(RegExp(r'[\\/]')).last;
      _attachmentType = imageOnly ? 'image' : 'file';
      _audioPath = null;
      _audioSeconds = 0;
    });
  }

  Future<void> _send() async {
    final user = _user;
    final item = _case;
    if (user == null || item == null || item.isClosed || _sending) return;

    final text = _message.text.trim();
    if (text.isEmpty &&
        (_audioPath ?? '').isEmpty &&
        (_attachmentPath ?? '').isEmpty) {
      _showSnack('Write a message, attach a voice note, or add a file.');
      return;
    }

    setState(() => _sending = true);
    try {
      final sent = await widget.api.sendMessage(
        user: user,
        caseId: item.id,
        body: text,
        audioPath: _audioPath,
        audioDurationSeconds: _audioSeconds,
        attachmentPath: _attachmentPath,
        attachmentType: _attachmentType,
      );
      if (!mounted) return;
      setState(() {
        final messages = [...item.messages, sent];
        _case = CounselingCase(
          id: item.id,
          reference: item.reference,
          status: 'awaiting_counselor',
          priority: item.priority,
          category: item.category,
          subject: item.subject,
          requester: item.requester,
          countryCode: item.countryCode,
          locale: item.locale,
          timezone: item.timezone,
          assignedProvider: item.assignedProvider,
          lastMessageAt: sent.createdAt ?? DateTime.now(),
          closedAt: item.closedAt,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
          messages: messages,
        );
        _message.clear();
        _audioPath = null;
        _audioSeconds = 0;
        _attachmentPath = null;
        _attachmentName = null;
        _attachmentType = 'file';
        _changed = true;
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error, 'Unable to send message right now.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _closeCase() async {
    final user = _user;
    final item = _case;
    if (user == null || item == null || item.isClosed || _closing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Close this request?'),
        content: const Text(
          'You can close a request when this matter no longer needs follow-up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _closing = true);
    try {
      final closed = await widget.api.closeCase(
        user: user,
        caseId: item.id,
        reason: 'Closed from mobile app',
      );
      if (!mounted) return;
      setState(() {
        _case = closed;
        _changed = true;
      });
      _showSnack('Request closed.');
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error, 'Unable to close this request.'));
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = _CounselingPalette.of(context);
    final item = _case ?? widget.initial;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(item.reference.isEmpty ? 'Counseling' : item.reference),
          actions: [
            if (!item.isClosed)
              IconButton(
                onPressed: _closing ? null : _closeCase,
                tooltip: 'Close request',
                icon: _closing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _detailBody(item, colors)),
            _MessageComposer(
              enabled: !item.isClosed && !_sending,
              controller: _message,
              audioPath: _audioPath,
              audioSeconds: _audioSeconds,
              attachmentName: _attachmentName,
              sending: _sending,
              onRecord: _record,
              onPickImage: () => _pickAttachment(imageOnly: true),
              onPickFile: () => _pickAttachment(imageOnly: false),
              onRemoveAudio: () => setState(() {
                _audioPath = null;
                _audioSeconds = 0;
              }),
              onRemoveAttachment: () => setState(() {
                _attachmentPath = null;
                _attachmentName = null;
                _attachmentType = 'file';
              }),
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailBody(CounselingCase item, _CounselingPalette colors) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _StatePanel(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load request',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    final messages = item.messages;
    return RefreshIndicator(
      onRefresh: _load,
      color: _gold,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _CaseSummaryPanel(item: item),
          const SizedBox(height: 16),
          if (messages.isEmpty)
            _SoftNotice(
              icon: Icons.forum_outlined,
              title: 'No messages yet',
              message: 'Your conversation will appear here once it starts.',
            )
          else
            ...messages.map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CounselingMessageBubble(
                  message: message,
                  caseId: item.id,
                  user: _user,
                  api: widget.api,
                  onReacted: _replaceMessage,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _replaceMessage(CounselingMessage next) {
    final item = _case;
    if (item == null) return;
    setState(() {
      _case = CounselingCase(
        id: item.id,
        reference: item.reference,
        status: item.status,
        priority: item.priority,
        category: item.category,
        subject: item.subject,
        requester: item.requester,
        countryCode: item.countryCode,
        locale: item.locale,
        timezone: item.timezone,
        assignedProvider: item.assignedProvider,
        lastMessageAt: item.lastMessageAt,
        closedAt: item.closedAt,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        messages: item.messages
            .map((message) => message.id == next.id ? next : message)
            .toList(),
      );
    });
  }
}

class CounselingMessageBubble extends StatelessWidget {
  const CounselingMessageBubble({
    super.key,
    required this.message,
    required this.caseId,
    required this.user,
    required this.api,
    required this.onReacted,
  });

  final CounselingMessage message;
  final int caseId;
  final Userdata? user;
  final CounselingApi api;
  final ValueChanged<CounselingMessage> onReacted;

  @override
  Widget build(BuildContext context) {
    final colors = _CounselingPalette.of(context);
    final mine = message.isFromRequester;
    final background = mine ? _primary : colors.card;
    final foreground = mine ? Colors.white : colors.text;
    final muted = mine ? Colors.white70 : colors.muted;

    final senderName = message.sender?.name.trim().isNotEmpty == true
        ? message.sender!.name.trim()
        : (mine ? 'You' : 'Counselor');
    final avatarUrl = message.sender?.avatar ?? '';

    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!mine) _ChatAvatar(name: senderName, avatarUrl: avatarUrl),
        if (!mine) const SizedBox(width: 8),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(mine ? 22 : 6),
                  bottomRight: Radius.circular(mine ? 6 : 22),
                ),
                border: mine ? null : Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: colors.isDark ? 0.22 : 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if ((message.body ?? '').trim().isNotEmpty)
                    Text(
                      message.body!.trim(),
                      style: TextStyle(color: foreground, height: 1.42),
                    ),
                  if (message.isAudio &&
                      (message.audioUrl ?? '').isNotEmpty) ...[
                    if ((message.body ?? '').trim().isNotEmpty)
                      const SizedBox(height: 10),
                    _CounselingAudioPlayer(
                      url: api.absoluteAudioUrl(message.audioUrl),
                      user: user,
                      inverse: mine,
                    ),
                  ],
                  if (message.attachment != null) ...[
                    if ((message.body ?? '').trim().isNotEmpty ||
                        message.isAudio)
                      const SizedBox(height: 10),
                    _AttachmentPreview(
                      message: message,
                      api: api,
                      inverse: mine,
                    ),
                  ],
                  if (message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: message.reactions
                          .map((reaction) => _ReactionChip(
                                label: '${reaction.emoji} ${reaction.count}',
                                inverse: mine,
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDateTime(message.createdAt),
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      for (final emoji in const ['🙏', '❤️'])
                        InkWell(
                          borderRadius: BorderRadius.circular(99),
                          onTap: user == null
                              ? null
                              : () async {
                                  try {
                                    final updated = await api.reactToMessage(
                                      user: user!,
                                      caseId: caseId,
                                      messageId: message.id,
                                      reaction: emoji,
                                    );
                                    onReacted(updated);
                                  } catch (_) {}
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(emoji),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (mine) const SizedBox(width: 8),
        if (mine) _ChatAvatar(name: senderName, avatarUrl: avatarUrl),
      ],
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.name, required this.avatarUrl});

  final String name;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: 17,
      backgroundColor: _gold.withValues(alpha: 0.22),
      backgroundImage:
          avatarUrl.trim().isEmpty ? null : NetworkImage(avatarUrl),
      child: avatarUrl.trim().isEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.label, required this.inverse});

  final String label;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: inverse
            ? Colors.white.withValues(alpha: 0.13)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: inverse ? Colors.white : _primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.message,
    required this.api,
    required this.inverse,
  });

  final CounselingMessage message;
  final CounselingApi api;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final attachment = message.attachment;
    if (attachment == null) return const SizedBox.shrink();
    final url = api.absoluteMediaUrl(attachment.url ?? message.mediaUrl);
    final name = attachment.name ?? 'Attachment';

    if (message.isImage && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          url,
          headers: userHeaders(context),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _FileAttachmentTile(
            name: name,
            inverse: inverse,
            url: url,
          ),
        ),
      );
    }

    return _FileAttachmentTile(name: name, inverse: inverse, url: url);
  }

  Map<String, String> userHeaders(BuildContext context) {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    return user == null ? const {} : api.authHeaders(user);
  }
}

class _FileAttachmentTile extends StatelessWidget {
  const _FileAttachmentTile({
    required this.name,
    required this.inverse,
    required this.url,
  });

  final String name;
  final bool inverse;
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: url.isEmpty
          ? null
          : () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: inverse
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file_rounded,
                color: inverse ? Colors.white : _primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: inverse ? Colors.white : _primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounselingAudioPlayer extends StatefulWidget {
  const _CounselingAudioPlayer({
    required this.url,
    required this.user,
    required this.inverse,
  });

  final String url;
  final Userdata? user;
  final bool inverse;

  @override
  State<_CounselingAudioPlayer> createState() => _CounselingAudioPlayerState();
}

class _CounselingAudioPlayerState extends State<_CounselingAudioPlayer> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _playing = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CounselingAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.pause();
      _controller?.dispose();
      _controller = null;
      _playing = false;
      _loading = false;
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _controller?.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }

    setState(() => _loading = true);
    try {
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      final path = await _downloadProtectedAudio(widget.url);
      final controller = VideoPlayerController.file(File(path));
      _controller = controller;
      await controller.initialize();

      controller.addListener(() {
        if (!mounted) return;
        final completed = controller.value.duration > Duration.zero &&
            controller.value.position >= controller.value.duration;

        setState(() {
          _playing = controller.value.isPlaying && !completed;
          _loading = controller.value.isBuffering;
        });

        if (completed && controller.value.isPlaying) {
          controller.pause();
          controller.seekTo(Duration.zero);
          setState(() => _playing = false);
        }
      });

      await controller.play();
      if (mounted) {
        setState(() {
          _playing = true;
          _loading = false;
        });
      }
    } catch (error) {
      debugPrint('Counseling audio playback failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to play this voice note.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _downloadProtectedAudio(String url) async {
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/counseling_audio',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    await _trimAudioCache(directory);

    final cached = await _findCachedAudio(directory, url);
    if (cached != null) return cached.path;

    final token = (widget.user?.apiToken ?? '').trim();
    final response = await Dio().get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Accept': 'audio/*',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ),
    );

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Downloaded counseling audio file is empty.');
    }

    final extension = _audioExtensionFromHeaders(response.headers) ??
        _audioExtensionFromUrl(url) ??
        'wav';
    final file = File(
      '${directory.path}/counseling_audio_${url.hashCode.abs()}.$extension',
    );

    final projectedSize = await _directorySize(directory) + bytes.length;
    if (projectedSize > _maxCounselingAudioCacheBytes) {
      await _trimAudioCache(directory, requiredFreeBytes: bytes.length);
    }

    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static const int _maxCounselingAudioCacheBytes = 50 * 1024 * 1024;

  Future<File?> _findCachedAudio(Directory directory, String url) async {
    final prefix = 'counseling_audio_${url.hashCode.abs()}.';
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.uri.pathSegments.last.startsWith(prefix)) {
        if (await entity.length() > 0) return entity;
      }
    }
    return null;
  }

  Future<void> _trimAudioCache(
    Directory directory, {
    int requiredFreeBytes = 0,
  }) async {
    final fileStats = <_CachedCounselingAudioFile>[];
    var total = 0;

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        total += stat.size;
        fileStats.add(
          _CachedCounselingAudioFile(entity, stat.size, stat.changed),
        );
      } catch (_) {}
    }

    final target = _maxCounselingAudioCacheBytes - requiredFreeBytes;
    if (total <= target) return;

    fileStats.sort((a, b) => a.changed.compareTo(b.changed));
    for (final item in fileStats) {
      if (total <= target) break;
      try {
        await item.file.delete();
        total -= item.size;
      } catch (_) {}
    }
  }

  Future<int> _directorySize(Directory directory) async {
    var total = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  String? _audioExtensionFromHeaders(Headers headers) {
    final disposition = headers.value('content-disposition') ?? '';
    final filenameMatch = RegExp(r'filename="?([^";]+)"?')
        .firstMatch(disposition.replaceAll("'", ''));
    if (filenameMatch != null) {
      final filename = filenameMatch.group(1) ?? '';
      final dot = filename.lastIndexOf('.');
      if (dot >= 0 && dot < filename.length - 1) {
        return filename.substring(dot + 1).toLowerCase();
      }
    }

    final contentType = headers.value('content-type')?.toLowerCase() ?? '';
    if (contentType.contains('mpeg')) return 'mp3';
    if (contentType.contains('mp4') || contentType.contains('aac')) {
      return 'm4a';
    }
    if (contentType.contains('ogg')) return 'ogg';
    if (contentType.contains('webm')) return 'webm';
    if (contentType.contains('wav') || contentType.contains('wave')) {
      return 'wav';
    }
    return null;
  }

  String? _audioExtensionFromUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    for (final extension in ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'webm']) {
      if (path.endsWith('.$extension')) return extension;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.inverse ? _gold : _primary;
    return Material(
      color: color.withValues(alpha: widget.inverse ? 0.16 : 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _loading ? null : _toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(
                      _playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: color,
                    ),
              const SizedBox(width: 8),
              Text(
                _loading
                    ? 'Preparing...'
                    : _playing
                        ? 'Pause voice note'
                        : 'Play voice note',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CachedCounselingAudioFile {
  const _CachedCounselingAudioFile(this.file, this.size, this.changed);

  final File file;
  final int size;
  final DateTime changed;
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.enabled,
    required this.controller,
    required this.audioPath,
    required this.audioSeconds,
    required this.attachmentName,
    required this.sending,
    required this.onRecord,
    required this.onPickImage,
    required this.onPickFile,
    required this.onRemoveAudio,
    required this.onRemoveAttachment,
    required this.onSend,
  });

  final bool enabled;
  final TextEditingController controller;
  final String? audioPath;
  final int audioSeconds;
  final String? attachmentName;
  final bool sending;
  final VoidCallback onRecord;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;
  final VoidCallback onRemoveAudio;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = _CounselingPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.28 : 0.1),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (audioPath != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AttachedAudioChip(
                    seconds: audioSeconds,
                    onRemove: enabled ? onRemoveAudio : null,
                  ),
                ),
              if (attachmentName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AttachedFileChip(
                    name: attachmentName!,
                    onRemove: enabled ? onRemoveAttachment : null,
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: enabled ? onRecord : null,
                    icon: const Icon(Icons.mic_rounded),
                    color: _primary,
                    tooltip: 'Record voice note',
                  ),
                  IconButton(
                    onPressed: enabled ? onPickImage : null,
                    icon: const Icon(Icons.image_outlined),
                    color: _teal,
                    tooltip: 'Attach image',
                  ),
                  IconButton(
                    onPressed: enabled ? onPickFile : null,
                    icon: const Icon(Icons.attach_file_rounded),
                    color: _primary,
                    tooltip: 'Attach file',
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: enabled
                            ? 'Write a private reply...'
                            : 'This request is closed',
                        filled: true,
                        fillColor: colors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    heroTag: 'send-counseling-message',
                    onPressed: enabled ? onSend : null,
                    backgroundColor: _gold,
                    foregroundColor: _primary,
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioAttachRow extends StatelessWidget {
  const _AudioAttachRow({
    required this.audioPath,
    required this.audioSeconds,
    required this.onRecord,
    required this.onRemove,
  });

  final String? audioPath;
  final int audioSeconds;
  final VoidCallback onRecord;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: onRecord,
          style: ElevatedButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: _primary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.mic_rounded),
          label: Text(audioPath == null
              ? 'Record voice note'
              : 'Voice note (${_formatDuration(audioSeconds)})'),
        ),
        if (audioPath != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Remove voice note',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ],
    );
  }
}

class _FileAttachRow extends StatelessWidget {
  const _FileAttachRow({
    required this.attachmentName,
    required this.onPickImage,
    required this.onPickFile,
    required this.onRemove,
  });

  final String? attachmentName;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachmentName != null) {
      return _AttachedFileChip(name: attachmentName!, onRemove: onRemove);
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onPickImage,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Attach image'),
        ),
        OutlinedButton.icon(
          onPressed: onPickFile,
          icon: const Icon(Icons.attach_file_rounded),
          label: const Text('Attach file'),
        ),
      ],
    );
  }
}

class _AttachedAudioChip extends StatelessWidget {
  const _AttachedAudioChip({required this.seconds, required this.onRemove});

  final int seconds;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq_rounded, color: _primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Voice note attached • ${_formatDuration(seconds)}',
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _AttachedFileChip extends StatelessWidget {
  const _AttachedFileChip({required this.name, required this.onRemove});

  final String name;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _teal.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded, color: _teal, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove attachment',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.total, required this.colors});

  final int total;
  final _CounselingPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C2230), Color(0xFF153F50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.28 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _HeroPainter())),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.lock_rounded, color: _gold, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Private pastoral care',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      total == 0
                          ? 'Start a confidential request by text or voice note.'
                          : '$total private request${total == 1 ? '' : 's'} in your counseling space.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrivacyHero extends StatelessWidget {
  const _PrivacyHero({required this.colors});

  final _CounselingPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C2230), Color(0xFF123D35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: _gold, size: 34),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Share only what you are comfortable sharing. Your request is private and visible only to approved pastoral care users.',
              style: TextStyle(
                color: Colors.white,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounselingCaseCard extends StatelessWidget {
  const _CounselingCaseCard({required this.item, required this.onTap});

  final CounselingCase item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _CounselingPalette.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: colors.isDark ? 0.22 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                  child: CustomPaint(painter: _CardPainter())),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusBadge(status: item.status),
                      const Spacer(),
                      Text(
                        item.reference,
                        style: TextStyle(
                          color: colors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    item.displaySubject,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 19,
                      height: 1.14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _caseSubtitle(item),
                    style: TextStyle(color: colors.muted, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          color: colors.muted, size: 17),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _formatDateTime(item.lastMessageAt ?? item.createdAt),
                          style: TextStyle(
                            color: colors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, color: _gold),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseSummaryPanel extends StatelessWidget {
  const _CaseSummaryPanel({required this.item});

  final CounselingCase item;

  @override
  Widget build(BuildContext context) {
    final colors = _CounselingPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(status: item.status),
              const Spacer(),
              if (item.priority.isNotEmpty)
                _TinyPill(
                  label: item.priority.toUpperCase(),
                  color: item.priority == 'high'
                      ? Colors.redAccent
                      : item.priority == 'low'
                          ? _teal
                          : _gold,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.displaySubject,
            style: TextStyle(
              color: colors.text,
              fontSize: 22,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _caseSubtitle(item),
            style: TextStyle(color: colors.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _EmptyRequestsCard extends StatelessWidget {
  const _EmptyRequestsCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.lock_outline_rounded,
      title: 'No private requests yet',
      message:
          'If you need pastoral support, you can submit a private text or voice note.',
      actionLabel: 'Create request',
      onAction: onCreate,
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = _CounselingPalette.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 86),
        Icon(icon, size: 68, color: _gold),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.text,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.muted, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 18),
        Center(
          child: ElevatedButton(
            onPressed: onAction,
            style: _primaryButtonStyle(compact: true),
            child: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

class _SoftNotice extends StatelessWidget {
  const _SoftNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = _CounselingPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _gold, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: colors.muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = _statusLabel(status);
    final color = _statusColor(status);
    return _TinyPill(label: label, color: color);
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = _CounselingPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _HeroPainter extends CustomPainter {
  const _HeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = _gold.withValues(alpha: 0.14);
    canvas.drawCircle(Offset(size.width * 0.9, 0), 94, paint);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.25), 52, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardPainter extends CustomPainter {
  const _CardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _gold.withValues(alpha: 0.08);
    canvas.drawCircle(Offset(size.width * 0.94, size.height * 0.05), 72, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CounselingPalette {
  const _CounselingPalette({
    required this.isDark,
    required this.background,
    required this.card,
    required this.text,
    required this.muted,
    required this.border,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color text;
  final Color muted;
  final Color border;

  static _CounselingPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _CounselingPalette(
      isDark: isDark,
      background: isDark ? const Color(0xFF071720) : const Color(0xFFF4F8FA),
      card: isDark ? const Color(0xFF102532) : Colors.white,
      text: isDark ? Colors.white : _primary,
      muted: isDark ? Colors.white60 : const Color(0xFF60707A),
      border: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : const Color(0xFFE8EEF2),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  required IconData icon,
  bool alignLabelWithHint = false,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    alignLabelWithHint: alignLabelWithHint,
    filled: true,
    fillColor: const Color(0xFFF4F8FA),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _gold, width: 1.5),
    ),
  );
}

ButtonStyle _primaryButtonStyle({bool compact = false}) {
  return ElevatedButton.styleFrom(
    backgroundColor: _gold,
    foregroundColor: _primary,
    disabledBackgroundColor: _gold.withValues(alpha: 0.58),
    disabledForegroundColor: _primary.withValues(alpha: 0.68),
    elevation: 0,
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 18 : 20,
      vertical: compact ? 12 : 16,
    ),
    textStyle: TextStyle(
      fontSize: compact ? 14 : 16,
      fontWeight: FontWeight.w900,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  );
}

String _friendlyError(Object error, String fallback) {
  if (error is CounselingApiException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  final message = error.toString().replaceFirst('Exception: ', '').trim();
  if (message.isNotEmpty &&
      !message.contains('DioException') &&
      !message.contains('Instance of')) {
    return message;
  }
  return fallback;
}

String _statusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'submitted':
      return 'SUBMITTED';
    case 'triage':
      return 'TRIAGE';
    case 'awaiting_assignment':
      return 'AWAITING ASSIGNMENT';
    case 'assigned':
      return 'ASSIGNED';
    case 'active':
      return 'ACTIVE';
    case 'awaiting_requester':
      return 'AWAITING YOU';
    case 'awaiting_counselor':
      return 'AWAITING COUNSELOR';
    case 'follow_up':
      return 'FOLLOW UP';
    case 'closed':
      return 'CLOSED';
    default:
      return status.replaceAll('_', ' ').toUpperCase();
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'closed':
      return const Color(0xFF7C8790);
    case 'awaiting_requester':
    case 'awaiting_counselor':
      return const Color(0xFFE1A63B);
    case 'active':
    case 'assigned':
      return _teal;
    case 'triage':
    case 'submitted':
      return _primary;
    default:
      return _gold;
  }
}

String _caseSubtitle(CounselingCase item) {
  final parts = <String>[];
  if ((item.category ?? '').trim().isNotEmpty) parts.add(item.category!.trim());
  if (item.assignedProvider != null) {
    parts.add('With ${item.assignedProvider!.displayName}');
  } else if (!item.isClosed) {
    parts.add('Waiting for pastoral care assignment');
  }
  return parts.join(' • ');
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'Date unavailable';
  final local = value.toLocal();
  final now = DateTime.now();
  final date = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (date == today) return 'Today, $time';
  if (date == today.subtract(const Duration(days: 1)))
    return 'Yesterday, $time';
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} $time';
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
}
