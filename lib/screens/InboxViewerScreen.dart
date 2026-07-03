import '../utils/TimUtil.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../models/Inbox.dart';
import 'NoitemScreen.dart';
import '../i18n/strings.g.dart';
import '../utils/inbox_read_store.dart';
import '../providers/events.dart';
import '../providers/AppStateManager.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

class InboxViewerScreen extends StatefulWidget {
  static const routeName = "/inboxviewer";
  const InboxViewerScreen({Key? key, this.inbox}) : super(key: key);
  final Inbox? inbox;

  @override
  _InboxViewerScreenState createState() => _InboxViewerScreenState();
}

class _InboxViewerScreenState extends State<InboxViewerScreen> {
  bool isLoading = false;
  bool isError = false;
  bool isDeleting = false;

  @override
  void initState() {
    /*Future.delayed(const Duration(milliseconds: 0), () {
      loadItems();
    });*/
    InboxReadStore.markRead(widget.inbox?.id);
    eventBus.fire(const InboxNotificationsChanged());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.inbox),
        actions: [
          if (widget.inbox != null)
            IconButton(
              tooltip: 'Delete notification',
              onPressed: isDeleting ? null : _confirmDelete,
              icon: isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(top: 12),
        child: SingleChildScrollView(
          child: getEventsBody(),
        ),
      ),
    );
  }

  Widget getEventsBody() {
    if (isLoading) {
      return Container(
        height: 600,
        child: Center(
          child: CupertinoActivityIndicator(
            radius: 20,
          ),
        ),
      );
    } else if (isError || widget.inbox == null) {
      return Container(
        height: 600,
        child: Center(
          child: NoitemScreen(
              title: t.oops,
              message: t.dataloaderror,
              onClick: () {
                //loadItems();
              }),
        ),
      );
    } else {
      final inbox = widget.inbox!;
      return _isAccommodationInbox(inbox)
          ? _AccommodationInboxView(inbox: inbox)
          : _GenericInboxView(inbox: inbox);
    }
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete notification?'),
        content: const Text('This removes the message from your inbox only.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteInbox();
    }
  }

  Future<void> _deleteInbox() async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please sign in to delete notifications.')),
      );
      return;
    }

    setState(() => isDeleting = true);
    try {
      final response = await Dio().post(
        ApiUrl.DELETE_INBOX,
        data: jsonEncode({
          'data': {
            'id': widget.inbox?.id,
            if (user.apiToken?.isNotEmpty == true) 'api_token': user.apiToken,
            if (user.email?.isNotEmpty == true) 'email': user.email,
          }
        }),
      );
      final res = decodeApiResponse(response.data);
      if ('${res['status']}' != 'ok') {
        throw Exception(
            '${res['message'] ?? 'Unable to delete notification.'}');
      }
      InboxReadStore.markRead(widget.inbox?.id);
      eventBus.fire(const InboxNotificationsChanged());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
    if (mounted) setState(() => isDeleting = false);
  }
}

class _GenericInboxView extends StatelessWidget {
  const _GenericInboxView({required this.inbox});

  final Inbox inbox;

  @override
  Widget build(BuildContext context) {
    final palette = _InboxPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InboxHeaderCard(
            title: inbox.title ?? 'Inbox message',
            date: TimUtil.formatFullDatestamp(inbox.date ?? 0),
            icon: Icons.mail_outline_rounded,
          ),
          if (inbox.imageUrl?.isNotEmpty == true) ...[
            const SizedBox(height: 18),
            _InboxImage(url: inbox.imageUrl!),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: palette.shadow,
            ),
            child: HtmlWidget(
              inbox.message ?? '',
              textStyle: TextStyle(
                color: palette.text,
                fontSize: 16,
                height: 1.55,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccommodationInboxView extends StatelessWidget {
  const _AccommodationInboxView({required this.inbox});

  final Inbox inbox;

  @override
  Widget build(BuildContext context) {
    final palette = _InboxPalette.of(context);
    final data = _AccommodationInboxData.from(inbox);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InboxHeaderCard(
            title: inbox.title ?? 'Accommodation update',
            date: TimUtil.formatFullDatestamp(inbox.date ?? 0),
            icon: Icons.hotel_rounded,
            accent: data.detail('Booking reference'),
          ),
          if (inbox.imageUrl?.isNotEmpty == true) ...[
            const SizedBox(height: 18),
            _InboxImage(url: inbox.imageUrl!),
          ],
          if (data.intro.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionCard(
              icon: Icons.favorite_border_rounded,
              title: 'Message',
              child: Text(
                data.intro,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 16,
                  height: 1.55,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
          if (data.details.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionCard(
              icon: Icons.receipt_long_rounded,
              title: 'Booking details',
              child: Column(
                children: data.details.entries
                    .map((entry) =>
                        _DetailLine(label: entry.key, value: entry.value))
                    .toList(),
              ),
            ),
          ],
          if (data.rules.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionCard(
              icon: Icons.rule_rounded,
              title: 'Important rules',
              child: Text(
                data.rules,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 15,
                  height: 1.55,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
          if (data.nextSteps.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionCard(
              icon: Icons.check_circle_outline_rounded,
              title: 'Next steps',
              tinted: true,
              child: Text(
                data.nextSteps,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 15.5,
                  height: 1.55,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (data.support.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionCard(
              icon: Icons.support_agent_rounded,
              title: 'Booking support',
              child: Column(
                children: data.support.entries
                    .map((entry) =>
                        _DetailLine(label: entry.key, value: entry.value))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InboxHeaderCard extends StatelessWidget {
  const _InboxHeaderCard({
    required this.title,
    required this.date,
    required this.icon,
    this.accent,
  });

  final String title;
  final String date;
  final IconData icon;
  final String? accent;

  @override
  Widget build(BuildContext context) {
    final palette = _InboxPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.deep, palette.deepAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: palette.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: palette.gold, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .78),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((accent ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: palette.gold,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                accent!,
                style: TextStyle(
                  color: palette.deep,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.tinted = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final palette = _InboxPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tinted ? palette.goldSoft : palette.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
        boxShadow: palette.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tinted ? palette.gold : palette.field,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon,
                    color: tinted ? palette.deep : palette.deep, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = _InboxPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                color: palette.muted,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 7,
            child: Text(
              value,
              style: TextStyle(
                color: palette.text,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxImage extends StatelessWidget {
  const _InboxImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final palette = _InboxPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 190,
          color: palette.field,
          child: const Center(child: CupertinoActivityIndicator()),
        ),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

class _AccommodationInboxData {
  const _AccommodationInboxData({
    required this.intro,
    required this.details,
    required this.rules,
    required this.nextSteps,
    required this.support,
  });

  final String intro;
  final Map<String, String> details;
  final String rules;
  final String nextSteps;
  final Map<String, String> support;

  String detail(String key) => details[key] ?? '';

  factory _AccommodationInboxData.from(Inbox inbox) {
    final lines = _plainInboxMessage(inbox.message ?? '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final intro = <String>[];
    final details = <String, String>{};
    final rules = <String>[];
    final next = <String>[];
    final support = <String, String>{};
    var section = 'intro';

    for (final line in lines) {
      final normalized = line.toLowerCase();
      if (normalized == 'booking details') {
        section = 'details';
        continue;
      }
      if (normalized == 'important rules and instructions' ||
          normalized == 'important rules') {
        section = 'rules';
        continue;
      }
      if (normalized == 'next steps') {
        section = 'next';
        continue;
      }
      if (normalized.startsWith('support contact:')) {
        section = 'support';
      }

      if (section == 'intro') {
        intro.add(line);
      } else if (section == 'details') {
        _addKeyValue(details, line);
      } else if (section == 'rules') {
        rules.add(line);
      } else if (section == 'next') {
        next.add(line);
      } else {
        _addKeyValue(support, line);
      }
    }

    return _AccommodationInboxData(
      intro: intro.join('\n\n'),
      details: details,
      rules: rules.join('\n'),
      nextSteps: next.join('\n'),
      support: support,
    );
  }
}

class _InboxPalette {
  const _InboxPalette({
    required this.background,
    required this.card,
    required this.field,
    required this.text,
    required this.muted,
    required this.deep,
    required this.deepAlt,
    required this.gold,
    required this.goldSoft,
    required this.border,
    required this.shadow,
  });

  final Color background;
  final Color card;
  final Color field;
  final Color text;
  final Color muted;
  final Color deep;
  final Color deepAlt;
  final Color gold;
  final Color goldSoft;
  final Color border;
  final List<BoxShadow> shadow;

  static _InboxPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _InboxPalette(
      background: dark ? const Color(0xFF07151E) : const Color(0xFFF3F8FA),
      card: dark ? const Color(0xFF102C39) : Colors.white,
      field: dark ? const Color(0xFF183746) : const Color(0xFFF0F5F7),
      text: dark ? Colors.white : const Color(0xFF0C2230),
      muted: dark ? const Color(0xFFB7C5CC) : const Color(0xFF61717A),
      deep: const Color(0xFF0C2230),
      deepAlt: const Color(0xFF154456),
      gold: const Color(0xFFF9B321),
      goldSoft: dark ? const Color(0xFF2B2A18) : const Color(0xFFFFF5D8),
      border:
          dark ? Colors.white.withValues(alpha: .07) : const Color(0xFFE5EEF2),
      shadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? .24 : .08),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }
}

bool _isAccommodationInbox(Inbox inbox) {
  final haystack = '${inbox.title ?? ''} ${inbox.message ?? ''}'.toLowerCase();
  return haystack.contains('accommodation') ||
      haystack.contains('booking reference') ||
      haystack.contains('room/unit');
}

void _addKeyValue(Map<String, String> target, String line) {
  final index = line.indexOf(':');
  if (index <= 0) {
    target['Note ${target.length + 1}'] = line;
    return;
  }

  final label = line.substring(0, index).trim();
  final value = line.substring(index + 1).trim();
  if (label.isNotEmpty && value.isNotEmpty) {
    target[_titleCase(label)] = value;
  }
}

String _plainInboxMessage(String html) {
  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
          RegExp(r'</(p|li|h3|section|div|article|ul)>', caseSensitive: false),
          '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String _titleCase(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.trim().isNotEmpty)
      .map((part) =>
          '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}
