import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../auth/LoginScreen.dart';
import '../../models/GoshenWallet.dart';
import '../../providers/AppStateManager.dart';
import '../../service/GoshenWalletApi.dart';
import '../../wallet_security/wallet_security_guard.dart';
import 'fundraising_api.dart';
import 'fundraising_models.dart';

const _primary = Color(0xFF0C2230);
const _gold = Color(0xFFFFB82E);
const _page = Color(0xFFF4F8FA);
const _muted = Color(0xFF64727D);
const _line = Color(0xFFE3EAEE);

class FundraisingScreen extends StatefulWidget {
  const FundraisingScreen({super.key});

  static const routeName = '/fundraising';

  @override
  State<FundraisingScreen> createState() => _FundraisingScreenState();
}

class _FundraisingScreenState extends State<FundraisingScreen> {
  final _api = FundraisingApi();
  final _walletApi = GoshenWalletApi();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  final _random = Random.secure();

  FundraisingCampaign? _campaign;
  Timer? _countdownTimer;
  Duration _serverOffset = Duration.zero;
  bool _loading = true;
  bool _submitting = false;
  bool _checkoutSubmitting = false;
  bool _anonymous = false;
  bool _sheetOpen = false;
  bool _refreshedAfterCountdown = false;
  int _selectedTab = 0;
  String? _error;
  String? _idempotencyKey;
  String? _idempotencyFingerprint;
  String? _checkoutIdempotencyKey;
  String? _checkoutIdempotencyFingerprint;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    final cached = _api.cachedActiveCampaign;
    if (cached != null) {
      _setCampaign(cached.hasActiveCampaign ? cached.campaign : null);
      _loading = false;
    }
    _loadCampaign();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final campaign = _campaign;
      if (!mounted || campaign?.endAt == null) return;

      final remaining = _remainingDuration(campaign!);
      if (remaining == Duration.zero && !_refreshedAfterCountdown) {
        _refreshedAfterCountdown = true;
        _loadCampaign();
        return;
      }

      setState(() {});
    });
  }

  Future<void> _loadCampaign() async {
    if (_campaign == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }

    try {
      final response = await _api.fetchActiveCampaign();
      if (!mounted) return;
      setState(() {
        _setCampaign(response.hasActiveCampaign ? response.campaign : null);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '').trim();
        _loading = false;
      });
    }
  }

  void _setCampaign(FundraisingCampaign? campaign) {
    _campaign = campaign;
    _refreshedAfterCountdown = false;
    if (campaign?.serverTime != null) {
      _serverOffset =
          campaign!.serverTime!.toUtc().difference(DateTime.now().toUtc());
    }
  }

  Future<void> _openContributionSheet() async {
    final campaign = _campaign;
    if (campaign == null || _sheetOpen) return;

    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: _ContributionForm(
                  amountController: _amountController,
                  messageController: _messageController,
                  anonymous: _anonymous,
                  walletEnabled: campaign.paymentOptions.walletEnabled,
                  cardCheckoutEnabled:
                      campaign.paymentOptions.cardCheckoutEnabled,
                  walletSubmitting: _submitting,
                  checkoutSubmitting: _checkoutSubmitting,
                  currency: campaign.currency,
                  onAnonymousChanged: (value) {
                    setState(() => _anonymous = value);
                  },
                  onWalletSubmit: _submitContribution,
                  onCheckoutSubmit: _startCardCheckout,
                ),
              ),
            ),
          ),
        );
      },
    );
    _sheetOpen = false;
  }

  Future<void> _submitContribution() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;

    final campaign = _campaign;
    if (campaign == null) {
      _showMessage('There is no active project support campaign right now.');
      return;
    }
    if (!campaign.canContribute) {
      _showMessage(
          'This project support campaign is not accepting contributions.');
      return;
    }

    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null || (user.apiToken ?? '').trim().isEmpty) {
      _showMessage('Please sign in before contributing from your wallet.');
      Navigator.pushNamed(context, LoginScreen.routeName);
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount < 1) {
      _showMessage('Enter an amount of at least 1 ${campaign.currency}.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final unlocked = await WalletSecurityGuard.ensureWalletUnlocked(
        context,
        requireFreshVerification: true,
      );
      if (!unlocked || !mounted) return;

      final wallet = await _walletApi.fetchWallet(user);
      final campaignCurrency = campaign.currency.trim().toUpperCase();
      final walletCurrency = wallet.currency.trim().toUpperCase();
      if (campaignCurrency != walletCurrency) {
        _showMessage(
          'Your wallet is in $walletCurrency, but this campaign is in $campaignCurrency.',
        );
        return;
      }

      if (wallet.balance + 0.01 < amount) {
        _showMessage(
          'Your wallet balance is ${_formatMoney(wallet.balance, walletCurrency)}.',
        );
        return;
      }

      final confirmed = await _confirmContribution(wallet, amount, campaign);
      if (confirmed != true || !mounted) return;

      final result = await _api.contributeFromWallet(
        user: user,
        campaign: campaign,
        amount: amount,
        idempotencyKey: _requestKey(campaign, amount, 'wallet'),
        message: _messageController.text,
        anonymous: _anonymous,
      );

      if (!mounted) return;
      setState(() {
        _setCampaign(result.campaign);
        _idempotencyKey = null;
        _idempotencyFingerprint = null;
      });
      _amountController.clear();
      _messageController.clear();
      if (_sheetOpen && mounted) {
        Navigator.of(context).pop();
      }
      await Future<void>.delayed(const Duration(milliseconds: 160));
      if (mounted) await _showSuccess(result);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      _showMessage(
        message.isEmpty
            ? 'Unable to complete this contribution right now.'
            : message,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _startCardCheckout() async {
    if (_checkoutSubmitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final campaign = _campaign;
    if (campaign == null) {
      _showMessage('There is no active project support campaign right now.');
      return;
    }
    if (!campaign.canContribute) {
      _showMessage(
          'This project support campaign is not accepting contributions.');
      return;
    }

    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null || (user.apiToken ?? '').trim().isEmpty) {
      _showMessage('Please sign in before starting secure checkout.');
      Navigator.pushNamed(context, LoginScreen.routeName);
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount < 1) {
      _showMessage('Enter an amount of at least 1 ${campaign.currency}.');
      return;
    }

    setState(() => _checkoutSubmitting = true);

    try {
      final result = await _api.createStripeCheckout(
        user: user,
        campaign: campaign,
        amount: amount,
        idempotencyKey: _requestKey(campaign, amount, 'stripe'),
        message: _messageController.text,
        anonymous: _anonymous,
      );

      final url = result.checkout.checkoutUrl.trim();
      if (url.isEmpty) {
        throw Exception('Secure checkout is not available right now.');
      }

      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;
      if (!launched) {
        throw Exception('Could not open the secure payment page.');
      }

      if (result.campaign != null) {
        setState(() => _setCampaign(result.campaign));
      }

      _checkoutIdempotencyKey = null;
      _checkoutIdempotencyFingerprint = null;

      if (_sheetOpen && mounted) {
        Navigator.of(context).pop();
      }

      await Future<void>.delayed(const Duration(milliseconds: 160));
      if (mounted) {
        await _showCheckoutStarted(result);
      }
    } catch (error) {
      _checkoutIdempotencyKey = null;
      _checkoutIdempotencyFingerprint = null;
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      _showMessage(
        message.isEmpty
            ? 'Unable to start secure checkout right now.'
            : message,
      );
    } finally {
      if (mounted) setState(() => _checkoutSubmitting = false);
    }
  }

  Future<bool?> _confirmContribution(
    GoshenWallet wallet,
    double amount,
    FundraisingCampaign campaign,
  ) {
    final balanceAfter = wallet.balance - amount;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Contribute from wallet?'),
        content: Text(
          'We will deduct ${_formatMoney(amount, campaign.currency)} from your Goshen wallet.\n\n'
          'Current balance: ${_formatMoney(wallet.balance, wallet.currency)}\n'
          'Balance after contribution: ${_formatMoney(balanceAfter, wallet.currency)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _primary,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccess(FundraisingContributionResult result) {
    final wallet = result.wallet;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Contribution recorded'),
        content: Text(
          wallet == null
              ? result.message
              : '${result.message}\n\nWallet balance: ${_formatMoney(wallet.balance, wallet.currency)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCheckoutStarted(FundraisingCheckoutResult result) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Complete support securely'),
        content: Text(
          '${result.message}\n\nAfter completing checkout, return to the app. Your support will appear once the payment gateway confirms it.',
        ),
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
    final campaign = _campaign;
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        title: const Text('Project support'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: _gold,
        onRefresh: _loadCampaign,
        child: _buildBody(context),
      ),
      bottomNavigationBar: campaign == null || _loading
          ? null
          : _SupportBar(
              enabled: campaign.canContribute &&
                  !_submitting &&
                  !_checkoutSubmitting &&
                  campaign.paymentOptions.hasAnyMethod,
              label: campaign.ctaLabel,
              submitting: _submitting || _checkoutSubmitting,
              onPressed: _openContributionSheet,
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return ListView(
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return _StateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load project support',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadCampaign,
      );
    }

    final campaign = _campaign;
    if (campaign == null) {
      return _StateMessage(
        icon: Icons.campaign_outlined,
        title: 'No active campaign',
        message: 'There is no active project support campaign at the moment.',
        actionLabel: 'Refresh',
        onAction: _loadCampaign,
      );
    }

    final remaining = _remainingDuration(campaign);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 118),
      children: [
        _CampaignTitleBlock(campaign: campaign),
        const SizedBox(height: 16),
        _CampaignMediaHero(media: campaign.media),
        const SizedBox(height: 16),
        _OrganizerRow(campaign: campaign),
        const SizedBox(height: 18),
        _CampaignTabs(
          selectedIndex: _selectedTab,
          onChanged: (index) => setState(() => _selectedTab = index),
        ),
        const SizedBox(height: 16),
        _CampaignTabContent(
          campaign: campaign,
          selectedIndex: _selectedTab,
          onPlayYoutube: _openYoutube,
        ),
        const SizedBox(height: 20),
        _CountdownStrip(remaining: remaining),
        const SizedBox(height: 20),
        _FundingProgress(campaign: campaign),
        const SizedBox(height: 20),
        _RecentContributions(campaign: campaign),
      ],
    );
  }

  Duration _remainingDuration(FundraisingCampaign campaign) {
    final endAt = campaign.endAt;
    if (endAt == null) return Duration.zero;
    final serverNow = DateTime.now().toUtc().add(_serverOffset);
    final remaining = endAt.toUtc().difference(serverNow);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _openYoutube(String videoId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => SafeArea(
        child: _YoutubePlayerPanel(videoId: videoId),
      ),
    );
  }

  String _requestKey(
    FundraisingCampaign campaign,
    double amount,
    String paymentMethod,
  ) {
    final fingerprint = [
      paymentMethod,
      campaign.id,
      amount.toStringAsFixed(2),
      _anonymous,
      _messageController.text.trim(),
    ].join('|');

    if (paymentMethod == 'stripe') {
      if (_checkoutIdempotencyFingerprint == fingerprint &&
          _checkoutIdempotencyKey != null) {
        return _checkoutIdempotencyKey!;
      }

      final key = _newIdempotencyKey('fundraising-stripe');
      _checkoutIdempotencyFingerprint = fingerprint;
      _checkoutIdempotencyKey = key;
      return key;
    }

    if (_idempotencyFingerprint == fingerprint && _idempotencyKey != null) {
      return _idempotencyKey!;
    }

    final key = _newIdempotencyKey('fundraising-wallet');
    _idempotencyFingerprint = fingerprint;
    _idempotencyKey = key;
    return key;
  }

  String _newIdempotencyKey(String prefix) {
    final nonce = List.generate(
      12,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$nonce';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _CampaignTitleBlock extends StatelessWidget {
  const _CampaignTitleBlock({required this.campaign});

  final FundraisingCampaign campaign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (campaign.cause.trim().isNotEmpty)
          Text(
            campaign.cause.trim().toUpperCase(),
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          campaign.title,
          style: const TextStyle(
            color: _primary,
            fontSize: 28,
            height: 1.12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        if (campaign.shortDescription.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            campaign.shortDescription,
            style: const TextStyle(
              color: _muted,
              fontSize: 16,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _CampaignMediaHero extends StatelessWidget {
  const _CampaignMediaHero({required this.media});

  final List<FundraisingCampaignMedia> media;

  @override
  Widget build(BuildContext context) {
    final hero = _primaryMedia();
    if (hero == null) return const SizedBox.shrink();

    final child = hero.hasVisualPreview
        ? CachedNetworkImage(
            imageUrl: hero.previewUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => _MediaPlaceholder(media: hero),
            errorWidget: (_, __, ___) => _MediaPlaceholder(media: hero),
          )
        : _MediaPlaceholder(media: hero);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (hero.isYoutube)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openYoutube(context, hero.youtubeVideoId),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 26, 14, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xA6000000)],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hero.isYoutube
                          ? Icons.play_circle_outline
                          : hero.isAudio
                              ? Icons.graphic_eq
                              : Icons.image_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hero.title.trim().isNotEmpty
                            ? hero.title.trim()
                            : hero.mediaLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  FundraisingCampaignMedia? _primaryMedia() {
    for (final item in media) {
      if (item.hasVisualPreview || item.isAudio) return item;
    }
    return media.isEmpty ? null : media.first;
  }

  void _openYoutube(BuildContext context, String videoId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => SafeArea(
        child: _YoutubePlayerPanel(videoId: videoId),
      ),
    );
  }
}

class _OrganizerRow extends StatelessWidget {
  const _OrganizerRow({required this.campaign});

  final FundraisingCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final started = campaign.startAt == null
        ? 'Active now'
        : DateFormat('d MMM yyyy').format(campaign.startAt!.toLocal());

    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: _gold,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified_user_outlined,
              color: _primary, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _InlineMeta(
                      icon: Icons.calendar_today_outlined, text: started),
                  if (campaign.cause.trim().isNotEmpty)
                    _InlineMeta(
                      icon: Icons.location_on_outlined,
                      text: campaign.cause.trim(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _CampaignTabs extends StatelessWidget {
  const _CampaignTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const _tabs = ['Description', 'Supporters', 'Media'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < _tabs.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        _tabs[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 3,
                        width: selectedIndex == index ? 52 : 0,
                        decoration: BoxDecoration(
                          color: _gold,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CampaignTabContent extends StatelessWidget {
  const _CampaignTabContent({
    required this.campaign,
    required this.selectedIndex,
    required this.onPlayYoutube,
  });

  final FundraisingCampaign campaign;
  final int selectedIndex;
  final ValueChanged<String> onPlayYoutube;

  @override
  Widget build(BuildContext context) {
    if (selectedIndex == 1) {
      return _SupportersPanel(campaign: campaign);
    }
    if (selectedIndex == 2) {
      return _MediaGallery(media: campaign.media, onPlayYoutube: onPlayYoutube);
    }

    final description = campaign.description.trim().isNotEmpty
        ? campaign.description.trim()
        : campaign.shortDescription.trim();

    return Text(
      description.isEmpty
          ? 'Campaign details will appear here once the team adds a description.'
          : description,
      style: const TextStyle(
        color: Color(0xFF1D252C),
        fontSize: 17,
        height: 1.55,
        letterSpacing: 0,
      ),
    );
  }
}

class _CountdownStrip extends StatelessWidget {
  const _CountdownStrip({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    if (remaining == Duration.zero) {
      return const _SoftNotice(
        icon: Icons.timer_off_outlined,
        title: 'Campaign time has ended',
        message: 'Refresh to see the latest campaign status.',
      );
    }

    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Time left',
          style: TextStyle(
            color: _primary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _CountdownTile(value: days, label: 'Days')),
            const SizedBox(width: 10),
            Expanded(child: _CountdownTile(value: hours, label: 'Hours')),
            const SizedBox(width: 10),
            Expanded(child: _CountdownTile(value: minutes, label: 'Minute')),
            const SizedBox(width: 10),
            Expanded(child: _CountdownTile(value: seconds, label: 'Second')),
          ],
        ),
      ],
    );
  }
}

class _CountdownTile extends StatelessWidget {
  const _CountdownTile({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value.toString().padLeft(2, '0'),
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xEFFFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FundingProgress extends StatelessWidget {
  const _FundingProgress({required this.campaign});

  final FundraisingCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final progress = campaign.progressFraction;
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: _line,
            valueColor: const AlwaysStoppedAnimation<Color>(_gold),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$percent% funded',
          style: const TextStyle(
            color: _muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _FundingStatCard(
                  width: tileWidth,
                  label: 'Raised',
                  value: _formatMoney(campaign.raisedAmount, campaign.currency),
                ),
                _FundingStatCard(
                  width: tileWidth,
                  label: 'Goal',
                  value: _formatMoney(campaign.goalAmount, campaign.currency),
                ),
                _FundingStatCard(
                  width: tileWidth,
                  label: 'Supporters',
                  value: NumberFormat('#,##0').format(campaign.donorCount),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FundingStatCard extends StatelessWidget {
  const _FundingStatCard({
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  color: _primary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentContributions extends StatelessWidget {
  const _RecentContributions({required this.campaign});

  final FundraisingCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final contributions = campaign.recentContributions.take(6).toList();
    if (contributions.isEmpty) {
      return const _SoftNotice(
        icon: Icons.favorite_border,
        title: 'Supporters',
        message: 'Be the first supporter listed for this campaign.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Expanded(
              child: Text(
                'Supporters',
                style: TextStyle(
                  color: _primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            Text(
              'Recent',
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: contributions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final contribution = contributions[index];
              return _ContributionChip(contribution: contribution);
            },
          ),
        ),
      ],
    );
  }
}

class _ContributionChip extends StatelessWidget {
  const _ContributionChip({required this.contribution});

  final FundraisingContributionSummary contribution;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF4D5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.volunteer_activism_outlined,
                color: _primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contribution.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatMoney(contribution.amount, contribution.currency),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
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

class _SupportersPanel extends StatelessWidget {
  const _SupportersPanel({required this.campaign});

  final FundraisingCampaign campaign;

  @override
  Widget build(BuildContext context) {
    if (campaign.recentContributions.isEmpty) {
      return const _SoftNotice(
        icon: Icons.groups_outlined,
        title: 'No public supporters yet',
        message:
            'Contributions can still be made even when supporters choose privacy.',
      );
    }

    return Column(
      children: [
        for (final contribution in campaign.recentContributions.take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SupporterRow(contribution: contribution),
          ),
      ],
    );
  }
}

class _SupporterRow extends StatelessWidget {
  const _SupporterRow({required this.contribution});

  final FundraisingContributionSummary contribution;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF4D5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.favorite_outline, color: _primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contribution.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              if (contribution.succeededAt != null)
                Text(
                  DateFormat('d MMM yyyy')
                      .format(contribution.succeededAt!.toLocal()),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _formatMoney(contribution.amount, contribution.currency),
          style: const TextStyle(
            color: _primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _MediaGallery extends StatelessWidget {
  const _MediaGallery({
    required this.media,
    required this.onPlayYoutube,
  });

  final List<FundraisingCampaignMedia> media;
  final ValueChanged<String> onPlayYoutube;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return const _SoftNotice(
        icon: Icons.perm_media_outlined,
        title: 'No campaign media',
        message: 'Media will appear here when it is added by the team.',
      );
    }

    return Column(
      children: [
        for (final item in media)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MediaGalleryItem(media: item, onPlayYoutube: onPlayYoutube),
          ),
      ],
    );
  }
}

class _MediaGalleryItem extends StatelessWidget {
  const _MediaGalleryItem({
    required this.media,
    required this.onPlayYoutube,
  });

  final FundraisingCampaignMedia media;
  final ValueChanged<String> onPlayYoutube;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: media.isYoutube ? () => onPlayYoutube(media.youtubeVideoId) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 88,
                height: 58,
                child: media.hasVisualPreview
                    ? CachedNetworkImage(
                        imageUrl: media.previewUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _MediaPlaceholder(media: media),
                        errorWidget: (_, __, ___) =>
                            _MediaPlaceholder(media: media),
                      )
                    : _MediaPlaceholder(media: media),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.title.trim().isNotEmpty
                        ? media.title.trim()
                        : media.mediaLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    media.caption.trim().isNotEmpty
                        ? media.caption.trim()
                        : media.mediaLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.3,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            if (media.isYoutube)
              const Icon(Icons.play_circle_outline, color: _gold, size: 28),
          ],
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.media});

  final FundraisingCampaignMedia media;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE6EEF2),
      alignment: Alignment.center,
      child: Icon(
        media.isAudio
            ? Icons.graphic_eq
            : media.isYoutube || media.isVideo
                ? Icons.play_circle_outline
                : Icons.image_outlined,
        color: _primary,
        size: 34,
      ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
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
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: _muted,
                    height: 1.35,
                    letterSpacing: 0,
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

class _ContributionForm extends StatelessWidget {
  const _ContributionForm({
    required this.amountController,
    required this.messageController,
    required this.anonymous,
    required this.walletEnabled,
    required this.cardCheckoutEnabled,
    required this.walletSubmitting,
    required this.checkoutSubmitting,
    required this.currency,
    required this.onAnonymousChanged,
    required this.onWalletSubmit,
    required this.onCheckoutSubmit,
  });

  final TextEditingController amountController;
  final TextEditingController messageController;
  final bool anonymous;
  final bool walletEnabled;
  final bool cardCheckoutEnabled;
  final bool walletSubmitting;
  final bool checkoutSubmitting;
  final String currency;
  final ValueChanged<bool> onAnonymousChanged;
  final VoidCallback onWalletSubmit;
  final VoidCallback onCheckoutSubmit;

  @override
  Widget build(BuildContext context) {
    final code = currency.trim().toUpperCase();
    final busy = walletSubmitting || checkoutSubmitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD4DEE5),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Support this campaign',
          style: TextStyle(
            color: _primary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose secure card checkout or your Goshen wallet. Wallet support requires a fresh unlock.',
          style: TextStyle(color: _muted, height: 1.4, letterSpacing: 0),
        ),
        const SizedBox(height: 18),
        TextFormField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration(
            label: 'Amount ($code)',
            icon: Icons.account_balance_wallet_outlined,
          ),
          validator: (value) {
            final amount = double.tryParse((value ?? '').trim()) ?? 0;
            return amount >= 1 ? null : 'Enter an amount of at least 1.';
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: messageController,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: _inputDecoration(
            label: 'Message (optional)',
            icon: Icons.message_outlined,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: _gold,
          title: const Text(
            'Contribute anonymously',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
          ),
          subtitle: const Text('Your public display name will be hidden.'),
          value: anonymous,
          onChanged: busy ? null : onAnonymousChanged,
        ),
        const SizedBox(height: 12),
        if (!cardCheckoutEnabled && !walletEnabled)
          const _PaymentUnavailableNotice()
        else ...[
          if (cardCheckoutEnabled) ...[
            _PaymentActionButton(
              label: checkoutSubmitting
                  ? 'Starting checkout...'
                  : 'Support with card',
              icon: Icons.credit_card,
              busy: checkoutSubmitting,
              enabled: !busy,
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              onPressed: onCheckoutSubmit,
            ),
            if (walletEnabled) const SizedBox(height: 10),
          ],
          if (walletEnabled)
            _PaymentActionButton(
              label: walletSubmitting ? 'Processing...' : 'Support with wallet',
              icon: Icons.lock_outline,
              busy: walletSubmitting,
              enabled: !busy,
              backgroundColor: _gold,
              foregroundColor: _primary,
              onPressed: onWalletSubmit,
            ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: _page,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _gold, width: 1.5),
      ),
    );
  }
}

class _PaymentUnavailableNotice extends StatelessWidget {
  const _PaymentUnavailableNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6DD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE4A3)),
      ),
      child: const Text(
        'Support payments are being prepared. Please try again shortly.',
        style: TextStyle(
          color: _primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PaymentActionButton extends StatelessWidget {
  const _PaymentActionButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.enabled,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final bool enabled;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            : Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: const Color(0xFFCAD6DC),
          disabledForegroundColor: const Color(0xFF62717C),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}

class _SupportBar extends StatelessWidget {
  const _SupportBar({
    required this.enabled,
    required this.label,
    required this.submitting,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final bool submitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: ElevatedButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.volunteer_activism_outlined),
            label: Text(
              submitting
                  ? 'Processing...'
                  : enabled
                      ? label
                      : 'Campaign closed',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _primary,
              disabledBackgroundColor: const Color(0xFFCAD6DC),
              disabledForegroundColor: const Color(0xFF62717C),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YoutubePlayerPanel extends StatefulWidget {
  const _YoutubePlayerPanel({required this.videoId});

  final String videoId;

  @override
  State<_YoutubePlayerPanel> createState() => _YoutubePlayerPanelState();
}

class _YoutubePlayerPanelState extends State<_YoutubePlayerPanel> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: YoutubePlayer(
              controller: _controller,
              aspectRatio: 16 / 9,
              showVideoProgressIndicator: true,
              bottomActions: [
                const SizedBox(width: 10),
                CurrentPosition(),
                const SizedBox(width: 8),
                ProgressBar(isExpanded: true),
                RemainingDuration(),
                const PlaybackSpeedButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 180, 28, 28),
      children: [
        Icon(icon, size: 56, color: _gold),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _primary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _muted,
            fontSize: 16,
            height: 1.4,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

String _formatMoney(double value, String currency) {
  return '${_currencySymbol(currency)}${NumberFormat('#,##0.00').format(value)}';
}

String _currencySymbol(String currency) {
  switch (currency.trim().toUpperCase()) {
    case 'GBP':
      return '\u00A3';
    case 'USD':
      return r'$';
    case 'EUR':
      return '\u20AC';
    default:
      return '${currency.trim().toUpperCase()} ';
  }
}
