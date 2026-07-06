import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/GoshenWallet.dart';
import '../models/ScreenArguements.dart';
import '../models/Userdata.dart';
import '../providers/AppStateManager.dart';
import '../providers/HomeProvider.dart';
import '../service/GoshenWalletApi.dart';
import '../screens/GoshenWalletTransferScreen.dart';
import '../utils/my_colors.dart';
import '../wallet_security/wallet_security_guard.dart';

class GoshenWalletScreen extends StatefulWidget {
  const GoshenWalletScreen({super.key});

  static const routeName = '/goshen-wallet';

  @override
  State<GoshenWalletScreen> createState() => _GoshenWalletScreenState();
}

class _GoshenWalletScreenState extends State<GoshenWalletScreen> {
  final _api = GoshenWalletApi();
  final _goalLabelController = TextEditingController();
  final _goalController = TextEditingController();
  final _topUpController = TextEditingController();
  final _voucherController = TextEditingController();
  final _planAmountController = TextEditingController();
  final _planCyclesController = TextEditingController();
  String _frequency = 'weekly';
  int? _editingGoalId;
  int? _editingPlanId;
  String? _goalEditorSignature;
  bool _saving = false;
  Future<GoshenWallet>? _walletFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _goalLabelController.dispose();
    _goalController.dispose();
    _topUpController.dispose();
    _voucherController.dispose();
    _planAmountController.dispose();
    _planCyclesController.dispose();
    super.dispose();
  }

  void _load() {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) return;
    final cached = _api.cachedWallet(user);
    setState(() {
      _walletFuture =
          cached == null ? _api.fetchWallet(user) : Future.value(cached);
    });
    if (cached != null) _refreshWallet(user);
  }

  Future<void> _refreshWallet(Userdata user) async {
    try {
      final wallet = await _api.fetchWallet(user);
      if (!mounted) return;
      setState(() {
        _walletFuture = Future.value(wallet);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppStateManager>(context).userdata;
    final homeData = Provider.of<HomeProvider>(context).data;
    final autoTopUpEnabled =
        _featureEnabled(homeData['goshen_wallet_auto_topup_enabled']);
    final withdrawalEnabled =
        _featureEnabled(homeData['goshen_wallet_withdrawals_enabled']);
    final palette = _WalletPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: const Color(0xFF0C2230),
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? _GuestState(palette: palette)
          : RefreshIndicator(
              onRefresh: () async => _load(),
              child: FutureBuilder<GoshenWallet>(
                future: _walletFuture,
                builder: (context, snapshot) {
                  if (_walletFuture == null ||
                      snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(
                      palette: palette,
                      message: snapshot.error.toString().replaceFirst(
                            'Exception: ',
                            '',
                          ),
                      onRetry: _load,
                    );
                  }

                  final wallet = snapshot.data!;
                  _hydrateGoalEditor(wallet);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                    children: [
                      _WalletHero(wallet: wallet, palette: palette),
                      const SizedBox(height: 16),
                      _GoalCard(
                        wallet: wallet,
                        palette: palette,
                        labelController: _goalLabelController,
                        controller: _goalController,
                        editingGoalId: _editingGoalId,
                        saving: _saving,
                        onSave: () => _saveGoal(user, wallet),
                        onCreate: () => _createGoal(user, wallet),
                        onSelectGoal: _selectGoal,
                        onCancel: _currentGoalAmount(wallet) > 0
                            ? () => _cancelGoal(user, wallet)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _TopUpCard(
                        wallet: wallet,
                        palette: palette,
                        amountController: _topUpController,
                        saving: _saving,
                        onTopUp: () => _topUp(user, wallet),
                      ),
                      const SizedBox(height: 16),
                      _VoucherTopUpCard(
                        wallet: wallet,
                        palette: palette,
                        controller: _voucherController,
                        saving: _saving,
                        onApply: () => _redeemVoucher(user),
                      ),
                      if (autoTopUpEnabled) ...[
                        const SizedBox(height: 16),
                        _SavingsPlanCard(
                          wallet: wallet,
                          palette: palette,
                          amountController: _planAmountController,
                          cyclesController: _planCyclesController,
                          frequency: _frequency,
                          editingPlanId: _editingPlanId,
                          saving: _saving,
                          onFrequencyChanged: (value) =>
                              setState(() => _frequency = value),
                          onSave: () => _saveSavingsPlan(user, wallet),
                          onNewPlan: _clearPlanEditor,
                          onEdit: _editSavingsPlan,
                          onSetup: (plan) =>
                              _setupSavingsPlan(user, wallet, plan),
                          onToggle: (plan, active) =>
                              _toggleSavingsPlan(user, wallet, plan, active),
                          onCancel: (plan) =>
                              _cancelSavingsPlan(user, wallet, plan),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _TransferActionCard(
                        wallet: wallet,
                        palette: palette,
                        onOpen: () => _openTransfer(wallet),
                      ),
                      if (withdrawalEnabled) ...[
                        const SizedBox(height: 16),
                        _WithdrawalLaunchCard(
                          wallet: wallet,
                          palette: palette,
                          onOpen: () => _openWithdrawal(wallet),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _LedgerCard(
                        wallet: wallet,
                        palette: palette,
                        onEntryTap: _openActivity,
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  bool _featureEnabled(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (['0', 'false', 'off', 'no'].contains(normalized)) return false;
      if (['1', 'true', 'on', 'yes'].contains(normalized)) return true;
    }
    return true;
  }

  Future<void> _saveGoal(Userdata user, GoshenWallet wallet) async {
    final amount = double.tryParse(_goalController.text.trim());
    final label = _goalLabelController.text.trim().isEmpty
        ? 'Goshen Retreat savings'
        : _goalLabelController.text.trim();
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid savings goal amount.');
      return;
    }
    if (!await _ensureFreshWalletVerification()) return;

    await _run(() async {
      final updated = await _api.updateGoal(
        user: user,
        amount: amount,
        label: label,
        currency: wallet.currency,
        goalId: _editingGoalId ?? wallet.goalId,
      );
      _replaceWallet(updated);
      _showSnack('Wallet goal updated.');
    });
  }

  Future<void> _createGoal(Userdata user, GoshenWallet wallet) async {
    final amount = double.tryParse(_goalController.text.trim());
    final label = _goalLabelController.text.trim().isEmpty
        ? 'Goshen Retreat savings'
        : _goalLabelController.text.trim();
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid savings goal amount.');
      return;
    }
    if (!await _ensureFreshWalletVerification()) return;

    await _run(() async {
      final updated = await _api.createGoal(
        user: user,
        amount: amount,
        label: label,
        currency: wallet.currency,
      );
      final createdGoal = _latestActiveGoal(updated);
      setState(() {
        _editingGoalId = createdGoal?.id;
        _goalEditorSignature = null;
        _walletFuture = Future.value(updated);
      });
      _showSnack('New wallet goal added.');
    });
  }

  Future<void> _cancelGoal(Userdata user, GoshenWallet wallet) async {
    final goalId = _editingGoalId ?? wallet.goalId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel savings goal?'),
        content: const Text(
          'This only removes your target goal. Your wallet balance stays exactly as it is and can still be used for Goshen Retreat payments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep goal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel goal'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!await _ensureFreshWalletVerification()) return;

    await _run(() async {
      final updated = await _api.cancelGoal(user: user, goalId: goalId);
      _goalController.clear();
      _goalLabelController.clear();
      _editingGoalId = null;
      _replaceWallet(updated);
      _showSnack('Savings goal cancelled. Your wallet balance is unchanged.');
    });
  }

  Future<void> _topUp(Userdata user, GoshenWallet wallet) async {
    final amount = double.tryParse(_topUpController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid top-up amount.');
      return;
    }
    if (!await _ensureFreshWalletVerification()) return;

    await _run(() async {
      final setupPlan = _latestSetupRequiredPlan(wallet);
      await _startTopUpCheckout(
        user: user,
        wallet: wallet,
        amount: amount,
        savingsPlanId: setupPlan?.id,
      );
    });
  }

  Future<void> _redeemVoucher(Userdata user) async {
    final code = _voucherController.text.trim();
    if (code.length < 8) {
      _showSnack('Enter a valid wallet voucher code.');
      return;
    }
    if (!await _ensureFreshWalletVerification()) return;

    await _run(() async {
      final updated = await _api.redeemTopUpVoucher(user: user, code: code);
      _voucherController.clear();
      _replaceWallet(updated);
      _showSnack('Voucher funds added to your wallet.');
    });
  }

  Future<void> _saveSavingsPlan(Userdata user, GoshenWallet wallet) async {
    final amount = double.tryParse(_planAmountController.text.trim());
    final cycles = int.tryParse(_planCyclesController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid scheduled top-up amount.');
      return;
    }
    if (!await _ensureFreshWalletVerification()) return;

    await _run(() async {
      final plan = _editingPlan(wallet);
      final updated = plan == null
          ? await _api.createSavingsPlan(
              user: user,
              amount: amount,
              frequency: _frequency,
              totalCycles: cycles != null && cycles > 0 ? cycles : null,
              currency: wallet.currency,
            )
          : await _api.updateSavingsPlan(
              user: user,
              plan: plan,
              status: plan.isActive ? 'active' : 'paused',
              amount: amount,
              frequency: _frequency,
              remainingCycles: cycles != null && cycles > 0 ? cycles : null,
              currency: wallet.currency,
            );
      _replaceWallet(updated);
      final createdPlan = _latestSavingsPlan(updated);
      if (plan == null && createdPlan?.needsSetup == true) {
        await _startTopUpCheckout(
          user: user,
          wallet: updated,
          amount: amount,
          savingsPlanId: createdPlan?.id,
          setupPlan: true,
        );
        return;
      }
      _showSnack(plan == null
          ? updated.savedPaymentMethod
              ? 'Savings plan is active.'
              : 'Savings plan saved. Top up once to authorize automatic payments.'
          : 'Savings plan updated.');
    });
  }

  Future<void> _setupSavingsPlan(
    Userdata user,
    GoshenWallet wallet,
    GoshenWalletSavingsPlan plan,
  ) async {
    if (!await _ensureFreshWalletVerification()) return;

    await _run(() async {
      await _startTopUpCheckout(
        user: user,
        wallet: wallet,
        amount: plan.amount,
        savingsPlanId: plan.id,
        setupPlan: true,
      );
    });
  }

  Future<void> _toggleSavingsPlan(
    Userdata user,
    GoshenWallet wallet,
    GoshenWalletSavingsPlan plan,
    bool active,
  ) async {
    if (!await _ensureFreshWalletVerification()) return;
    await _run(() async {
      final updated = await _api.updateSavingsPlan(
        user: user,
        plan: plan,
        status: active ? 'paused' : 'active',
      );
      _replaceWallet(updated);
      _showSnack(active ? 'Savings plan paused.' : 'Savings plan resumed.');
    });
  }

  Future<void> _cancelSavingsPlan(
    Userdata user,
    GoshenWallet wallet,
    GoshenWalletSavingsPlan plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel auto top-up?'),
        content: const Text(
          'This stops future scheduled top-ups. Money already in your wallet remains available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel plan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!await _ensureFreshWalletVerification()) return;

    await _run(() async {
      final updated = await _api.updateSavingsPlan(
        user: user,
        plan: plan,
        status: 'cancelled',
      );
      _replaceWallet(updated);
      _showSnack('Auto top-up plan cancelled.');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startTopUpCheckout({
    required Userdata user,
    required GoshenWallet wallet,
    required double amount,
    int? savingsPlanId,
    bool setupPlan = false,
  }) async {
    final checkout = await _api.createTopUpCheckout(
      user: user,
      amount: amount,
      currency: wallet.currency,
      savePaymentMethod: true,
      savingsPlanId: savingsPlanId,
    );
    final url = '${checkout['checkout_url'] ?? ''}'.trim();
    if (url.isEmpty) {
      throw Exception('Wallet checkout is not available right now.');
    }
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('Unable to open secure checkout.');
    }
    _showSnack(setupPlan
        ? 'Secure checkout opened. Complete it to activate automatic top-ups.'
        : 'Secure Stripe checkout opened. Return here after payment.');
  }

  Future<bool> _ensureFreshWalletVerification() async {
    final unlocked = await WalletSecurityGuard.ensureWalletUnlocked(
      context,
      requireFreshVerification: true,
    );
    if (!unlocked && mounted) {
      _showSnack('Wallet verification is required to continue.');
    }
    return unlocked;
  }

  Future<void> _openTransfer(GoshenWallet wallet) async {
    final result = await Navigator.pushNamed(
      context,
      GoshenWalletTransferScreen.routeName,
      arguments: ScreenArguements(items: wallet),
    );
    if (result is GoshenWallet) {
      _replaceWallet(result);
    }
  }

  Future<void> _openWithdrawal(GoshenWallet wallet) async {
    final result = await Navigator.pushNamed(
      context,
      GoshenWalletWithdrawalScreen.routeName,
      arguments: ScreenArguements(items: wallet),
    );
    if (result is GoshenWallet) {
      _replaceWallet(result);
    }
  }

  void _openActivity(GoshenWalletLedgerEntry entry) {
    Navigator.pushNamed(
      context,
      GoshenWalletActivityDetailScreen.routeName,
      arguments: ScreenArguements(items: entry),
    );
  }

  void _replaceWallet(GoshenWallet wallet) {
    setState(() {
      _goalEditorSignature = null;
      _walletFuture = Future.value(wallet);
    });
  }

  void _hydrateGoalEditor(GoshenWallet wallet) {
    final selectedGoal = _selectedGoal(wallet);
    final signature = [
      wallet.id,
      selectedGoal?.id ?? wallet.goalId ?? 'legacy',
      selectedGoal?.label ?? wallet.goalLabel ?? '',
      selectedGoal?.targetAmount ?? wallet.goalAmount ?? 0,
      wallet.goals
          .map((goal) =>
              '${goal.id}:${goal.status}:${goal.label}:${goal.targetAmount}:${goal.isPrimary}')
          .join('|'),
    ].join('::');

    if (_goalEditorSignature == signature) return;

    final amount = selectedGoal?.targetAmount ?? wallet.goalAmount ?? 0;
    _editingGoalId = selectedGoal?.id ?? wallet.goalId;
    _goalController.text = amount > 0 ? _plainAmount(amount) : '';
    _goalLabelController.text =
        selectedGoal?.label ?? wallet.goalLabel ?? 'Goshen Retreat savings';
    _goalEditorSignature = signature;
  }

  GoshenWalletGoal? _selectedGoal(GoshenWallet wallet) {
    final activeGoals = wallet.goals.where((goal) => goal.isActive).toList();
    if (activeGoals.isEmpty) return null;

    if (_editingGoalId != null) {
      for (final goal in activeGoals) {
        if (goal.id == _editingGoalId) return goal;
      }
    }

    for (final goal in activeGoals) {
      if (goal.isPrimary) return goal;
    }
    return activeGoals.first;
  }

  GoshenWalletGoal? _latestActiveGoal(GoshenWallet wallet) {
    final activeGoals = wallet.goals.where((goal) => goal.isActive);
    GoshenWalletGoal? latest;
    for (final goal in activeGoals) {
      if (latest == null || goal.id > latest.id) {
        latest = goal;
      }
    }
    return latest;
  }

  double _currentGoalAmount(GoshenWallet wallet) {
    final selectedGoal = _selectedGoal(wallet);
    return selectedGoal?.targetAmount ?? wallet.goalAmount ?? 0;
  }

  GoshenWalletSavingsPlan? _editingPlan(GoshenWallet wallet) {
    if (_editingPlanId == null) return null;
    for (final plan in wallet.savingsPlans) {
      if (plan.id == _editingPlanId && plan.status != 'cancelled') {
        return plan;
      }
    }
    return null;
  }

  GoshenWalletSavingsPlan? _latestSavingsPlan(GoshenWallet wallet) {
    GoshenWalletSavingsPlan? latest;
    for (final plan in wallet.savingsPlans) {
      if (latest == null || plan.id > latest.id) {
        latest = plan;
      }
    }
    return latest;
  }

  GoshenWalletSavingsPlan? _latestSetupRequiredPlan(GoshenWallet wallet) {
    GoshenWalletSavingsPlan? latest;
    for (final plan in wallet.savingsPlans.where((plan) => plan.needsSetup)) {
      if (latest == null || plan.id > latest.id) {
        latest = plan;
      }
    }
    return latest;
  }

  void _selectGoal(GoshenWalletGoal goal) {
    setState(() {
      _editingGoalId = goal.id;
      _goalEditorSignature = null;
      _goalLabelController.text = goal.label;
      _goalController.text = _plainAmount(goal.targetAmount);
    });
  }

  void _editSavingsPlan(GoshenWalletSavingsPlan plan) {
    setState(() {
      _editingPlanId = plan.id;
      _planAmountController.text = _plainAmount(plan.amount);
      _planCyclesController.text =
          plan.totalCycles == null ? '' : plan.totalCycles.toString();
      _frequency = ['daily', 'weekly', 'monthly'].contains(plan.frequency)
          ? plan.frequency
          : 'weekly';
    });
  }

  void _clearPlanEditor() {
    setState(() {
      _editingPlanId = null;
      _planAmountController.clear();
      _planCyclesController.clear();
      _frequency = 'weekly';
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class GoshenWalletWithdrawalScreen extends StatefulWidget {
  const GoshenWalletWithdrawalScreen({super.key, this.initialWallet});

  static const routeName = '/goshen-wallet-withdrawal';

  final GoshenWallet? initialWallet;

  @override
  State<GoshenWalletWithdrawalScreen> createState() =>
      _GoshenWalletWithdrawalScreenState();
}

class _GoshenWalletWithdrawalScreenState
    extends State<GoshenWalletWithdrawalScreen> {
  final _api = GoshenWalletApi();
  final _amountController = TextEditingController();
  final _bankController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _sortCodeController = TextEditingController();
  final _ibanController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;
  Future<GoshenWallet>? _walletFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _sortCodeController.dispose();
    _ibanController.dispose();
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
    final palette = _WalletPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Withdraw wallet funds'),
        backgroundColor: const Color(0xFF0C2230),
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? _GuestState(palette: palette)
          : RefreshIndicator(
              onRefresh: () async => _load(),
              child: FutureBuilder<GoshenWallet>(
                future: _walletFuture,
                builder: (context, snapshot) {
                  if (_walletFuture == null ||
                      snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(
                      palette: palette,
                      message: snapshot.error.toString().replaceFirst(
                            'Exception: ',
                            '',
                          ),
                      onRetry: _load,
                    );
                  }

                  final wallet = snapshot.data!;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                    children: [
                      _WithdrawalRequestCard(
                        wallet: wallet,
                        palette: palette,
                        amountController: _amountController,
                        bankController: _bankController,
                        accountNameController: _accountNameController,
                        accountNumberController: _accountNumberController,
                        sortCodeController: _sortCodeController,
                        ibanController: _ibanController,
                        noteController: _noteController,
                        saving: _saving,
                        onSubmit: () => _submitWithdrawal(user, wallet),
                        onCancel: (request) => _cancelWithdrawal(user, request),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Future<void> _submitWithdrawal(Userdata user, GoshenWallet wallet) async {
    final amount = double.tryParse(_amountController.text.trim());
    final bank = _bankController.text.trim();
    final accountName = _accountNameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();

    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid withdrawal amount.');
      return;
    }
    if (amount > wallet.balance) {
      _showSnack('Withdrawal amount is higher than your wallet balance.');
      return;
    }
    if (bank.isEmpty || accountName.isEmpty || accountNumber.isEmpty) {
      _showSnack('Enter bank name, account name, and account number.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit withdrawal request?'),
        content: Text(
          '${_money(amount, wallet.currency)} will be reserved from your wallet until admin review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!await _ensureFreshWalletVerification()) return;

    await _run(() async {
      final updated = await _api.createWithdrawal(
        user: user,
        amount: amount,
        currency: wallet.currency,
        bankName: bank,
        accountName: accountName,
        accountNumber: accountNumber,
        sortCode: _sortCodeController.text,
        iban: _ibanController.text,
        userNote: _noteController.text,
      );
      if (!mounted) return;
      _showSnack('Withdrawal request submitted.');
      Navigator.pop(context, updated);
    });
  }

  Future<void> _cancelWithdrawal(
    Userdata user,
    GoshenWalletWithdrawalRequest request,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel withdrawal request?'),
        content: const Text(
          'Reserved funds will be returned to your wallet immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!await _ensureFreshWalletVerification()) return;

    await _run(() async {
      final updated = await _api.cancelWithdrawal(user: user, request: request);
      if (!mounted) return;
      _showSnack('Withdrawal cancelled. Funds returned to wallet.');
      Navigator.pop(context, updated);
    });
  }

  Future<bool> _ensureFreshWalletVerification() async {
    final unlocked = await WalletSecurityGuard.ensureWalletUnlocked(
      context,
      requireFreshVerification: true,
    );
    if (!unlocked && mounted) {
      _showSnack('Wallet verification is required to continue.');
    }
    return unlocked;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
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

class GoshenWalletActivityDetailScreen extends StatelessWidget {
  const GoshenWalletActivityDetailScreen({super.key, required this.entry});

  static const routeName = '/goshen-wallet-activity';

  final GoshenWalletLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = _WalletPalette.of(context);
    final positive = entry.direction != 'debit';
    final occurredAt = entry.settledAt ?? entry.createdAt;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Activity details'),
        backgroundColor: const Color(0xFF0C2230),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          _SectionCard(
            palette: palette,
            title: entry.description.isEmpty
                ? 'Wallet activity'
                : entry.description,
            subtitle: _dateTimeLabel(occurredAt),
            icon: positive
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            children: [
              _DetailRow(
                label: 'Amount',
                value:
                    '${positive ? '+' : '-'}${_money(entry.amount, entry.currency)}',
                palette: palette,
              ),
              _DetailRow(
                label: 'Status',
                value: entry.status.replaceAll('_', ' '),
                palette: palette,
              ),
              _DetailRow(
                label: 'Type',
                value: entry.type.replaceAll('_', ' '),
                palette: palette,
              ),
              if ((entry.reference ?? '').trim().isNotEmpty)
                _DetailRow(
                  label: 'Reference',
                  value: entry.reference!.trim(),
                  palette: palette,
                ),
              if (entry.createdAt != null)
                _DetailRow(
                  label: 'Created',
                  value: _dateTimeLabel(entry.createdAt),
                  palette: palette,
                ),
              if (entry.settledAt != null)
                _DetailRow(
                  label: 'Settled',
                  value: _dateTimeLabel(entry.settledAt),
                  palette: palette,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletHero extends StatelessWidget {
  const _WalletHero({required this.wallet, required this.palette});

  final GoshenWallet wallet;
  final _WalletPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF0C2230), Color(0xFF15513F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _WalletGraphic())),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Goshen savings wallet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                _money(wallet.balance, wallet.currency),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                wallet.savedPaymentMethod
                    ? 'Automatic top-up is ready when you create a plan.'
                    : 'Top up once and save your card to enable auto top-up.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((wallet.goalAmount ?? 0) > 0) ...[
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: wallet.progress,
                    color: const Color(0xFFFFC857),
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(wallet.progress * 100).round()}% of ${_money(wallet.goalAmount!, wallet.currency)} target',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.wallet,
    required this.palette,
    required this.labelController,
    required this.controller,
    required this.editingGoalId,
    required this.saving,
    required this.onSave,
    required this.onCreate,
    required this.onSelectGoal,
    this.onCancel,
  });

  final GoshenWallet wallet;
  final _WalletPalette palette;
  final TextEditingController labelController;
  final TextEditingController controller;
  final int? editingGoalId;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCreate;
  final ValueChanged<GoshenWalletGoal> onSelectGoal;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final activeGoals = wallet.goals.where((goal) => goal.isActive).toList();

    return _SectionCard(
      palette: palette,
      title: 'Savings goal',
      subtitle: 'Edit a saved goal or add another target for Goshen Retreat.',
      icon: Icons.flag_outlined,
      children: [
        if (activeGoals.isNotEmpty) ...[
          Text(
            'Saved goals',
            style: TextStyle(
              color: palette.muted,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ...activeGoals.map(
            (goal) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GoalTile(
                goal: goal,
                selected: goal.id == editingGoalId,
                palette: palette,
                onTap: () => onSelectGoal(goal),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        TextField(
          controller: labelController,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: palette.text, fontWeight: FontWeight.w800),
          decoration: _inputDecoration('Goal name', palette),
        ),
        const SizedBox(height: 12),
        _MoneyField(
          controller: controller,
          label: 'Target amount (${wallet.currency})',
          palette: palette,
        ),
        const SizedBox(height: 12),
        _PrimaryButton(
          label: saving ? 'Saving...' : 'Save selected goal',
          icon: Icons.check_rounded,
          onPressed: saving ? null : onSave,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: saving ? null : onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add as new goal'),
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.text,
            side: BorderSide(color: palette.border),
            minimumSize: const Size.fromHeight(48),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        if (onCancel != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: saving ? null : onCancel,
            icon: const Icon(Icons.flag_circle_outlined),
            label: const Text('Cancel goal only'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE53935),
              side: const BorderSide(color: Color(0xFFE53935)),
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final GoshenWalletGoal goal;
  final bool selected;
  final _WalletPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFFFFC857).withValues(alpha: 0.18)
          : palette.soft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.label,
                          style: TextStyle(
                            color: palette.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${(goal.progress * 100).round()}% of ${_money(goal.targetAmount, goal.currency)}',
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.edit_rounded : Icons.chevron_right_rounded,
                    color: selected ? const Color(0xFF0C2230) : palette.muted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: goal.progress,
                  color: const Color(0xFFFFC857),
                  backgroundColor: palette.border,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopUpCard extends StatelessWidget {
  const _TopUpCard({
    required this.wallet,
    required this.palette,
    required this.amountController,
    required this.saving,
    required this.onTopUp,
  });

  final GoshenWallet wallet;
  final _WalletPalette palette;
  final TextEditingController amountController;
  final bool saving;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      palette: palette,
      title: 'Top up now',
      subtitle: 'Add money to your wallet securely with Stripe.',
      icon: Icons.add_card_outlined,
      children: [
        _MoneyField(
          controller: amountController,
          label: 'Amount (${wallet.currency})',
          palette: palette,
        ),
        const SizedBox(height: 12),
        _PrimaryButton(
          label: saving ? 'Starting checkout...' : 'Top up with Stripe',
          icon: Icons.lock_outline_rounded,
          onPressed: saving ? null : onTopUp,
        ),
      ],
    );
  }
}

class _VoucherTopUpCard extends StatelessWidget {
  const _VoucherTopUpCard({
    required this.wallet,
    required this.palette,
    required this.controller,
    required this.saving,
    required this.onApply,
  });

  final GoshenWallet wallet;
  final _WalletPalette palette;
  final TextEditingController controller;
  final bool saving;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      palette: palette,
      title: 'Top up with voucher',
      subtitle: 'Apply a wallet voucher code issued by Goshen admin.',
      icon: Icons.confirmation_number_outlined,
      children: [
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(color: palette.text, fontWeight: FontWeight.w800),
          decoration: _inputDecoration('Voucher code', palette),
        ),
        const SizedBox(height: 12),
        _PrimaryButton(
          label: saving ? 'Applying voucher...' : 'Apply voucher',
          icon: Icons.redeem_outlined,
          onPressed: saving ? null : onApply,
        ),
      ],
    );
  }
}

class _SavingsPlanCard extends StatelessWidget {
  const _SavingsPlanCard({
    required this.wallet,
    required this.palette,
    required this.amountController,
    required this.cyclesController,
    required this.frequency,
    required this.editingPlanId,
    required this.saving,
    required this.onFrequencyChanged,
    required this.onSave,
    required this.onNewPlan,
    required this.onEdit,
    required this.onSetup,
    required this.onToggle,
    required this.onCancel,
  });

  final GoshenWallet wallet;
  final _WalletPalette palette;
  final TextEditingController amountController;
  final TextEditingController cyclesController;
  final String frequency;
  final int? editingPlanId;
  final bool saving;
  final ValueChanged<String> onFrequencyChanged;
  final VoidCallback onSave;
  final VoidCallback onNewPlan;
  final ValueChanged<GoshenWalletSavingsPlan> onEdit;
  final ValueChanged<GoshenWalletSavingsPlan> onSetup;
  final void Function(GoshenWalletSavingsPlan plan, bool active) onToggle;
  final ValueChanged<GoshenWalletSavingsPlan> onCancel;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      palette: palette,
      title: 'Auto top-up plan',
      subtitle: 'Save a fixed amount daily, weekly, or monthly.',
      icon: Icons.autorenew_rounded,
      children: [
        _MoneyField(
          controller: amountController,
          label: 'Amount per top-up (${wallet.currency})',
          palette: palette,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: frequency,
          dropdownColor: palette.card,
          decoration: _inputDecoration('Frequency', palette),
          items: const [
            DropdownMenuItem(value: 'daily', child: Text('Daily')),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
          ],
          onChanged: (value) {
            if (value != null) onFrequencyChanged(value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cyclesController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: palette.text, fontWeight: FontWeight.w700),
          decoration: _inputDecoration('Number of top-ups (optional)', palette),
        ),
        const SizedBox(height: 12),
        _PrimaryButton(
          label: saving
              ? 'Saving plan...'
              : editingPlanId == null
                  ? 'Create auto top-up'
                  : 'Save selected plan',
          icon: Icons.schedule_rounded,
          onPressed: saving ? null : onSave,
        ),
        if (editingPlanId != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: saving ? null : onNewPlan,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create new plan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.text,
              side: BorderSide(color: palette.border),
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
        if (wallet.savingsPlans.isNotEmpty) ...[
          const SizedBox(height: 18),
          ...wallet.savingsPlans.map(
            (plan) => _PlanTile(
              plan: plan,
              palette: palette,
              selected: plan.id == editingPlanId,
              onEdit: () => onEdit(plan),
              onSetup: () => onSetup(plan),
              onToggle: () => onToggle(plan, plan.isActive),
              onCancel: () => onCancel(plan),
            ),
          ),
        ],
      ],
    );
  }
}

class _TransferActionCard extends StatelessWidget {
  const _TransferActionCard({
    required this.wallet,
    required this.palette,
    required this.onOpen,
  });

  final GoshenWallet wallet;
  final _WalletPalette palette;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      palette: palette,
      title: 'Transfer to a Member',
      subtitle: 'Open a focused transfer screen for member-to-member transfer.',
      icon: Icons.send_to_mobile_outlined,
      children: [
        Text(
          'Available to transfer: ${_money(wallet.balance, wallet.currency)}',
          style: TextStyle(
            color: palette.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        _PrimaryButton(
          label: 'Open transfer page',
          icon: Icons.arrow_forward_rounded,
          onPressed: onOpen,
        ),
      ],
    );
  }
}

class _WithdrawalLaunchCard extends StatelessWidget {
  const _WithdrawalLaunchCard({
    required this.wallet,
    required this.palette,
    required this.onOpen,
  });

  final GoshenWallet wallet;
  final _WalletPalette palette;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final openRequests =
        wallet.withdrawalRequests.where((request) => request.isOpen).length;
    return _SectionCard(
      palette: palette,
      title: 'Withdraw wallet funds',
      subtitle: 'Open a dedicated withdrawal request screen for admin review.',
      icon: Icons.account_balance_outlined,
      children: [
        Text(
          'Available to withdraw: ${_money(wallet.balance, wallet.currency)}',
          style: TextStyle(color: palette.muted, fontWeight: FontWeight.w800),
        ),
        if (openRequests > 0) ...[
          const SizedBox(height: 6),
          Text(
            '$openRequests active withdrawal request${openRequests == 1 ? '' : 's'}',
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _PrimaryButton(
          label: 'Open withdrawal page',
          icon: Icons.outbox_outlined,
          onPressed: onOpen,
        ),
      ],
    );
  }
}

class _WithdrawalRequestCard extends StatelessWidget {
  const _WithdrawalRequestCard({
    required this.wallet,
    required this.palette,
    required this.amountController,
    required this.bankController,
    required this.accountNameController,
    required this.accountNumberController,
    required this.sortCodeController,
    required this.ibanController,
    required this.noteController,
    required this.saving,
    required this.onSubmit,
    required this.onCancel,
  });

  final GoshenWallet wallet;
  final _WalletPalette palette;
  final TextEditingController amountController;
  final TextEditingController bankController;
  final TextEditingController accountNameController;
  final TextEditingController accountNumberController;
  final TextEditingController sortCodeController;
  final TextEditingController ibanController;
  final TextEditingController noteController;
  final bool saving;
  final VoidCallback onSubmit;
  final ValueChanged<GoshenWalletWithdrawalRequest> onCancel;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      palette: palette,
      title: 'Withdraw wallet funds',
      subtitle:
          'Submit a withdrawal request for admin review. Funds are reserved while pending.',
      icon: Icons.account_balance_outlined,
      children: [
        Text(
          'Available: ${_money(wallet.balance, wallet.currency)}',
          style: TextStyle(color: palette.muted, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _MoneyField(
          controller: amountController,
          label: 'Amount (${wallet.currency})',
          palette: palette,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: bankController,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: palette.text, fontWeight: FontWeight.w800),
          decoration: _inputDecoration('Bank name', palette),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: accountNameController,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: palette.text, fontWeight: FontWeight.w800),
          decoration: _inputDecoration('Account name', palette),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: accountNumberController,
          keyboardType: TextInputType.text,
          style: TextStyle(color: palette.text, fontWeight: FontWeight.w800),
          decoration: _inputDecoration('Account number', palette),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: sortCodeController,
                style:
                    TextStyle(color: palette.text, fontWeight: FontWeight.w800),
                decoration: _inputDecoration('Sort code', palette),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: ibanController,
                style:
                    TextStyle(color: palette.text, fontWeight: FontWeight.w800),
                decoration: _inputDecoration('IBAN', palette),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: noteController,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: palette.text, fontWeight: FontWeight.w800),
          decoration: _inputDecoration('Note for admin (optional)', palette),
        ),
        const SizedBox(height: 12),
        _PrimaryButton(
          label: saving ? 'Submitting...' : 'Submit withdrawal request',
          icon: Icons.outbox_outlined,
          onPressed: saving ? null : onSubmit,
        ),
        if (wallet.withdrawalRequests.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Recent withdrawal requests',
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...wallet.withdrawalRequests.take(5).map(
                (request) => _WithdrawalRequestTile(
                  request: request,
                  palette: palette,
                  saving: saving,
                  onCancel: request.isPending ? () => onCancel(request) : null,
                ),
              ),
        ],
      ],
    );
  }
}

class _WithdrawalRequestTile extends StatelessWidget {
  const _WithdrawalRequestTile({
    required this.request,
    required this.palette,
    required this.saving,
    this.onCancel,
  });

  final GoshenWalletWithdrawalRequest request;
  final _WalletPalette palette;
  final bool saving;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _money(request.amount, request.currency),
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${request.status} - ${request.bankName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onCancel != null)
            TextButton(
              onPressed: saving ? null : onCancel,
              child: const Text('Cancel'),
            ),
        ],
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({
    required this.wallet,
    required this.palette,
    required this.onEntryTap,
  });

  final GoshenWallet wallet;
  final _WalletPalette palette;
  final ValueChanged<GoshenWalletLedgerEntry> onEntryTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      palette: palette,
      title: 'Recent activity',
      subtitle: 'Wallet top-ups and retreat payment movements.',
      icon: Icons.receipt_long_outlined,
      children: wallet.ledger.isEmpty
          ? [
              Text(
                'No wallet activity yet.',
                style: TextStyle(
                  color: palette.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]
          : wallet.ledger
              .take(8)
              .map((entry) => _LedgerTile(
                    entry: entry,
                    palette: palette,
                    onTap: () => onEntryTap(entry),
                  ))
              .toList(),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final _WalletPalette palette;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.18 : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC857).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: const Color(0xFFFFC857)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.muted,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.controller,
    required this.label,
    required this.palette,
  });

  final TextEditingController controller;
  final String label;
  final _WalletPalette palette;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: palette.text, fontWeight: FontWeight.w800),
      decoration: _inputDecoration(label, palette),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFB522),
          foregroundColor: MyColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final _WalletPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: palette.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? 'Not available' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.palette,
    required this.selected,
    required this.onEdit,
    required this.onSetup,
    required this.onToggle,
    required this.onCancel,
  });

  final GoshenWalletSavingsPlan plan;
  final _WalletPalette palette;
  final bool selected;
  final VoidCallback onEdit;
  final VoidCallback onSetup;
  final VoidCallback onToggle;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final canManage = plan.status != 'cancelled' && plan.status != 'completed';
    final next = plan.nextChargeAt == null
        ? 'Next date pending'
        : 'Next: ${_dateTimeLabel(plan.nextChargeAt)}';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFFFC857).withValues(alpha: 0.18)
            : palette.soft,
        borderRadius: BorderRadius.circular(18),
        border: selected ? Border.all(color: const Color(0xFFFFC857)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_money(plan.amount, plan.currency)} ${plan.frequency}',
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$next • ${plan.status.replaceAll('_', ' ')}',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (canManage)
                TextButton(
                  onPressed: onEdit,
                  child: Text(selected ? 'Editing' : 'Edit'),
                ),
              if (plan.needsSetup)
                TextButton(
                  onPressed: onSetup,
                  child: const Text('Set up card'),
                )
              else if (canManage)
                TextButton(
                  onPressed: onToggle,
                  child: Text(plan.isActive ? 'Pause' : 'Resume'),
                ),
              if (canManage)
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                  ),
                  child: const Text('Cancel'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({
    required this.entry,
    required this.palette,
    required this.onTap,
  });

  final GoshenWalletLedgerEntry entry;
  final _WalletPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final positive = entry.direction != 'debit';
    final occurredAt = entry.settledAt ?? entry.createdAt;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: palette.soft,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Icon(
                  positive
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: positive
                      ? const Color(0xFF2C9B88)
                      : const Color(0xFFE55353),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.description.isEmpty
                            ? entry.type.replaceAll('_', ' ')
                            : entry.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          entry.status.replaceAll('_', ' '),
                          _dateTimeLabel(occurredAt),
                        ].where((part) => part.trim().isNotEmpty).join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${positive ? '+' : '-'}${_money(entry.amount, entry.currency)}',
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: palette.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestState extends StatelessWidget {
  const _GuestState({required this.palette});

  final _WalletPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Please sign in to view your Goshen savings wallet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.text, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.palette,
    required this.message,
    required this.onRetry,
  });

  final _WalletPalette palette;
  final String message;
  final VoidCallback onRetry;

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
              style:
                  TextStyle(color: palette.text, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label, _WalletPalette palette) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: palette.muted, fontWeight: FontWeight.w700),
    filled: true,
    fillColor: palette.soft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: palette.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: palette.border),
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

String _dateTimeLabel(DateTime? value) {
  if (value == null) return '';
  return DateFormat('MMM d, y h:mm a').format(value.toLocal());
}

String _plainAmount(double amount) {
  return amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
}

class _WalletGraphic extends CustomPainter {
  const _WalletGraphic();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFFFC857).withValues(alpha: 0.16);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.055);

    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.14), 86, fill);
    canvas.drawCircle(
        Offset(size.width * 0.88, size.height * 0.14), 124, paint);

    final path = Path()
      ..moveTo(size.width * 0.56, size.height * 0.78)
      ..cubicTo(size.width * 0.66, size.height * 0.48, size.width * 0.84,
          size.height * 1.02, size.width * 1.04, size.height * 0.66);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WalletGraphic oldDelegate) => false;
}

class _WalletPalette {
  const _WalletPalette({
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

  static _WalletPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _WalletPalette(
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
