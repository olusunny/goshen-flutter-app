import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/LoginScreen.dart';
import '../models/GoshenWallet.dart';
import '../providers/AppStateManager.dart';
import '../service/GivingStatusApi.dart';
import '../service/GoshenWalletApi.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';
import '../wallet_security/wallet_security_guard.dart';

class DonationAccountsScreen extends StatefulWidget {
  const DonationAccountsScreen({super.key});

  static const routeName = '/donation-accounts';

  @override
  State<DonationAccountsScreen> createState() => _DonationAccountsScreenState();
}

class _DonationAccountsScreenState extends State<DonationAccountsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _secureRandom = Random.secure();

  bool _loadingStatus = true;
  bool _enabled = false;
  bool _configured = false;
  bool _walletEnabled = false;
  bool _submitting = false;
  bool _walletSubmitting = false;
  String _currency = 'NGN';
  List<_GivingCategory> _categories = [];
  int? _selectedCategoryId;
  String? _walletIdempotencyKey;
  String? _walletIdempotencyFingerprint;

  static const _primary = Color(0xFF0C2230);
  static const _gold = Color(0xFFFFB82E);
  static const _surface = Color(0xFFF4F8FA);

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';
    _phoneController.text = user?.phone ?? '';
    final cached = GivingStatusApi().cachedStatus;
    if (cached != null) {
      _applyStatusData(cached);
      _loadingStatus = false;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _loadStatus(silent: true));
    } else {
      _loadStatus();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus({bool silent = false}) async {
    if (!silent) setState(() => _loadingStatus = true);
    try {
      final data = await GivingStatusApi().fetchStatus();
      if (!mounted) return;
      setState(() {
        _applyStatusData(data);
        _loadingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _configured = false;
        _walletEnabled = false;
        _loadingStatus = false;
      });
    }
  }

  void _applyStatusData(Map<String, dynamic> data) {
    final categories = (data['categories'] as List? ?? [])
        .whereType<Map>()
        .map(
            (item) => _GivingCategory.fromJson(Map<String, dynamic>.from(item)))
        .where((category) => category.id > 0 && category.name.isNotEmpty)
        .toList();

    _enabled = _readBool(data['enabled']);
    _configured = _readBool(data['configured']);
    _walletEnabled = _readBool(data['wallet_enabled']);
    _currency = (data['currency'] ?? 'NGN').toString().toUpperCase();
    _categories = categories;
    _selectedCategoryId = _selectedCategoryId != null &&
            categories.any((item) => item.id == _selectedCategoryId)
        ? _selectedCategoryId
        : null;
  }

  Future<void> _startGiving() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting || _walletSubmitting) return;
    setState(() => _submitting = true);

    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    final token = (user?.apiToken ?? '').trim();

    try {
      final response = await Dio().post(
        ApiUrl.GIVING_STRIPE_CHECKOUT,
        data: jsonEncode({
          'data': {
            if (token.isNotEmpty) 'api_token': token,
            'amount': _amountController.text.trim(),
            'currency': _currency,
            'donation_category_id': _selectedCategoryId,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'purpose': _selectedCategory?.name ?? 'Goshen Retreat Giving',
          },
        }),
      );

      final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
      if (data['status'] != 'ok') {
        _showMessage(data['message']?.toString() ?? 'Unable to start giving.');
        return;
      }

      final checkout =
          Map<String, dynamic>.from(data['checkout'] as Map? ?? {});
      final url = (checkout['checkout_url'] ?? '').toString().trim();
      if (url.isEmpty) {
        _showMessage(
            'Secure checkout is not available yet. Please contact the church office.');
        return;
      }

      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;
      if (!launched) {
        _showMessage(
            'Could not open the secure payment page. Please try again.');
        return;
      }

      await _showGivingDialog(
        title: 'Complete giving securely',
        message:
            'Stripe Checkout has opened in your browser. After completing payment, return to the app. Your gift will be recorded automatically once Stripe confirms it.',
      );
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map ? body['message']?.toString() : null;
      _showMessage(message ?? 'Unable to start secure giving right now.');
    } catch (_) {
      _showMessage('Unable to start secure giving right now.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _startWalletGiving() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting || _walletSubmitting) return;

    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null || (user.apiToken ?? '').trim().isEmpty) {
      _showWalletLoginPrompt();
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount < 1) {
      _showMessage('Enter an amount of at least 1 $_currency.');
      return;
    }

    setState(() => _walletSubmitting = true);

    try {
      final unlocked = await WalletSecurityGuard.ensureWalletUnlocked(
        context,
        requireFreshVerification: true,
      );
      if (!unlocked || !mounted) return;

      final wallet = await GoshenWalletApi().fetchWallet(user);
      final walletCurrency = wallet.currency.trim().toUpperCase();
      final givingCurrency = _currency.trim().toUpperCase();
      if (walletCurrency != givingCurrency) {
        _showMessage(
          'Your wallet is in $walletCurrency, but this giving is in $givingCurrency.',
        );
        return;
      }

      if (wallet.balance + 0.01 < amount) {
        _showMessage(
          'Your wallet balance is ${_formatMoney(wallet.balance, walletCurrency)}.',
        );
        return;
      }

      final confirmed = await _confirmWalletGiving(wallet, amount);
      if (confirmed != true || !mounted) return;

      final idempotencyKey = _walletRequestKey(amount);
      final token = (user.apiToken ?? '').trim();
      final response = await Dio().post(
        ApiUrl.GIVING_WALLET_PAY,
        options: Options(
          validateStatus: (status) => status != null && status < 600,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        ),
        data: jsonEncode({
          'data': {
            'amount': amount,
            'currency': _currency,
            'donation_category_id': _selectedCategoryId,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'purpose': _selectedCategory?.name ?? 'Goshen Retreat Giving',
            'idempotency_key': idempotencyKey,
          },
        }),
      );

      final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
      if (data['status'] != 'ok') {
        _showMessage(
          data['message']?.toString() ?? 'Unable to complete wallet giving.',
        );
        return;
      }

      _amountController.clear();
      _walletIdempotencyKey = null;
      _walletIdempotencyFingerprint = null;
      await _showGivingDialog(
        title: 'Wallet giving complete',
        message: data['message']?.toString() ??
            'Your giving has been recorded from your wallet.',
      );
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map ? body['message']?.toString() : null;
      _showMessage(message ?? 'Unable to complete wallet giving right now.');
    } catch (error) {
      final text = error.toString().replaceFirst('Exception: ', '').trim();
      _showMessage(
        text.isEmpty ? 'Unable to complete wallet giving right now.' : text,
      );
    } finally {
      if (mounted) setState(() => _walletSubmitting = false);
    }
  }

  Future<bool?> _confirmWalletGiving(
    GoshenWallet wallet,
    double amount,
  ) async {
    final currency = wallet.currency.trim().toUpperCase();
    final balanceAfter = wallet.balance - amount;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Give from wallet?'),
        content: Text(
          'We will deduct ${_formatMoney(amount, currency)} from your Goshen wallet.\n\n'
          'Current balance: ${_formatMoney(wallet.balance, currency)}\n'
          'Balance after giving: ${_formatMoney(balanceAfter, currency)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF061721) : _surface;
    final cardColor = isDark ? const Color(0xFF0E2A38) : Colors.white;
    final textColor = isDark ? Colors.white : _primary;
    final softText = isDark ? Colors.white70 : const Color(0xFF66737D);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(title: const Text('Giving')),
      body: RefreshIndicator(
        onRefresh: _loadStatus,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 36),
          children: [
            _GivingHero(textColor: textColor, softText: softText),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.18 : 0.07),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(22),
              child: _loadingStatus
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _buildContent(textColor, softText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Color textColor, Color softText) {
    if (!_enabled) {
      return _NoticeState(
        icon: Icons.volunteer_activism_rounded,
        title: 'Online giving is not available',
        message:
            'The church team has temporarily disabled online giving for this app. Please check back later.',
        textColor: textColor,
        softText: softText,
      );
    }

    if (!_configured && !_walletEnabled) {
      return _NoticeState(
        icon: Icons.settings_suggest_rounded,
        title: 'Giving payment options are being prepared',
        message:
            'Online giving is enabled, but the payment options still need configuration. Please contact the church office if you need to give immediately.',
        textColor: textColor,
        softText: softText,
      );
    }

    if (_categories.isEmpty) {
      return _NoticeState(
        icon: Icons.category_rounded,
        title: 'Giving categories are not ready',
        message:
            'The church team needs to activate at least one Giving category before online giving can start.',
        textColor: textColor,
        softText: softText,
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Give securely',
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _paymentIntroText,
            style: TextStyle(color: softText, fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 22),
          _GivingTextField(
            controller: _amountController,
            label: 'Amount ($_currency)',
            icon: Icons.payments_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final amount = double.tryParse((value ?? '').trim());
              if (amount == null || amount < 1) {
                return 'Enter an amount of at least 1 $_currency.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _GivingCategoryField(
            value: _selectedCategoryId,
            categories: _categories,
            onChanged: (value) => setState(() => _selectedCategoryId = value),
          ),
          const SizedBox(height: 14),
          _GivingTextField(
            controller: _nameController,
            label: 'Full name',
            icon: Icons.person_rounded,
            validator: (value) {
              if ((value ?? '').trim().length < 2) {
                return 'Enter your full name.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _GivingTextField(
            controller: _emailController,
            label: 'Email address',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty || !text.contains('@')) {
                return 'Enter a valid email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _GivingTextField(
            controller: _phoneController,
            label: 'Phone number',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
              if (digits.length < 7) {
                return 'Enter your phone number.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          if (_configured) _stripeButton(),
          if (_configured && _walletEnabled) const SizedBox(height: 12),
          if (_walletEnabled) _walletButton(),
        ],
      ),
    );
  }

  Widget _stripeButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: (_submitting || _walletSubmitting) ? null : _startGiving,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock_rounded),
        label: Text(_submitting ? 'Starting checkout...' : 'Give with Stripe'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _primary,
          disabledBackgroundColor: _gold.withOpacity(0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _walletButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed:
            (_submitting || _walletSubmitting) ? null : _startWalletGiving,
        icon: _walletSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.account_balance_wallet_rounded),
        label: Text(
          _walletSubmitting ? 'Processing wallet gift...' : 'Give from wallet',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF14513F),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF14513F).withOpacity(0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  String get _paymentIntroText {
    if (_configured && _walletEnabled) {
      return 'Use Stripe Checkout as a visitor or signed-in member. Goshen wallet gifts require sign-in and a fresh wallet unlock before funds are deducted.';
    }

    if (_walletEnabled) {
      return 'Goshen wallet gifts require sign-in and a fresh wallet unlock before funds are deducted.';
    }

    return 'Use Stripe Checkout as a visitor or signed-in member. Your gift is recorded once payment is confirmed.';
  }

  _GivingCategory? get _selectedCategory {
    for (final category in _categories) {
      if (category.id == _selectedCategoryId) return category;
    }

    return _categories.isNotEmpty ? _categories.first : null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showGivingDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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

  Future<void> _showWalletLoginPrompt() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Sign in for wallet giving'),
        content: const Text(
          'Stripe giving is open to visitors. Please sign in before giving from your Goshen wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
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

  String _formatMoney(double value, String currency) {
    return '$currency ${value.toStringAsFixed(2)}';
  }

  String _walletRequestKey(double amount) {
    final fingerprint = [
      amount.toStringAsFixed(2),
      _currency.trim().toUpperCase(),
      _selectedCategoryId?.toString() ?? '',
    ].join('|');

    if (_walletIdempotencyKey == null ||
        _walletIdempotencyFingerprint != fingerprint) {
      final bytes = List<int>.generate(
        16,
        (_) => _secureRandom.nextInt(256),
      );
      _walletIdempotencyKey =
          '${DateTime.now().microsecondsSinceEpoch}-${base64UrlEncode(bytes)}';
      _walletIdempotencyFingerprint = fingerprint;
    }

    return _walletIdempotencyKey!;
  }
}

class _GivingHero extends StatelessWidget {
  const _GivingHero({required this.textColor, required this.softText});

  final Color textColor;
  final Color softText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C2230), Color(0xFF0E4B3D)],
        ),
      ),
      padding: const EdgeInsets.all(22),
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: -22,
            child: Icon(
              Icons.volunteer_activism_rounded,
              size: 128,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFFB82E),
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Giving',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Support Goshen Retreat and church ministry securely.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
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

class _GivingTextField extends StatelessWidget {
  const _GivingTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _GivingCategoryField extends StatelessWidget {
  const _GivingCategoryField({
    required this.value,
    required this.categories,
    required this.onChanged,
  });

  final int? value;
  final List<_GivingCategory> categories;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    const menuItemHeight = 84.0;

    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      itemHeight: menuItemHeight,
      menuMaxHeight: MediaQuery.sizeOf(context).height * 0.55,
      selectedItemBuilder: (context) => categories
          .map(
            (category) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          )
          .toList(),
      items: categories
          .map(
            (category) => DropdownMenuItem<int>(
              value: category.id,
              child: SizedBox(
                height: menuItemHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (category.description.isNotEmpty)
                      Text(
                        category.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.62),
                          fontSize: 12,
                          height: 1.15,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
      validator: (value) =>
          value == null ? 'Please select a Giving category.' : null,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Giving category',
        prefixIcon: const Icon(Icons.favorite_rounded),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _NoticeState extends StatelessWidget {
  const _NoticeState({
    required this.icon,
    required this.title,
    required this.message,
    required this.textColor,
    required this.softText,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color textColor;
  final Color softText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFFFB82E).withOpacity(0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFFFB82E), size: 34),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: softText, height: 1.5, fontSize: 15),
        ),
      ],
    );
  }
}

class _GivingCategory {
  const _GivingCategory({
    required this.id,
    required this.name,
    required this.description,
  });

  final int id;
  final String name;
  final String description;

  factory _GivingCategory.fromJson(Map<String, dynamic> json) {
    return _GivingCategory(
      id: int.tryParse((json['id'] ?? '').toString()) ?? 0,
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

bool _readBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  final text = value.toString().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes';
}
