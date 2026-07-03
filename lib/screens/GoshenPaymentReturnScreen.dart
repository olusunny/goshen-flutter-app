import 'package:flutter/material.dart';

import 'GoshenRetreatScreen.dart';
import 'GoshenWalletScreen.dart';

class GoshenPaymentReturnScreen extends StatelessWidget {
  const GoshenPaymentReturnScreen({
    super.key,
    required this.success,
    this.wallet = false,
  });

  static const routeName = '/goshen-payment-return';

  final bool success;
  final bool wallet;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0C2230);
    const gold = Color(0xFFFFB522);
    final title = success ? 'Payment received' : 'Payment not completed';
    final destination = wallet ? 'My Wallet' : 'My Registration';
    final message = success
        ? wallet
            ? 'Thank you. We are refreshing your wallet so your new balance can appear as soon as Stripe confirms it.'
            : 'Thank you. We are refreshing your Goshen Retreat registration so your payment status and ticket can appear on My Registration as soon as Stripe confirms it.'
        : wallet
            ? 'Your wallet top-up was not completed. You can return to My Wallet and try again whenever you are ready.'
            : 'Your payment was not completed. You can return to My Registration and continue the payment from your registration history.';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FA),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('Goshen payment'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: success
                            ? const Color(0xFFEAF8EF)
                            : const Color(0xFFFFF5DE),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        success
                            ? Icons.check_circle_rounded
                            : Icons.info_rounded,
                        color: success ? const Color(0xFF118A47) : gold,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: primary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF66727A),
                        fontSize: 16,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: primary,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          wallet
                              ? GoshenWalletScreen.routeName
                              : GoshenMyRegistrationScreen.routeName,
                          (route) => route.isFirst,
                        );
                      },
                      icon: Icon(wallet
                          ? Icons.account_balance_wallet_outlined
                          : Icons.confirmation_number_rounded),
                      label: Text('View $destination'),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
