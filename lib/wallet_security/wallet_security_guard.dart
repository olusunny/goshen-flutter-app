import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/AppStateManager.dart';
import '../screens/GoshenWalletScreen.dart';
import '../screens/GoshenWalletTransferScreen.dart';
import 'wallet_security_controller.dart';
import 'wallet_security_flow.dart';

class WalletSecurityGuard {
  const WalletSecurityGuard._();

  static bool isWalletRoute(String? routeName) {
    return routeName == GoshenWalletScreen.routeName ||
        routeName == GoshenWalletTransferScreen.routeName ||
        routeName == GoshenWalletWithdrawalScreen.routeName ||
        routeName == GoshenWalletActivityDetailScreen.routeName ||
        routeName == '/goshen-wallet';
  }

  static Future<bool> ensureWalletUnlocked(
    BuildContext context, {
    bool requireFreshVerification = false,
  }) async {
    final controller =
        Provider.of<WalletSecurityController>(context, listen: false);
    await controller.load();
    final alreadyUnlocked = requireFreshVerification
        ? controller.hasFreshVerification
        : controller.isWalletUnlocked;
    if (alreadyUnlocked) return true;
    if (!context.mounted) return false;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChangeNotifierProvider<WalletSecurityController>.value(
          value: controller,
          child: WalletSecurityFlowScreen(
            requireFreshVerification: requireFreshVerification,
          ),
        ),
      ),
    );
    return result == true;
  }
}

class WalletSecurityGate extends StatefulWidget {
  const WalletSecurityGate({
    super.key,
    required this.child,
    this.requireFreshVerification = false,
  });

  final Widget child;
  final bool requireFreshVerification;

  @override
  State<WalletSecurityGate> createState() => _WalletSecurityGateState();
}

class _WalletSecurityGateState extends State<WalletSecurityGate> {
  bool _authorized = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkCurrentSession());
  }

  Future<void> _checkCurrentSession() async {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final user = await appState.ensureUserDataLoaded();
    if (!mounted) return;

    final token = (user?.apiToken ?? '').trim();
    if (user == null || token.isEmpty) {
      setState(() {
        _authorized = true;
        _checked = true;
      });
      return;
    }

    if (!mounted) return;
    final controller =
        Provider.of<WalletSecurityController>(context, listen: false);
    await controller.load();
    if (!mounted) return;
    final authorized = widget.requireFreshVerification
        ? controller.hasFreshVerification
        : controller.isWalletUnlocked;
    setState(() {
      _authorized = authorized;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    if (!appState.isUserDataHydrated || !_checked) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F8FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (appState.userdata == null) return widget.child;
    if (_authorized) return widget.child;
    return WalletSecurityFlowScreen(
      requireFreshVerification: widget.requireFreshVerification,
      popOnCompleted: false,
      onCompleted: () {
        if (mounted) setState(() => _authorized = true);
      },
      onCancelled: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );
  }
}
