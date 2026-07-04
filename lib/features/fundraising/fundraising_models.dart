class FundraisingCampaignResponse {
  const FundraisingCampaignResponse({
    required this.hasActiveCampaign,
    required this.message,
    this.campaign,
  });

  final bool hasActiveCampaign;
  final String message;
  final FundraisingCampaign? campaign;

  factory FundraisingCampaignResponse.fromJson(Map<String, dynamic> json) {
    final campaignJson = json['campaign'];
    return FundraisingCampaignResponse(
      hasActiveCampaign: _readBool(json['has_active_campaign']),
      message: '${json['message'] ?? ''}',
      campaign: campaignJson is Map
          ? FundraisingCampaign.fromJson(
              Map<String, dynamic>.from(campaignJson),
            )
          : null,
    );
  }
}

class FundraisingCampaign {
  const FundraisingCampaign({
    required this.id,
    required this.slug,
    required this.title,
    required this.cause,
    required this.shortDescription,
    required this.description,
    required this.goalAmount,
    required this.raisedAmount,
    required this.currency,
    required this.ctaLabel,
    required this.donorCount,
    required this.progressPercentage,
    required this.status,
    required this.canContribute,
    required this.remainingSeconds,
    required this.goalReached,
    required this.paymentOptions,
    required this.media,
    required this.recentContributions,
    this.startAt,
    this.endAt,
    this.serverTime,
  });

  final int id;
  final String slug;
  final String title;
  final String cause;
  final String shortDescription;
  final String description;
  final double goalAmount;
  final double raisedAmount;
  final String currency;
  final String ctaLabel;
  final int donorCount;
  final double progressPercentage;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? serverTime;
  final String status;
  final bool canContribute;
  final int? remainingSeconds;
  final bool goalReached;
  final FundraisingPaymentOptions paymentOptions;
  final List<FundraisingCampaignMedia> media;
  final List<FundraisingContributionSummary> recentContributions;

  String get identifier => slug.trim().isNotEmpty ? slug.trim() : '$id';

  double get progressFraction {
    final raw =
        progressPercentage > 1 ? progressPercentage / 100 : progressPercentage;
    return raw.clamp(0, 1).toDouble();
  }

  FundraisingCampaign copyWith({
    double? raisedAmount,
    int? donorCount,
    double? progressPercentage,
    String? status,
    bool? canContribute,
    bool? goalReached,
    List<FundraisingContributionSummary>? recentContributions,
  }) {
    return FundraisingCampaign(
      id: id,
      slug: slug,
      title: title,
      cause: cause,
      shortDescription: shortDescription,
      description: description,
      goalAmount: goalAmount,
      raisedAmount: raisedAmount ?? this.raisedAmount,
      currency: currency,
      ctaLabel: ctaLabel,
      donorCount: donorCount ?? this.donorCount,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      startAt: startAt,
      endAt: endAt,
      serverTime: serverTime,
      status: status ?? this.status,
      canContribute: canContribute ?? this.canContribute,
      remainingSeconds: remainingSeconds,
      goalReached: goalReached ?? this.goalReached,
      paymentOptions: paymentOptions,
      media: media,
      recentContributions: recentContributions ?? this.recentContributions,
    );
  }

  factory FundraisingCampaign.fromJson(Map<String, dynamic> json) {
    return FundraisingCampaign(
      id: _readInt(json['id']),
      slug: '${json['slug'] ?? ''}',
      title: '${json['title'] ?? 'Project support'}',
      cause: '${json['cause'] ?? ''}',
      shortDescription: '${json['short_description'] ?? ''}',
      description: '${json['description'] ?? ''}',
      goalAmount: _readDouble(json['goal_amount']),
      raisedAmount: _readDouble(json['raised_amount']),
      currency: '${json['currency'] ?? 'GBP'}'.toUpperCase(),
      ctaLabel: _readCtaLabel(json['cta_label']),
      donorCount: _readInt(json['donor_count']),
      progressPercentage: _readDouble(json['progress_percentage']),
      startAt: _readDate(json['start_at']),
      endAt: _readDate(json['end_at']),
      serverTime: _readDate(json['server_time']),
      status: '${json['status'] ?? ''}',
      canContribute: _readBool(json['can_contribute']),
      remainingSeconds: json['remaining_seconds'] == null
          ? null
          : _readInt(json['remaining_seconds']),
      goalReached: _readBool(json['goal_reached']),
      paymentOptions: FundraisingPaymentOptions.fromJson(
        json['payment_options'],
      ),
      media: _readList(json['media'])
          .map((item) => FundraisingCampaignMedia.fromJson(item))
          .toList(),
      recentContributions: _readList(json['recent_contributions'])
          .map((item) => FundraisingContributionSummary.fromJson(item))
          .toList(),
    );
  }
}

class FundraisingPaymentOptions {
  const FundraisingPaymentOptions({
    required this.walletEnabled,
    required this.stripeEnabled,
    required this.stripeConfigured,
  });

  final bool walletEnabled;
  final bool stripeEnabled;
  final bool stripeConfigured;

  bool get cardCheckoutEnabled => stripeEnabled && stripeConfigured;
  bool get hasAnyMethod => walletEnabled || cardCheckoutEnabled;

  factory FundraisingPaymentOptions.fromJson(dynamic value) {
    if (value is! Map) {
      return const FundraisingPaymentOptions(
        walletEnabled: true,
        stripeEnabled: false,
        stripeConfigured: false,
      );
    }

    final json = Map<String, dynamic>.from(value);
    return FundraisingPaymentOptions(
      walletEnabled: _readBool(json['wallet_enabled']),
      stripeEnabled: _readBool(json['stripe_enabled']),
      stripeConfigured: _readBool(json['stripe_configured']),
    );
  }
}

String _readCtaLabel(dynamic value) {
  final label = '${value ?? ''}'.trim();
  return label.isEmpty ? 'Support this campaign' : label;
}

class FundraisingCampaignMedia {
  const FundraisingCampaignMedia({
    required this.id,
    required this.type,
    required this.url,
    required this.youtubeVideoId,
    required this.title,
    required this.caption,
    required this.sortOrder,
  });

  final int id;
  final String type;
  final String url;
  final String youtubeVideoId;
  final String title;
  final String caption;
  final int sortOrder;

  bool get isImage => type.toLowerCase() == 'image' && url.trim().isNotEmpty;
  bool get isYoutube =>
      type.toLowerCase() == 'youtube' && youtubeVideoId.trim().isNotEmpty;
  bool get isVideo => type.toLowerCase() == 'video' && url.trim().isNotEmpty;
  bool get isAudio => type.toLowerCase() == 'audio' && url.trim().isNotEmpty;

  String get previewUrl {
    if (isImage) return url.trim();
    if (isYoutube) {
      return 'https://img.youtube.com/vi/${youtubeVideoId.trim()}/hqdefault.jpg';
    }
    return '';
  }

  bool get hasVisualPreview => previewUrl.trim().isNotEmpty;

  String get mediaLabel {
    final cleanType = type.trim().toLowerCase();
    if (cleanType == 'youtube') return 'YouTube video';
    if (cleanType == 'video') return 'Video';
    if (cleanType == 'audio') return 'Audio';
    return 'Image';
  }

  factory FundraisingCampaignMedia.fromJson(Map<String, dynamic> json) {
    return FundraisingCampaignMedia(
      id: _readInt(json['id']),
      type: '${json['type'] ?? ''}',
      url: '${json['url'] ?? ''}',
      youtubeVideoId: '${json['youtube_video_id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      caption: '${json['caption'] ?? ''}',
      sortOrder: _readInt(json['sort_order']),
    );
  }
}

class FundraisingContributionSummary {
  const FundraisingContributionSummary({
    required this.id,
    required this.amount,
    required this.currency,
    required this.displayName,
    required this.message,
    required this.succeededAt,
  });

  final int id;
  final double amount;
  final String currency;
  final String displayName;
  final String message;
  final DateTime? succeededAt;

  factory FundraisingContributionSummary.fromJson(Map<String, dynamic> json) {
    return FundraisingContributionSummary(
      id: _readInt(json['id']),
      amount: _readDouble(json['amount']),
      currency: '${json['currency'] ?? 'GBP'}'.toUpperCase(),
      displayName: '${json['display_name'] ?? 'Anonymous supporter'}',
      message: '${json['message'] ?? ''}',
      succeededAt: _readDate(json['succeeded_at']),
    );
  }
}

class FundraisingContributionResult {
  const FundraisingContributionResult({
    required this.message,
    required this.campaign,
    required this.wallet,
    required this.idempotentReplay,
  });

  final String message;
  final FundraisingCampaign campaign;
  final FundraisingWalletSnapshot? wallet;
  final bool idempotentReplay;

  factory FundraisingContributionResult.fromJson(Map<String, dynamic> json) {
    final campaignJson = json['campaign'];
    if (campaignJson is! Map) {
      throw const FormatException(
          'Contribution response did not include campaign data.');
    }

    final walletJson = json['wallet'];
    return FundraisingContributionResult(
      message: '${json['message'] ?? 'Thank you for your contribution.'}',
      campaign: FundraisingCampaign.fromJson(
        Map<String, dynamic>.from(campaignJson),
      ),
      wallet: walletJson is Map
          ? FundraisingWalletSnapshot.fromJson(
              Map<String, dynamic>.from(walletJson),
            )
          : null,
      idempotentReplay: _readBool(json['idempotent_replay']),
    );
  }
}

class FundraisingCheckoutResult {
  const FundraisingCheckoutResult({
    required this.message,
    required this.checkout,
    required this.campaign,
    required this.idempotentReplay,
  });

  final String message;
  final FundraisingCheckout checkout;
  final FundraisingCampaign? campaign;
  final bool idempotentReplay;

  factory FundraisingCheckoutResult.fromJson(Map<String, dynamic> json) {
    final checkoutJson = json['checkout'];
    if (checkoutJson is! Map) {
      throw const FormatException(
          'Checkout response did not include checkout data.');
    }

    final campaignJson = json['campaign'];
    return FundraisingCheckoutResult(
      message: '${json['message'] ?? 'Secure checkout is ready.'}',
      checkout: FundraisingCheckout.fromJson(
        Map<String, dynamic>.from(checkoutJson),
      ),
      campaign: campaignJson is Map
          ? FundraisingCampaign.fromJson(
              Map<String, dynamic>.from(campaignJson),
            )
          : null,
      idempotentReplay: _readBool(json['idempotent_replay']),
    );
  }
}

class FundraisingCheckout {
  const FundraisingCheckout({
    required this.gateway,
    required this.reference,
    required this.checkoutUrl,
  });

  final String gateway;
  final String reference;
  final String checkoutUrl;

  factory FundraisingCheckout.fromJson(Map<String, dynamic> json) {
    return FundraisingCheckout(
      gateway: '${json['gateway'] ?? ''}',
      reference: '${json['reference'] ?? ''}',
      checkoutUrl: '${json['checkout_url'] ?? ''}',
    );
  }
}

class FundraisingWalletSnapshot {
  const FundraisingWalletSnapshot({
    required this.balance,
    required this.currency,
  });

  final double balance;
  final String currency;

  factory FundraisingWalletSnapshot.fromJson(Map<String, dynamic> json) {
    return FundraisingWalletSnapshot(
      balance: _readDouble(json['balance']),
      currency: '${json['currency'] ?? 'GBP'}'.toUpperCase(),
    );
  }
}

class FundraisingManagementSummary {
  const FundraisingManagementSummary({
    required this.totals,
    required this.breakdowns,
    required this.campaigns,
    required this.recentContributions,
    this.generatedAt,
  });

  final FundraisingManagementTotals totals;
  final FundraisingManagementBreakdowns breakdowns;
  final List<FundraisingManagementCampaignRow> campaigns;
  final List<FundraisingManagementContributionRow> recentContributions;
  final DateTime? generatedAt;

  factory FundraisingManagementSummary.fromJson(Map<String, dynamic> json) {
    return FundraisingManagementSummary(
      totals: FundraisingManagementTotals.fromJson(
        Map<String, dynamic>.from(json['totals'] as Map? ?? {}),
      ),
      breakdowns: FundraisingManagementBreakdowns.fromJson(
        Map<String, dynamic>.from(json['breakdowns'] as Map? ?? {}),
      ),
      campaigns: _readList(json['campaigns'])
          .map(FundraisingManagementCampaignRow.fromJson)
          .toList(),
      recentContributions: _readList(json['recent_contributions'])
          .map(FundraisingManagementContributionRow.fromJson)
          .toList(),
      generatedAt: _readDate(json['generated_at']),
    );
  }
}

class FundraisingManagementTotals {
  const FundraisingManagementTotals({
    required this.campaigns,
    required this.activeCampaigns,
    required this.draftCampaigns,
    required this.pausedCampaigns,
    required this.closedCampaigns,
    required this.goalAmount,
    required this.raisedAmount,
    required this.allTimeRaisedAmount,
    required this.pendingAmount,
    required this.contributions,
    required this.succeededContributions,
    required this.pendingContributions,
    required this.failedContributions,
    required this.walletAmount,
    required this.stripeAmount,
    required this.currency,
  });

  final int campaigns;
  final int activeCampaigns;
  final int draftCampaigns;
  final int pausedCampaigns;
  final int closedCampaigns;
  final double goalAmount;
  final double raisedAmount;
  final double allTimeRaisedAmount;
  final double pendingAmount;
  final int contributions;
  final int succeededContributions;
  final int pendingContributions;
  final int failedContributions;
  final double walletAmount;
  final double stripeAmount;
  final String currency;

  factory FundraisingManagementTotals.fromJson(Map<String, dynamic> json) {
    return FundraisingManagementTotals(
      campaigns: _readInt(json['campaigns']),
      activeCampaigns: _readInt(json['active_campaigns']),
      draftCampaigns: _readInt(json['draft_campaigns']),
      pausedCampaigns: _readInt(json['paused_campaigns']),
      closedCampaigns: _readInt(json['closed_campaigns']),
      goalAmount: _readDouble(json['goal_amount']),
      raisedAmount: _readDouble(json['raised_amount']),
      allTimeRaisedAmount: _readDouble(json['all_time_raised_amount']),
      pendingAmount: _readDouble(json['pending_amount']),
      contributions: _readInt(json['contributions']),
      succeededContributions: _readInt(json['succeeded_contributions']),
      pendingContributions: _readInt(json['pending_contributions']),
      failedContributions: _readInt(json['failed_contributions']),
      walletAmount: _readDouble(json['wallet_amount']),
      stripeAmount: _readDouble(json['stripe_amount']),
      currency: '${json['currency'] ?? 'GBP'}'.toUpperCase(),
    );
  }

  String money(double value) => '$currency ${_formatMoney(value)}'.trim();

  double get raisedProgress {
    if (goalAmount <= 0) return 0;
    final progress = raisedAmount / goalAmount;
    if (progress.isNaN || progress.isInfinite) return 0;
    return progress.clamp(0, 1).toDouble();
  }
}

class FundraisingManagementBreakdowns {
  const FundraisingManagementBreakdowns({
    required this.campaignStatus,
    required this.contributionStatus,
    required this.paymentProvider,
    required this.campaignProgress,
  });

  final List<FundraisingManagementBreakdownRow> campaignStatus;
  final List<FundraisingManagementBreakdownRow> contributionStatus;
  final List<FundraisingManagementBreakdownRow> paymentProvider;
  final List<FundraisingManagementBreakdownRow> campaignProgress;

  factory FundraisingManagementBreakdowns.fromJson(Map<String, dynamic> json) {
    List<FundraisingManagementBreakdownRow> rows(String key) {
      return _readList(json[key])
          .map(FundraisingManagementBreakdownRow.fromJson)
          .toList();
    }

    return FundraisingManagementBreakdowns(
      campaignStatus: rows('campaign_status'),
      contributionStatus: rows('contribution_status'),
      paymentProvider: rows('payment_provider'),
      campaignProgress: rows('campaign_progress'),
    );
  }
}

class FundraisingManagementBreakdownRow {
  const FundraisingManagementBreakdownRow({
    required this.key,
    required this.label,
    required this.count,
    this.amount,
    this.percentage,
  });

  final String key;
  final String label;
  final int count;
  final double? amount;
  final double? percentage;

  factory FundraisingManagementBreakdownRow.fromJson(
    Map<String, dynamic> json,
  ) {
    final key = '${json['key'] ?? ''}';
    final label = '${json['label'] ?? ''}'.trim();
    return FundraisingManagementBreakdownRow(
      key: key,
      label: label.isEmpty ? _humanLabel(key) : label,
      count: _readInt(json['count']),
      amount: json.containsKey('amount') ? _readDouble(json['amount']) : null,
      percentage: json.containsKey('percentage')
          ? _readDouble(json['percentage'])
          : null,
    );
  }
}

class FundraisingManagementCampaignRow {
  const FundraisingManagementCampaignRow({
    required this.id,
    required this.slug,
    required this.title,
    required this.cause,
    required this.statusCode,
    required this.statusLabel,
    required this.availableActions,
    required this.currency,
    required this.goalAmount,
    required this.raisedAmount,
    required this.progressPercentage,
    required this.donorCount,
    required this.contributionsCount,
    required this.mediaCount,
    required this.canContribute,
    this.startAt,
    this.endAt,
  });

  final int id;
  final String slug;
  final String title;
  final String cause;
  final String statusCode;
  final String statusLabel;
  final List<String> availableActions;
  final String currency;
  final double goalAmount;
  final double raisedAmount;
  final double progressPercentage;
  final int donorCount;
  final int contributionsCount;
  final int mediaCount;
  final bool canContribute;
  final DateTime? startAt;
  final DateTime? endAt;

  factory FundraisingManagementCampaignRow.fromJson(
    Map<String, dynamic> json,
  ) {
    return FundraisingManagementCampaignRow(
      id: _readInt(json['id']),
      slug: '${json['slug'] ?? ''}',
      title: '${json['title'] ?? 'Project support'}',
      cause: '${json['cause'] ?? ''}',
      statusCode: '${json['status'] ?? ''}'.trim(),
      statusLabel: '${json['status_label'] ?? json['status'] ?? 'Unknown'}',
      availableActions: _readStringList(json['available_actions']),
      currency: '${json['currency'] ?? 'GBP'}'.toUpperCase(),
      goalAmount: _readDouble(json['goal_amount']),
      raisedAmount: _readDouble(json['raised_amount']),
      progressPercentage: _readDouble(json['progress_percentage']),
      donorCount: _readInt(json['donor_count']),
      contributionsCount: _readInt(json['contributions_count']),
      mediaCount: _readInt(json['media_count']),
      canContribute: _readBool(json['can_contribute']),
      startAt: _readDate(json['start_at']),
      endAt: _readDate(json['end_at']),
    );
  }

  String get displayTitle => title.trim().isEmpty ? 'Project support' : title;
  String get status => statusLabel.trim().isEmpty ? statusCode : statusLabel;
  String get identifier => slug.trim().isNotEmpty ? slug.trim() : '$id';
  String money(double value) => '$currency ${_formatMoney(value)}'.trim();
}

class FundraisingManagementContributionRow {
  const FundraisingManagementContributionRow({
    required this.id,
    required this.campaignTitle,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentProvider,
    required this.displayName,
    required this.anonymous,
    this.succeededAt,
    this.createdAt,
  });

  final int id;
  final String campaignTitle;
  final double amount;
  final String currency;
  final String status;
  final String paymentProvider;
  final String displayName;
  final bool anonymous;
  final DateTime? succeededAt;
  final DateTime? createdAt;

  factory FundraisingManagementContributionRow.fromJson(
    Map<String, dynamic> json,
  ) {
    return FundraisingManagementContributionRow(
      id: _readInt(json['id']),
      campaignTitle: '${json['campaign_title'] ?? 'Project support campaign'}',
      amount: _readDouble(json['amount']),
      currency: '${json['currency'] ?? 'GBP'}'.toUpperCase(),
      status: '${json['status_label'] ?? json['status'] ?? 'Unknown'}',
      paymentProvider:
          '${json['payment_provider_label'] ?? json['payment_provider'] ?? ''}',
      displayName: '${json['display_name'] ?? 'Supporter'}',
      anonymous: _readBool(json['anonymous']),
      succeededAt: _readDate(json['succeeded_at']),
      createdAt: _readDate(json['created_at']),
    );
  }

  String get paidAtLabel => _shortDate(succeededAt ?? createdAt);
  String get amountLabel => '$currency ${_formatMoney(amount)}'.trim();
}

List<Map<String, dynamic>> _readList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

List<String> _readStringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

DateTime? _readDate(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase().trim();
  return text == 'true' || text == '1' || text == 'yes';
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? 0}') ?? 0;
}

double _readDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? 0}') ?? 0;
}

String _formatMoney(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _humanLabel(String value) {
  final clean = value.replaceAll('_', ' ').trim();
  if (clean.isEmpty) return 'Unknown';
  return clean[0].toUpperCase() + clean.substring(1);
}

String _shortDate(DateTime? value) {
  if (value == null) return '';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
