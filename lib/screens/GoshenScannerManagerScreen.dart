import 'package:flutter/material.dart';

import '../models/GoshenRetreat.dart';
import '../models/Userdata.dart';
import '../service/GoshenRetreatApi.dart';

class GoshenScannerManagerScreen extends StatefulWidget {
  const GoshenScannerManagerScreen({
    super.key,
    required this.user,
  });

  final Userdata user;

  @override
  State<GoshenScannerManagerScreen> createState() =>
      _GoshenScannerManagerScreenState();
}

class _GoshenScannerManagerScreenState
    extends State<GoshenScannerManagerScreen> {
  final _api = GoshenRetreatApi();
  late Future<List<GoshenScannerOperator>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<GoshenScannerOperator>> _load() {
    return _api.fetchScannerOperators(widget.user);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _toggle(GoshenScannerOperator operator) async {
    final suspend = !operator.scannerSuspended;
    final reasonController = TextEditingController(
      text: suspend ? 'Scanner activity paused by event manager' : '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            suspend ? 'Suspend scanner?' : 'Resume scanner?',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suspend
                    ? '${operator.name} will not be able to scan or check in tickets until resumed.'
                    : '${operator.name} will be able to scan tickets again.',
              ),
              if (suspend) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(suspend ? 'Suspend' : 'Resume'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _api.toggleScannerOperator(
        user: widget.user,
        userId: operator.id,
        suspend: suspend,
        reason: reasonController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            suspend
                ? 'Scanner activity suspended for ${operator.name}.'
                : 'Scanner activity resumed for ${operator.name}.',
          ),
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final background = dark ? const Color(0xFF071820) : const Color(0xFFF3F8FA);
    final card = dark ? const Color(0xFF0C2733) : Colors.white;
    final text = dark ? Colors.white : const Color(0xFF0C2230);
    final muted = dark ? Colors.white70 : const Color(0xFF60707A);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Manage Scanners'),
        backgroundColor: const Color(0xFF0C2230),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<GoshenScannerOperator>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _HeroCard(
                    title: 'Scanner access',
                    subtitle: 'Unable to load active scanners right now.',
                    icon: Icons.manage_accounts_rounded,
                    dark: dark,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              );
            }

            final operators = snapshot.data ?? const [];

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                _HeroCard(
                  title: 'Scanner access',
                  subtitle:
                      'Pause or resume individual scanner activity during Goshen Retreat check-in.',
                  icon: Icons.qr_code_scanner_rounded,
                  dark: dark,
                ),
                const SizedBox(height: 18),
                if (operators.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: dark ? Colors.white12 : const Color(0xFFE1EAEE),
                      ),
                    ),
                    child: Text(
                      'No active scanner users are available yet.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  ...operators.map(
                    (operator) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ScannerCard(
                        operator: operator,
                        cardColor: card,
                        textColor: text,
                        mutedColor: muted,
                        busy: _busy,
                        onToggle: () => _toggle(operator),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.dark,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0C2230), Color(0xFF16513E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? .2 : .08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: const Color(0xFFFFC857), size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(.78),
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

class _ScannerCard extends StatelessWidget {
  const _ScannerCard({
    required this.operator,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.busy,
    required this.onToggle,
  });

  final GoshenScannerOperator operator;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final suspended = operator.scannerSuspended;
    final accent =
        suspended ? const Color(0xFFEF4444) : const Color(0xFF16A34A);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFEAF1F4),
                backgroundImage: operator.avatar.trim().isEmpty
                    ? null
                    : NetworkImage(operator.avatar),
                child: operator.avatar.trim().isEmpty
                    ? Text(
                        operator.name.trim().isEmpty
                            ? 'S'
                            : operator.name.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF0C2230),
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operator.name.trim().isEmpty ? 'Scanner' : operator.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      operator.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: mutedColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: accent.withOpacity(.13),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  suspended ? 'Suspended' : 'Active',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: operator.roles
                .map((role) => Chip(
                      label: Text(role.replaceAll('_', ' ')),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          if (suspended &&
              operator.scannerSuspensionReason.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              operator.scannerSuspensionReason,
              style: TextStyle(color: mutedColor),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: mutedColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  operator.lastSeenAt == null
                      ? 'No recent app activity'
                      : 'Last active ${_formatDateTime(operator.lastSeenAt!)}',
                  style:
                      TextStyle(color: mutedColor, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: busy ? null : onToggle,
                icon: Icon(suspended
                    ? Icons.play_arrow_rounded
                    : Icons.pause_circle_outline_rounded),
                label: Text(suspended ? 'Resume' : 'Suspend'),
                style: FilledButton.styleFrom(
                  backgroundColor: suspended
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF0C2230),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}/${value.month}/${value.year} $hour:$minute';
  }
}
