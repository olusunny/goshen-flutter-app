import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/GoshenWallet.dart';
import '../models/Userdata.dart';
import '../providers/AppStateManager.dart';
import '../service/GoshenWalletApi.dart';
import '../utils/my_colors.dart';
import '../wallet_security/wallet_security_guard.dart';

class GoshenWalletTransferScreen extends StatefulWidget {
  const GoshenWalletTransferScreen({
    super.key,
    this.initialWallet,
  });

  static const routeName = '/goshen-wallet-transfer';

  final GoshenWallet? initialWallet;

  @override
  State<GoshenWalletTransferScreen> createState() =>
      _GoshenWalletTransferScreenState();
}

class _GoshenWalletTransferScreenState
    extends State<GoshenWalletTransferScreen> {
  final _api = GoshenWalletApi();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Future<GoshenWallet>? _walletFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _load() {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) return;
    setState(() {
      _walletFuture = widget.initialWallet == null
          ? _api.fetchWallet(user)
          : Future.value(widget.initialWallet);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppStateManager>(context).userdata;
    final colors = _TransferPalette.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Wallet transfer'),
        backgroundColor: const Color(0xFF0C2230),
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? _TransferMessage(
              colors: colors,
              message: 'Please sign in to transfer from your wallet.',
            )
          : FutureBuilder<GoshenWallet>(
              future: _walletFuture,
              builder: (context, snapshot) {
                if (_walletFuture == null ||
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _TransferMessage(
                    colors: colors,
                    message: snapshot.error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                    onRetry: _load,
                  );
                }

                final wallet = snapshot.data!;
                return SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                    children: [
                      _BalanceHeader(wallet: wallet, colors: colors),
                      const SizedBox(height: 16),
                      _TransferFormCard(
                        wallet: wallet,
                        colors: colors,
                        recipientController: _recipientController,
                        amountController: _amountController,
                        noteController: _noteController,
                        saving: _saving,
                        onSubmit: () => _submitTransfer(user, wallet),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Transfers are sent only to registered app members by email address or phone number. Confirm the recipient carefully before sending.',
                        style: TextStyle(
                          color: colors.muted,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _submitTransfer(Userdata user, GoshenWallet wallet) async {
    final recipient = _recipientController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (recipient.isEmpty) {
      _showSnack('Enter the recipient email address or phone number.');
      return;
    }
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid transfer amount.');
      return;
    }
    if (amount > wallet.balance) {
      _showSnack('Your wallet balance is not enough for this transfer.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send wallet transfer?'),
        content: Text(
          'Send ${_money(amount, wallet.currency)} to $recipient? This cannot be reversed from the app after it is completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send money'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final verified = await WalletSecurityGuard.ensureWalletUnlocked(
      context,
      requireFreshVerification: true,
    );
    if (!verified) {
      _showSnack('Wallet verification is required to send money.');
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await _api.transfer(
        user: user,
        recipient: recipient,
        amount: amount,
        currency: wallet.currency,
        note: _noteController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet transfer completed.')),
      );
      Navigator.pop(context, updated);
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({
    required this.wallet,
    required this.colors,
  });

  final GoshenWallet wallet;
  final _TransferPalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0C2230), Color(0xFF15513F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Color(0xFFFFC857),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available wallet balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _money(wallet.balance, wallet.currency),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
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

class _TransferFormCard extends StatelessWidget {
  const _TransferFormCard({
    required this.wallet,
    required this.colors,
    required this.recipientController,
    required this.amountController,
    required this.noteController,
    required this.saving,
    required this.onSubmit,
  });

  final GoshenWallet wallet;
  final _TransferPalette colors;
  final TextEditingController recipientController;
  final TextEditingController amountController;
  final TextEditingController noteController;
  final bool saving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.18 : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transfer details',
            style: TextStyle(
              color: colors.text,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Send available funds to a registered MFM Triumphant Church app member.',
            style: TextStyle(
              color: colors.muted,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: recipientController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
            decoration: _inputDecoration(
              'Recipient email or phone',
              colors,
              Icons.person_search_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
            decoration: _inputDecoration(
              'Amount (${wallet.currency})',
              colors,
              Icons.payments_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            maxLines: 3,
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
            decoration: _inputDecoration(
              'Note (optional)',
              colors,
              Icons.notes_outlined,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: saving ? null : onSubmit,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.lock_outline_rounded),
              label: Text(saving ? 'Sending...' : 'Verify and send'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFB522),
                foregroundColor: MyColors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferMessage extends StatelessWidget {
  const _TransferMessage({
    required this.colors,
    required this.message,
    this.onRetry,
  });

  final _TransferPalette colors;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(
  String label,
  _TransferPalette colors,
  IconData icon,
) {
  return InputDecoration(
    prefixIcon: Icon(icon),
    labelText: label,
    labelStyle: TextStyle(color: colors.muted, fontWeight: FontWeight.w700),
    filled: true,
    fillColor: colors.soft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: colors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFFFC857), width: 1.5),
    ),
  );
}

String _money(double amount, String currency) {
  final symbol = switch (currency.toUpperCase()) {
    'GBP' => '£',
    'USD' => r'$',
    'EUR' => '€',
    'NGN' => '₦',
    _ => '${currency.toUpperCase()} ',
  };
  return '$symbol${NumberFormat('#,##0.00').format(amount)}';
}

class _TransferPalette {
  const _TransferPalette({
    required this.isDark,
    required this.background,
    required this.card,
    required this.soft,
    required this.text,
    required this.muted,
    required this.border,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color soft;
  final Color text;
  final Color muted;
  final Color border;

  static _TransferPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _TransferPalette(
      isDark: isDark,
      background: isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
      card: isDark ? const Color(0xFF102532) : Colors.white,
      soft: isDark ? const Color(0xFF0C2230) : const Color(0xFFF0F5F7),
      text: isDark ? Colors.white : const Color(0xFF102532),
      muted: isDark ? Colors.white60 : const Color(0xFF60707A),
      border: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE0E8ED),
    );
  }
}
