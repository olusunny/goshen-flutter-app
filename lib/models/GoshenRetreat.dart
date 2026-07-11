class GoshenRetreatEvent {
  const GoshenRetreatEvent({
    required this.id,
    required this.publicId,
    required this.name,
    required this.slug,
    required this.description,
    required this.timezone,
    required this.venueName,
    required this.venueAddress,
    required this.supportEmail,
    required this.inquiryPhone,
    required this.featureImageUrl,
    required this.startDate,
    required this.endDate,
    required this.salesStartAt,
    required this.salesEndAt,
    required this.registration,
    required this.registrationFields,
    required this.payInFullDiscount,
    required this.schedules,
    required this.ticketTypes,
    required this.pastVideos,
  });

  final int id;
  final String publicId;
  final String name;
  final String slug;
  final String description;
  final String timezone;
  final String venueName;
  final String venueAddress;
  final String supportEmail;
  final String inquiryPhone;
  final String featureImageUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? salesStartAt;
  final DateTime? salesEndAt;
  final GoshenRegistrationStatus registration;
  final List<GoshenRegistrationField> registrationFields;
  final GoshenPayInFullDiscount payInFullDiscount;
  final List<GoshenRetreatSchedule> schedules;
  final List<GoshenTicketType> ticketTypes;
  final List<GoshenRetreatPastVideo> pastVideos;

  factory GoshenRetreatEvent.fromJson(Map<String, dynamic> json) {
    return GoshenRetreatEvent(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      publicId: '${json['public_id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      description: '${json['description'] ?? ''}',
      timezone: '${json['timezone'] ?? 'Africa/Lagos'}',
      venueName: '${json['venue_name'] ?? ''}',
      venueAddress: '${json['venue_address'] ?? ''}',
      supportEmail: '${json['support_email'] ?? ''}',
      inquiryPhone: _stringValue(json, const [
        'inquiry_phone',
        'inquiryPhone',
        'inquiry_phone_number',
        'inquiryPhoneNumber',
        'support_phone',
        'supportPhone',
        'contact_phone',
        'contactPhone',
      ]),
      featureImageUrl: _featureImageUrl(json),
      startDate: _date(json['start_date'] ?? json['startDate']),
      endDate: _date(json['end_date'] ?? json['endDate']),
      salesStartAt: _date(json['sales_start_at']),
      salesEndAt: _date(json['sales_end_at']),
      registration: GoshenRegistrationStatus.fromJson(
        Map<String, dynamic>.from(json['registration'] as Map? ?? {}),
        fallbackOpen: _bool(json['registration_open']),
        fallbackReason: '${json['registration_closed_reason'] ?? ''}',
      ),
      registrationFields: _registrationFieldsFromJson(json),
      payInFullDiscount: GoshenPayInFullDiscount.fromJson(
        Map<String, dynamic>.from(json['pay_in_full_discount'] as Map? ?? {}),
      ),
      schedules: ((json['schedules'] as List?) ?? const [])
          .map((item) =>
              GoshenRetreatSchedule.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      ticketTypes: ((json['ticket_types'] as List?) ?? const [])
          .map((item) =>
              GoshenTicketType.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      pastVideos: _listValue(
        json,
        const [
          'past_videos',
          'pastVideos',
          'youtube_videos',
          'youtubeVideos',
          'videos',
        ],
      )
          .whereType<Map>()
          .map((item) => GoshenRetreatPastVideo.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((video) => video.youtubeUrl.isNotEmpty)
          .toList(),
    );
  }

  String get dateLabel {
    if (startDate != null) {
      if (endDate == null || _sameDate(startDate!, endDate!)) {
        return _formatDate(startDate!);
      }

      return '${_formatDate(startDate!)} - ${_formatDate(endDate!)}';
    }

    if (schedules.isEmpty) return 'Dates will be announced';
    final first = schedules.first.startsAt;
    final last = schedules.last.endsAt ?? schedules.last.startsAt;
    if (first == null) return 'Dates will be announced';
    if (last == null || _sameDate(first, last)) return _formatDate(first);
    return '${_formatDate(first)} - ${_formatDate(last)}';
  }

  String get priceLabel {
    if (ticketTypes.isEmpty) return 'Tickets will be announced';
    final first = ticketTypes.first;
    return '${first.currency} ${_money(first.price)}';
  }

  bool get canRegister => registration.open && ticketTypes.isNotEmpty;

  DateTime? get countdownTarget {
    if (startDate != null) return startDate;
    for (final schedule in schedules) {
      if (schedule.startsAt != null) return schedule.startsAt;
    }
    return salesEndAt ?? salesStartAt;
  }
}

class GoshenRetreatPastVideo {
  const GoshenRetreatPastVideo({
    required this.videoId,
    required this.youtubeUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.description,
  });

  final String videoId;
  final String youtubeUrl;
  final String thumbnailUrl;
  final String title;
  final String description;

  factory GoshenRetreatPastVideo.fromJson(Map<String, dynamic> json) {
    final youtube = _dynamicMap(json['youtube']);
    final rawUrl = _firstStringValue([
      json['youtube_url'],
      json['youtubeUrl'],
      json['url'],
      json['link'],
      youtube['url'],
      youtube['link'],
    ]);
    final parsedVideoId = _firstStringValue([
      json['youtube_video_id'],
      json['youtubeVideoId'],
      json['youtube_id'],
      json['youtubeId'],
      json['video_id'],
      json['videoId'],
      youtube['video_id'],
      youtube['videoId'],
      youtube['id'],
    ]);
    final videoId = parsedVideoId.isNotEmpty
        ? parsedVideoId
        : _youtubeVideoIdFromUrl(rawUrl);
    final youtubeUrl = _youtubeUrl(rawUrl: rawUrl, videoId: videoId);
    final thumbnailUrl = _firstStringValue([
      json['thumbnail_url'],
      json['thumbnailUrl'],
      json['youtube_thumbnail_url'],
      json['youtubeThumbnailUrl'],
      json['thumbnail'],
      json['image_url'],
      youtube['thumbnail_url'],
      youtube['thumbnailUrl'],
      youtube['thumbnail'],
    ]);

    return GoshenRetreatPastVideo(
      videoId: videoId,
      youtubeUrl: youtubeUrl,
      thumbnailUrl: thumbnailUrl.isNotEmpty
          ? thumbnailUrl
          : videoId.isEmpty
              ? ''
              : 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      title: _firstStringValue([
        json['title'],
        json['name'],
        youtube['title'],
        youtube['name'],
      ]),
      description: _firstStringValue([
        json['description'],
        json['summary'],
        youtube['description'],
        youtube['summary'],
      ]),
    );
  }
}

class GoshenRegistrationStatus {
  const GoshenRegistrationStatus({
    required this.open,
    required this.status,
    required this.override,
    required this.message,
    required this.closedReason,
    this.closedAt,
    this.reopenedAt,
  });

  final bool open;
  final String status;
  final String override;
  final String message;
  final String closedReason;
  final DateTime? closedAt;
  final DateTime? reopenedAt;

  factory GoshenRegistrationStatus.fromJson(
    Map<String, dynamic> json, {
    bool fallbackOpen = true,
    String fallbackReason = '',
  }) {
    final open = json.containsKey('open') ? _bool(json['open']) : fallbackOpen;
    final reason = '${json['closed_reason'] ?? fallbackReason}'.trim();
    return GoshenRegistrationStatus(
      open: open,
      status: '${json['status'] ?? (open ? 'open' : 'closed')}',
      override: '${json['override'] ?? 'auto'}',
      message:
          '${json['message'] ?? (open ? 'Registration is open.' : reason)}',
      closedReason: reason,
      closedAt: _date(json['closed_at']),
      reopenedAt: _date(json['reopened_at']),
    );
  }
}

class GoshenPayInFullDiscount {
  const GoshenPayInFullDiscount({
    required this.enabled,
    required this.active,
    required this.label,
    required this.type,
    required this.value,
    this.startsAt,
    this.endsAt,
  });

  final bool enabled;
  final bool active;
  final String label;
  final String type;
  final double value;
  final DateTime? startsAt;
  final DateTime? endsAt;

  bool get available => enabled && active && value > 0;

  factory GoshenPayInFullDiscount.fromJson(Map<String, dynamic> json) {
    return GoshenPayInFullDiscount(
      enabled: _bool(json['enabled']),
      active: _bool(json['active']),
      label: '${json['label'] ?? 'Pay in full discount'}',
      type: '${json['type'] ?? 'percentage'}',
      value: double.tryParse('${json['value'] ?? 0}') ?? 0,
      startsAt: _date(json['starts_at']),
      endsAt: _date(json['ends_at']),
    );
  }

  double amountFor(double subtotal) {
    if (!available || subtotal <= 0) return 0;
    final amount =
        type == 'fixed' ? value : subtotal * value.clamp(0, 100) / 100;
    return amount.clamp(0, subtotal).toDouble();
  }

  String description(String currency, double subtotal) {
    final amount = amountFor(subtotal);
    if (amount <= 0) return '';
    final prefix = label.trim().isEmpty ? 'Pay in full discount' : label.trim();
    return '$prefix: $currency ${_money(amount)} off';
  }
}

class GoshenRegistrationField {
  const GoshenRegistrationField({
    required this.id,
    required this.key,
    required this.label,
    required this.type,
    required this.isRequired,
    required this.isUnique,
    required this.options,
    required this.sortOrder,
  });

  final int id;
  final String key;
  final String label;
  final String type;
  final bool isRequired;
  final bool isUnique;
  final List<GoshenRegistrationFieldOption> options;
  final int sortOrder;

  bool get isSelect =>
      type == 'select' || type == 'single_select' || type == 'dropdown';
  bool get isImageSelect => type == 'image_select';
  bool get isColorSelect => type == 'color_select';
  bool get isTextArea => type == 'textarea';

  factory GoshenRegistrationField.fromJson(Map<String, dynamic> json) {
    final type = '${json['type'] ?? 'text'}'.trim().toLowerCase();
    return GoshenRegistrationField(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      key: '${json['key'] ?? ''}'.trim(),
      label: '${json['label'] ?? json['key'] ?? ''}'.trim(),
      type: type.isEmpty ? 'text' : type,
      isRequired: _bool(json['is_required'] ?? json['required']),
      isUnique: _bool(json['is_unique'] ?? json['unique']),
      options: ((json['options'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => GoshenRegistrationFieldOption.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
    );
  }
}

class GoshenRegistrationFieldOption {
  const GoshenRegistrationFieldOption({
    required this.label,
    required this.value,
    required this.imagePath,
    required this.imageUrl,
    required this.colorHex,
    required this.fee,
    required this.feeLabel,
    required this.currency,
  });

  final String label;
  final String value;
  final String imagePath;
  final String imageUrl;
  final String colorHex;
  final double fee;
  final String feeLabel;
  final String currency;

  factory GoshenRegistrationFieldOption.fromJson(Map<String, dynamic> json) {
    return GoshenRegistrationFieldOption(
      label: '${json['label'] ?? json['name'] ?? json['value'] ?? ''}'.trim(),
      value: '${json['value'] ?? ''}'.trim(),
      imagePath: '${json['image_path'] ?? json['imagePath'] ?? ''}'.trim(),
      imageUrl:
          '${json['image_url'] ?? json['imageUrl'] ?? json['image_path'] ?? ''}'
              .trim(),
      colorHex:
          '${json['color_hex'] ?? json['colour_hex'] ?? json['color'] ?? ''}'
              .trim(),
      fee: _doubleValueFromKeys(json, const [
        'fee',
        'fee_amount',
        'feeAmount',
        'option_fee',
        'optionFee',
        'additional_fee',
        'additionalFee',
        'price',
        'amount',
      ]),
      feeLabel: '${json['fee_label'] ?? json['feeLabel'] ?? ''}'.trim(),
      currency: _stringValue(json, const ['currency', 'fee_currency']),
    );
  }

  bool get hasFee => fee > 0;

  String labelWithFee(String fallbackCurrency) {
    if (!hasFee) return label;
    final effectiveCurrency =
        currency.trim().isEmpty ? fallbackCurrency : currency;
    final amount = _money(fee);
    return effectiveCurrency.trim().isEmpty
        ? '$label (+$amount)'
        : '$label (+$effectiveCurrency $amount)';
  }
}

class GoshenRetreatSchedule {
  const GoshenRetreatSchedule({
    required this.id,
    required this.dayNumber,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
  });

  final int id;
  final int dayNumber;
  final String title;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? capacity;

  factory GoshenRetreatSchedule.fromJson(Map<String, dynamic> json) {
    return GoshenRetreatSchedule(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      dayNumber: int.tryParse('${json['day_number'] ?? 0}') ?? 0,
      title: '${json['title'] ?? ''}',
      startsAt: _date(json['starts_at']),
      endsAt: _date(json['ends_at']),
      capacity:
          json['capacity'] == null ? null : int.tryParse('${json['capacity']}'),
    );
  }

  String get timeLabel {
    if (startsAt == null) return 'Time will be announced';
    final start = _formatTime(startsAt!);
    final end = endsAt == null ? '' : ' - ${_formatTime(endsAt!)}';
    return '$start$end';
  }
}

class GoshenTicketType {
  const GoshenTicketType({
    required this.id,
    required this.publicId,
    required this.name,
    required this.sku,
    required this.currency,
    required this.price,
    required this.capacity,
    required this.minPerBooking,
    required this.maxPerBooking,
    required this.isActive,
  });

  final int id;
  final String publicId;
  final String name;
  final String sku;
  final String currency;
  final double price;
  final int? capacity;
  final int minPerBooking;
  final int maxPerBooking;
  final bool isActive;

  factory GoshenTicketType.fromJson(Map<String, dynamic> json) {
    return GoshenTicketType(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      publicId: '${json['public_id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      sku: '${json['sku'] ?? ''}',
      currency: '${json['currency'] ?? 'USD'}',
      price: double.tryParse('${json['price'] ?? 0}') ?? 0,
      capacity:
          json['capacity'] == null ? null : int.tryParse('${json['capacity']}'),
      minPerBooking: int.tryParse('${json['min_per_booking'] ?? 1}') ?? 1,
      maxPerBooking: int.tryParse('${json['max_per_booking'] ?? 10}') ?? 10,
      isActive: _bool(json['is_active'] ?? true),
    );
  }
}

class GoshenRegistration {
  const GoshenRegistration({
    required this.publicId,
    required this.eventName,
    required this.currency,
    required this.total,
    required this.paidTotal,
    required this.status,
    required this.schedules,
    required this.lines,
    required this.attendees,
    required this.installments,
    required this.payments,
    required this.tickets,
    required this.createdAt,
    required this.paymentExpiresAt,
    required this.paymentReminderSentAt,
    required this.cancelledAt,
    required this.cancellationReason,
    required this.canCancel,
    required this.canPay,
    required this.paymentMode,
    required this.voucherCodeSuffix,
  });

  final String publicId;
  final String eventName;
  final String currency;
  final double total;
  final double paidTotal;
  final String status;
  final List<GoshenRetreatSchedule> schedules;
  final List<GoshenRegistrationLine> lines;
  final List<GoshenAttendee> attendees;
  final List<GoshenInstallment> installments;
  final List<GoshenPaymentRecord> payments;
  final List<GoshenTicket> tickets;
  final DateTime? createdAt;
  final DateTime? paymentExpiresAt;
  final DateTime? paymentReminderSentAt;
  final DateTime? cancelledAt;
  final String cancellationReason;
  final bool canCancel;
  final bool canPay;
  final String paymentMode;
  final String voucherCodeSuffix;

  factory GoshenRegistration.fromJson(Map<String, dynamic> json) {
    final event = Map<String, dynamic>.from(json['event'] as Map? ?? {});
    return GoshenRegistration(
      publicId: '${json['public_id'] ?? ''}',
      eventName: '${event['name'] ?? 'Goshen Retreat'}',
      currency: '${json['currency'] ?? ''}',
      total: double.tryParse('${json['total'] ?? 0}') ?? 0,
      paidTotal: double.tryParse('${json['paid_total'] ?? 0}') ?? 0,
      status: '${json['status'] ?? 'pending'}',
      schedules: ((event['schedules'] as List?) ?? const [])
          .map((item) =>
              GoshenRetreatSchedule.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      lines: ((json['lines'] as List?) ?? const [])
          .map((item) =>
              GoshenRegistrationLine.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      attendees: ((json['attendees'] as List?) ?? const [])
          .map((item) =>
              GoshenAttendee.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      installments: ((json['installments'] as List?) ?? const [])
          .map((item) =>
              GoshenInstallment.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      payments: _listValue(
        json,
        const ['payments', 'payment_history', 'transactions', 'charges'],
      )
          .map((item) =>
              GoshenPaymentRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      tickets: ((json['tickets'] as List?) ?? const [])
          .map((item) => GoshenTicket.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      createdAt: _date(json['created_at']),
      paymentExpiresAt: _date(json['payment_expires_at']),
      paymentReminderSentAt: _date(json['payment_reminder_sent_at']),
      cancelledAt: _date(json['cancelled_at']),
      cancellationReason: '${json['cancellation_reason'] ?? ''}',
      canCancel: _bool(json['can_cancel']),
      canPay: json.containsKey('can_pay') ? _bool(json['can_pay']) : true,
      paymentMode: '${json['payment_mode'] ?? ''}',
      voucherCodeSuffix: '${json['voucher_code_suffix'] ?? ''}',
    );
  }

  String get totalLabel => '$currency ${_money(total)}'.trim();
  String get paidLabel => '$currency ${_money(paidTotal)}'.trim();
  double get balanceTotal {
    final remaining = total - paidTotal;
    return remaining < 0 ? 0 : remaining;
  }

  String get balanceLabel => '$currency ${_money(balanceTotal)}'.trim();

  double get paymentProgress {
    if (total <= 0) return paidTotal > 0 ? 1 : 0;
    final value = paidTotal / total;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  String get createdLabel =>
      createdAt == null ? 'Date unavailable' : _formatDate(createdAt!);

  String get paymentExpiryLabel => paymentExpiresAt == null
      ? 'Payment expiry unavailable'
      : _formatDate(paymentExpiresAt!);

  bool get isCancelled => status.toLowerCase().trim() == 'cancelled';
  bool get isPaid => status.toLowerCase().trim() == 'paid' || balanceTotal <= 0;
  bool get countsInSummary => isPaid && !isCancelled;
  bool get isVoucherPaid => paymentMode.toLowerCase().trim() == 'voucher';

  String get statusLabel {
    final cleaned = status.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return 'Pending';
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}

class GoshenMemberRetreatData {
  const GoshenMemberRetreatData({
    required this.registrations,
    required this.accommodationAllocations,
    required this.givingHistory,
    required this.referralSummary,
    required this.referralPoints,
  });

  final List<GoshenRegistration> registrations;
  final List<GoshenAccommodationAllocation> accommodationAllocations;
  final List<GoshenGivingRecord> givingHistory;
  final GoshenReferralSummary referralSummary;
  final List<GoshenReferralPointEntry> referralPoints;

  factory GoshenMemberRetreatData.fromJson(Map<String, dynamic> json) {
    return GoshenMemberRetreatData(
      registrations: ((json['registrations'] as List?) ?? const [])
          .map((item) =>
              GoshenRegistration.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      accommodationAllocations:
          ((json['accommodation_allocations'] as List?) ?? const [])
              .map((item) => GoshenAccommodationAllocation.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(),
      givingHistory: _listValue(
        json,
        const [
          'giving_history',
          'givingHistory',
          'giving',
          'donations',
          'donation_history',
          'gifts',
        ],
      )
          .map((item) =>
              GoshenGivingRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      referralSummary: GoshenReferralSummary.fromJson(
        _referralSummaryJson(json),
      ),
      referralPoints: _referralEntriesJson(json)
          .whereType<Map>()
          .map((item) => GoshenReferralPointEntry.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }
}

class GoshenReferralSummary {
  const GoshenReferralSummary({
    required this.code,
    required this.totalPoints,
    required this.pendingPoints,
    required this.validatedPoints,
    required this.convertedPoints,
    required this.availablePoints,
    required this.currency,
    required this.walletAmount,
    required this.conversionEnabled,
    required this.conversionMessage,
  });

  const GoshenReferralSummary.empty()
      : code = '',
        totalPoints = 0,
        pendingPoints = 0,
        validatedPoints = 0,
        convertedPoints = 0,
        availablePoints = 0,
        currency = '',
        walletAmount = 0,
        conversionEnabled = false,
        conversionMessage = '';

  final String code;
  final int totalPoints;
  final int pendingPoints;
  final int validatedPoints;
  final int convertedPoints;
  final int availablePoints;
  final String currency;
  final double walletAmount;
  final bool conversionEnabled;
  final String conversionMessage;

  factory GoshenReferralSummary.fromJson(Map<String, dynamic> json) {
    final availablePoints = _roundedIntValueFromKeys(json, const [
      'available_points',
      'availablePoints',
      'validated_available_points',
      'validatedAvailablePoints',
      'convertible_points',
      'convertiblePoints',
      'validated',
    ]);
    final canConvert = json.containsKey('can_convert')
        ? _bool(json['can_convert'])
        : json.containsKey('canConvert')
            ? _bool(json['canConvert'])
            : json.containsKey('wallet_conversion_enabled')
                ? _bool(json['wallet_conversion_enabled'])
                : json.containsKey('walletConversionEnabled')
                    ? _bool(json['walletConversionEnabled'])
                    : availablePoints > 0;

    return GoshenReferralSummary(
      code: _stringValue(json, const [
        'referral_code',
        'referralCode',
        'code',
        'member_referral_code',
        'memberReferralCode',
      ]),
      totalPoints: _roundedIntValueFromKeys(json, const [
        'total_points',
        'totalPoints',
        'points_total',
        'pointsTotal',
        'total_earned',
        'totalEarned',
      ]),
      pendingPoints: _roundedIntValueFromKeys(json, const [
        'pending_points',
        'pendingPoints',
        'pending_validation',
        'pendingValidation',
      ]),
      validatedPoints: _roundedIntValueFromKeys(json, const [
        'validated_points',
        'validatedPoints',
        'approved_points',
        'approvedPoints',
        'validated',
      ]),
      convertedPoints: _roundedIntValueFromKeys(json, const [
        'converted_points',
        'convertedPoints',
        'redeemed_points',
        'redeemedPoints',
        'converted',
      ]),
      availablePoints: availablePoints,
      currency: _stringValue(json, const [
        'currency',
        'wallet_currency',
        'walletCurrency',
      ]),
      walletAmount: _doubleValueFromKeys(json, const [
        'wallet_amount',
        'walletAmount',
        'wallet_amount_available',
        'walletAmountAvailable',
        'available_amount',
        'availableAmount',
        'convertible_amount',
        'convertibleAmount',
      ]),
      conversionEnabled: canConvert,
      conversionMessage: _stringValue(json, const [
        'conversion_message',
        'conversionMessage',
        'wallet_conversion_message',
        'walletConversionMessage',
      ]),
    );
  }

  bool get hasContent =>
      code.trim().isNotEmpty ||
      totalPoints > 0 ||
      pendingPoints > 0 ||
      validatedPoints > 0 ||
      convertedPoints > 0 ||
      availablePoints > 0;

  bool get canConvert => conversionEnabled && availablePoints > 0;

  String get availablePointsLabel => _pointsLabel(availablePoints);

  String get walletAmountLabel {
    final amount = _money(walletAmount);
    return currency.trim().isEmpty ? amount : '${currency.trim()} $amount';
  }
}

class GoshenReferralPointEntry {
  const GoshenReferralPointEntry({
    required this.publicId,
    required this.referralCode,
    required this.referredName,
    required this.referredEmail,
    required this.points,
    required this.status,
    required this.currency,
    required this.walletAmount,
    required this.createdAt,
    required this.validatedAt,
    required this.convertedAt,
  });

  final String publicId;
  final String referralCode;
  final String referredName;
  final String referredEmail;
  final int points;
  final String status;
  final String currency;
  final double walletAmount;
  final DateTime? createdAt;
  final DateTime? validatedAt;
  final DateTime? convertedAt;

  factory GoshenReferralPointEntry.fromJson(Map<String, dynamic> json) {
    final referred = _dynamicMap(
      json['referred'] ??
          json['referred_user'] ??
          json['referredUser'] ??
          json['member'] ??
          json['user'],
    );
    return GoshenReferralPointEntry(
      publicId: _stringValue(json, const ['public_id', 'publicId', 'id']),
      referralCode: _stringValue(json, const [
        'referral_code',
        'referralCode',
        'code',
      ]),
      referredName: _stringValue(json, const [
        'referred_name',
        'referredName',
        'referee_name',
        'refereeName',
        'name',
        'member_name',
        'memberName',
      ]).isNotEmpty
          ? _stringValue(json, const [
              'referred_name',
              'referredName',
              'referee_name',
              'refereeName',
              'name',
              'member_name',
              'memberName',
            ])
          : _stringValue(referred, const ['name', 'full_name', 'fullName']),
      referredEmail: _stringValue(json, const [
        'referred_email',
        'referredEmail',
        'referee_email',
        'refereeEmail',
        'email',
        'member_email',
        'memberEmail',
      ]).isNotEmpty
          ? _stringValue(json, const [
              'referred_email',
              'referredEmail',
              'referee_email',
              'refereeEmail',
              'email',
              'member_email',
              'memberEmail',
            ])
          : _stringValue(referred, const ['email']),
      points: _roundedIntValueFromKeys(json, const [
        'points',
        'point_value',
        'pointValue',
        'validated_points',
        'validatedPoints',
      ]),
      status: _stringValue(json, const [
        'status',
        'point_status',
        'pointStatus',
        'state',
      ]),
      currency: _stringValue(json, const ['currency', 'wallet_currency']),
      walletAmount: _doubleValueFromKeys(json, const [
        'wallet_amount',
        'walletAmount',
        'amount',
        'converted_amount',
        'convertedAmount',
      ]),
      createdAt: _date(json['created_at'] ??
          json['createdAt'] ??
          json['earned_at'] ??
          json['earnedAt']),
      validatedAt: _date(json['validated_at'] ??
          json['validatedAt'] ??
          json['approved_at'] ??
          json['approvedAt']),
      convertedAt: _date(json['converted_at'] ??
          json['convertedAt'] ??
          json['redeemed_at'] ??
          json['redeemedAt']),
    );
  }

  String get statusLabel => _humanStatus(status, fallback: 'Pending');

  String get pointsLabel => _pointsLabel(points);

  String get amountLabel {
    if (walletAmount <= 0) return '';
    final amount = _money(walletAmount);
    return currency.trim().isEmpty ? amount : '${currency.trim()} $amount';
  }

  String get dateLabel {
    final value = convertedAt ?? validatedAt ?? createdAt;
    return value == null ? 'Date unavailable' : _formatDate(value);
  }

  String get displayName {
    if (referredName.trim().isNotEmpty) return referredName.trim();
    if (referredEmail.trim().isNotEmpty) return referredEmail.trim();
    return 'Referred registration';
  }
}

class GoshenGivingRecord {
  const GoshenGivingRecord({
    required this.publicId,
    required this.reference,
    required this.categoryName,
    required this.purpose,
    required this.currency,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    required this.givenAt,
    required this.anonymous,
  });

  final String publicId;
  final String reference;
  final String categoryName;
  final String purpose;
  final String currency;
  final double amount;
  final String status;
  final String paymentMethod;
  final DateTime? givenAt;
  final bool anonymous;

  factory GoshenGivingRecord.fromJson(Map<String, dynamic> json) {
    final category = Map<String, dynamic>.from(json['category'] as Map? ?? {});
    return GoshenGivingRecord(
      publicId: '${json['public_id'] ?? json['id'] ?? ''}',
      reference:
          '${json['reference'] ?? json['payment_reference'] ?? json['receipt'] ?? ''}',
      categoryName:
          '${json['category_name'] ?? category['name'] ?? json['fund'] ?? ''}',
      purpose: '${json['purpose'] ?? json['description'] ?? ''}',
      currency: '${json['currency'] ?? 'NGN'}',
      amount: double.tryParse('${json['amount'] ?? json['total'] ?? 0}') ?? 0,
      status: '${json['status'] ?? 'recorded'}',
      paymentMethod:
          '${json['payment_method'] ?? json['method'] ?? json['provider'] ?? ''}',
      givenAt: _date(
        json['given_at'] ??
            json['paid_at'] ??
            json['created_at'] ??
            json['updated_at'],
      ),
      anonymous: _bool(json['anonymous']),
    );
  }

  String get amountLabel => '$currency ${_money(amount)}'.trim();

  String get title {
    if (categoryName.trim().isNotEmpty) return categoryName.trim();
    if (purpose.trim().isNotEmpty) return purpose.trim();
    return 'Goshen Retreat giving';
  }

  String get statusLabel => _humanStatus(status, fallback: 'Recorded');

  String get dateLabel =>
      givenAt == null ? 'Date unavailable' : _formatDate(givenAt!);
}

class GoshenAccommodationAllocation {
  const GoshenAccommodationAllocation({
    required this.status,
    required this.eventName,
    required this.attendeeName,
    required this.ticketNumber,
    required this.building,
    required this.room,
    required this.bed,
    required this.checkInNote,
    required this.attendeeVisibleDetails,
    required this.assignedAt,
  });

  final String status;
  final String eventName;
  final String attendeeName;
  final String ticketNumber;
  final String building;
  final String room;
  final String bed;
  final String checkInNote;
  final Map<String, dynamic> attendeeVisibleDetails;
  final DateTime? assignedAt;

  factory GoshenAccommodationAllocation.fromJson(Map<String, dynamic> json) {
    final event = _dynamicMap(json['event']);
    final attendee = _dynamicMap(json['attendee']);
    return GoshenAccommodationAllocation(
      status: '${json['status'] ?? 'assigned'}',
      eventName: '${event['name'] ?? 'Goshen Retreat'}',
      attendeeName: '${attendee['name'] ?? ''}',
      ticketNumber: '${json['ticket_number'] ?? ''}',
      building: '${json['building'] ?? ''}',
      room: '${json['room'] ?? ''}',
      bed: '${json['bed'] ?? ''}',
      checkInNote: '${json['check_in_note'] ?? ''}',
      attendeeVisibleDetails: _dynamicMap(json['attendee_visible_details']),
      assignedAt: _date(json['assigned_at']),
    );
  }

  String get statusLabel {
    final cleaned = status.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return 'Assigned';
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  String get locationLabel {
    final parts = [
      if (building.trim().isNotEmpty) building.trim(),
      if (room.trim().isNotEmpty) 'Room $room',
      if (bed.trim().isNotEmpty) 'Bed $bed',
    ];
    return parts.isEmpty
        ? 'Allocation details will be shared soon'
        : parts.join(' · ');
  }
}

class GoshenRegistrationLine {
  const GoshenRegistrationLine({
    required this.ticketType,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String ticketType;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  factory GoshenRegistrationLine.fromJson(Map<String, dynamic> json) {
    return GoshenRegistrationLine(
      ticketType: '${json['ticket_type'] ?? 'Ticket'}',
      quantity: int.tryParse('${json['quantity'] ?? 0}') ?? 0,
      unitPrice: double.tryParse('${json['unit_price'] ?? 0}') ?? 0,
      lineTotal: double.tryParse('${json['line_total'] ?? 0}') ?? 0,
    );
  }
}

class GoshenAttendee {
  const GoshenAttendee({
    required this.publicId,
    required this.name,
    required this.email,
    required this.phone,
    required this.company,
    required this.designation,
    required this.gender,
    required this.ageGroup,
    required this.freeChurchBusInterest,
    required this.volunteerDepartment,
  });

  final String publicId;
  final String name;
  final String email;
  final String phone;
  final String company;
  final String designation;
  final String gender;
  final String ageGroup;
  final String freeChurchBusInterest;
  final String volunteerDepartment;

  String get genderLabel => _labelFor(gender, const {
        'male': 'Male',
        'female': 'Female',
        'not_specified': 'Gender not specified',
      });

  String get ageGroupLabel => _labelFor(ageGroup, const {
        'child': 'Child',
        'teen': 'Teen',
        'young_adult': 'Young adult',
        'adult': 'Adult',
        'senior': 'Senior',
        'not_specified': 'Age group not specified',
      });

  String get freeChurchBusInterestLabel =>
      _labelFor(freeChurchBusInterest, const {
        'yes': 'Interested in FREE church bus',
        'no_thanks': 'No thanks for FREE church bus',
      });

  String get volunteerDepartmentLabel => _labelFor(volunteerDepartment, const {
        'children_department': 'Children department',
        'intercessory': 'Intercessory',
        'media': 'Media',
        'protocol': 'Protocol',
        'sanctuary': 'Sanctuary',
        'no_chance_at_the_moment': 'No Chance at the moment',
      });

  factory GoshenAttendee.fromJson(Map<String, dynamic> json) {
    return GoshenAttendee(
      publicId: '${json['public_id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      company: '${json['company'] ?? ''}',
      designation: '${json['designation'] ?? ''}',
      gender: '${json['gender'] ?? 'not_specified'}',
      ageGroup: '${json['age_group'] ?? 'not_specified'}',
      freeChurchBusInterest:
          '${json['free_church_bus_interest'] ?? 'no_thanks'}',
      volunteerDepartment:
          '${json['volunteer_department'] ?? 'no_chance_at_the_moment'}',
    );
  }
}

String _labelFor(String value, Map<String, String> labels) {
  return labels[value.trim().toLowerCase()] ?? labels['not_specified'] ?? value;
}

class GoshenInstallment {
  const GoshenInstallment({
    required this.publicId,
    required this.label,
    required this.sequence,
    required this.currency,
    required this.amount,
    required this.paidAmount,
    required this.dueOn,
    required this.paidAt,
    required this.paymentReference,
    required this.paymentMethod,
    required this.status,
  });

  final String publicId;
  final String label;
  final int sequence;
  final String currency;
  final double amount;
  final double paidAmount;
  final DateTime? dueOn;
  final DateTime? paidAt;
  final String paymentReference;
  final String paymentMethod;
  final String status;

  factory GoshenInstallment.fromJson(Map<String, dynamic> json) {
    return GoshenInstallment(
      publicId: '${json['public_id'] ?? ''}',
      label: '${json['label'] ?? ''}',
      sequence: int.tryParse('${json['sequence'] ?? 0}') ?? 0,
      currency: '${json['currency'] ?? ''}',
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      paidAmount: double.tryParse('${json['paid_amount'] ?? 0}') ?? 0,
      dueOn: _date(json['due_on']),
      paidAt: _date(json['paid_at'] ?? json['completed_at']),
      paymentReference:
          '${json['payment_reference'] ?? json['reference'] ?? json['receipt'] ?? ''}',
      paymentMethod:
          '${json['payment_method'] ?? json['method'] ?? json['provider'] ?? ''}',
      status: '${json['status'] ?? 'pending'}',
    );
  }

  String get amountLabel => '$currency ${_money(amount)}'.trim();
  String get paidAmountLabel => '$currency ${_money(paidAmount)}'.trim();
  String get displayLabel {
    final cleanLabel = label.trim();
    if (cleanLabel.isNotEmpty) {
      return cleanLabel;
    }

    return 'Payment ${sequence == 0 ? '' : sequence}'.trim();
  }

  String get dueLabel =>
      dueOn == null ? 'Due date pending' : _formatDate(dueOn!);
  String get paidLabel =>
      paidAt == null ? 'Paid date unavailable' : _formatDate(paidAt!);
  String get statusLabel => _humanStatus(status, fallback: 'Pending');

  bool get isPaid {
    final cleaned = status.toLowerCase();
    return cleaned == 'paid' ||
        cleaned == 'completed' ||
        cleaned == 'succeeded';
  }
}

class GoshenPaymentRecord {
  const GoshenPaymentRecord({
    required this.publicId,
    required this.reference,
    required this.currency,
    required this.amount,
    required this.status,
    required this.method,
    required this.provider,
    required this.description,
    required this.paidAt,
    required this.createdAt,
  });

  final String publicId;
  final String reference;
  final String currency;
  final double amount;
  final String status;
  final String method;
  final String provider;
  final String description;
  final DateTime? paidAt;
  final DateTime? createdAt;

  factory GoshenPaymentRecord.fromJson(Map<String, dynamic> json) {
    return GoshenPaymentRecord(
      publicId: '${json['public_id'] ?? json['id'] ?? ''}',
      reference:
          '${json['reference'] ?? json['payment_reference'] ?? json['receipt'] ?? ''}',
      currency: '${json['currency'] ?? 'NGN'}',
      amount: double.tryParse('${json['amount'] ?? json['total'] ?? 0}') ?? 0,
      status: '${json['status'] ?? 'paid'}',
      method: '${json['payment_method'] ?? json['method'] ?? ''}',
      provider: '${json['provider'] ?? json['gateway'] ?? ''}',
      description: '${json['description'] ?? json['purpose'] ?? ''}',
      paidAt: _date(json['paid_at'] ?? json['completed_at']),
      createdAt: _date(json['created_at']),
    );
  }

  String get amountLabel => '$currency ${_money(amount)}'.trim();

  String get statusLabel => _humanStatus(status, fallback: 'Paid');

  String get dateLabel {
    final value = paidAt ?? createdAt;
    return value == null ? 'Date unavailable' : _formatDate(value);
  }

  String get methodLabel {
    final parts = [
      if (method.trim().isNotEmpty) method.trim(),
      if (provider.trim().isNotEmpty) provider.trim(),
    ];
    return parts.isEmpty ? 'Payment method unavailable' : parts.join(' · ');
  }
}

class GoshenVoucherInfo {
  const GoshenVoucherInfo({
    required this.id,
    required this.eventId,
    required this.purpose,
    required this.label,
    required this.batchReference,
    required this.codeSuffix,
    required this.currency,
    required this.amount,
    required this.maxUses,
    required this.usedCount,
    required this.remainingUses,
    required this.status,
    required this.startsAt,
    required this.expiresAt,
    required this.createdAt,
  });

  static const purposePayments = 'payments';
  static const purposeWalletFunding = 'wallet_funding';

  final int id;
  final int eventId;
  final String purpose;
  final String label;
  final String batchReference;
  final String codeSuffix;
  final String currency;
  final double amount;
  final int maxUses;
  final int usedCount;
  final int remainingUses;
  final String status;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory GoshenVoucherInfo.fromJson(Map<String, dynamic> json) {
    return GoshenVoucherInfo(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      eventId: int.tryParse('${json['event_id'] ?? 0}') ?? 0,
      purpose: '${json['purpose'] ?? purposePayments}',
      label: '${json['label'] ?? ''}',
      batchReference: '${json['batch_reference'] ?? ''}',
      codeSuffix: '${json['code_suffix'] ?? ''}',
      currency: '${json['currency'] ?? 'GBP'}',
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      maxUses: int.tryParse('${json['max_uses'] ?? 0}') ?? 0,
      usedCount: int.tryParse('${json['used_count'] ?? 0}') ?? 0,
      remainingUses: int.tryParse('${json['remaining_uses'] ?? 0}') ?? 0,
      status: '${json['status'] ?? ''}',
      startsAt: _date(json['starts_at']),
      expiresAt: _date(json['expires_at']),
      createdAt: _date(json['created_at']),
    );
  }

  String get amountLabel => '$currency ${_money(amount)}'.trim();
  String get purposeLabel =>
      purpose == purposeWalletFunding ? 'Wallet Funding' : 'For Payments';
  String get statusLabel => _humanStatus(status, fallback: 'Active');
}

class GoshenGeneratedVoucher {
  const GoshenGeneratedVoucher({
    required this.code,
    required this.voucher,
  });

  final String code;
  final GoshenVoucherInfo voucher;

  factory GoshenGeneratedVoucher.fromJson(Map<String, dynamic> json) {
    return GoshenGeneratedVoucher(
      code: '${json['code'] ?? ''}',
      voucher: GoshenVoucherInfo.fromJson(
        Map<String, dynamic>.from(json['voucher'] as Map? ?? {}),
      ),
    );
  }
}

class GoshenVoucherVerification {
  const GoshenVoucherVerification({
    required this.valid,
    required this.message,
    required this.voucher,
  });

  final bool valid;
  final String message;
  final GoshenVoucherInfo? voucher;

  factory GoshenVoucherVerification.fromJson(Map<String, dynamic> json) {
    final voucher = json['voucher'];
    return GoshenVoucherVerification(
      valid: _bool(json['valid']),
      message: '${json['message'] ?? ''}',
      voucher: voucher is Map
          ? GoshenVoucherInfo.fromJson(Map<String, dynamic>.from(voucher))
          : null,
    );
  }
}

class GoshenVoucherUsage {
  const GoshenVoucherUsage({
    required this.id,
    required this.voucherId,
    required this.codeSuffix,
    required this.currency,
    required this.amount,
    required this.source,
    required this.status,
    required this.eventName,
    required this.bookingReference,
    required this.memberName,
    required this.memberEmail,
    required this.redeemedByName,
    required this.createdAt,
  });

  final int id;
  final int voucherId;
  final String codeSuffix;
  final String currency;
  final double amount;
  final String source;
  final String status;
  final String eventName;
  final String bookingReference;
  final String memberName;
  final String memberEmail;
  final String redeemedByName;
  final DateTime? createdAt;

  factory GoshenVoucherUsage.fromJson(Map<String, dynamic> json) {
    final event = Map<String, dynamic>.from(json['event'] as Map? ?? {});
    final booking = Map<String, dynamic>.from(json['booking'] as Map? ?? {});
    final member = Map<String, dynamic>.from(json['member'] as Map? ?? {});
    final redeemedBy =
        Map<String, dynamic>.from(json['redeemed_by'] as Map? ?? {});

    return GoshenVoucherUsage(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      voucherId: int.tryParse('${json['voucher_id'] ?? 0}') ?? 0,
      codeSuffix: '${json['code_suffix'] ?? ''}',
      currency: '${json['currency'] ?? 'GBP'}',
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      source: '${json['source'] ?? ''}',
      status: '${json['status'] ?? ''}',
      eventName: '${event['name'] ?? ''}',
      bookingReference: '${booking['public_id'] ?? booking['id'] ?? ''}',
      memberName: '${member['name'] ?? booking['customer_name'] ?? ''}',
      memberEmail: '${member['email'] ?? booking['customer_email'] ?? ''}',
      redeemedByName: '${redeemedBy['name'] ?? ''}',
      createdAt: _date(json['created_at']),
    );
  }

  String get amountLabel => '$currency ${_money(amount)}'.trim();
  String get statusLabel => _humanStatus(status, fallback: 'Applied');
  String get sourceLabel => _humanStatus(source, fallback: 'Voucher');
  String get dateLabel =>
      createdAt == null ? 'Date unavailable' : _formatDate(createdAt!);
}

class GoshenTicket {
  const GoshenTicket({
    required this.publicId,
    required this.ticketNumber,
    required this.status,
    required this.issuedAt,
    required this.checkedInAt,
    required this.eventName,
    required this.ticketType,
    required this.attendeeName,
    required this.qrEncoded,
    required this.documentUrls,
  });

  final String publicId;
  final String ticketNumber;
  final String status;
  final DateTime? issuedAt;
  final DateTime? checkedInAt;
  final String eventName;
  final String ticketType;
  final String attendeeName;
  final String qrEncoded;
  final Map<String, String> documentUrls;

  factory GoshenTicket.fromJson(Map<String, dynamic> json) {
    final rawDocumentUrls = json['document_urls'];
    return GoshenTicket(
      publicId: '${json['public_id'] ?? ''}',
      ticketNumber: '${json['ticket_number'] ?? ''}',
      status: '${json['status'] ?? ''}',
      issuedAt: _date(json['issued_at']),
      checkedInAt: _date(json['checked_in_at'] ?? json['last_checked_in_at']),
      eventName: '${json['event_name'] ?? ''}',
      ticketType: '${json['ticket_type'] ?? ''}',
      attendeeName: '${json['attendee_name'] ?? ''}',
      qrEncoded: '${json['qr_encoded'] ?? ''}',
      documentUrls:
          rawDocumentUrls is Map ? _stringMap(rawDocumentUrls) : const {},
    );
  }

  String get statusLabel => _humanStatus(status, fallback: 'Issued');

  bool get isCheckedIn {
    final normalized = status.trim().toLowerCase().replaceAll('-', '_');
    return checkedInAt != null || normalized == 'checked_in';
  }

  String get ticketUseStatusLabel =>
      isCheckedIn ? 'Checked in' : 'Not checked in yet';

  String get qrStatusLabel =>
      qrEncoded.trim().isEmpty ? 'QR pending' : 'QR ready';

  String get issuedLabel =>
      issuedAt == null ? 'Issue date pending' : _formatDate(issuedAt!);

  String get checkInLabel =>
      checkedInAt == null ? 'Not checked in' : _formatDate(checkedInAt!);
}

class GoshenScannerStatus {
  const GoshenScannerStatus({
    required this.enabled,
    required this.scannerEnabled,
    required this.allowed,
    required this.roles,
    this.managerAllowed = false,
    this.scannerSuspended = false,
    this.scannerSuspensionReason = '',
  });

  final bool enabled;
  final bool scannerEnabled;
  final bool allowed;
  final List<String> roles;
  final bool managerAllowed;
  final bool scannerSuspended;
  final String scannerSuspensionReason;

  factory GoshenScannerStatus.fromJson(Map<String, dynamic> json) {
    return GoshenScannerStatus(
      enabled: _bool(json['enabled']),
      scannerEnabled: _bool(json['scanner_enabled']),
      allowed: _bool(json['allowed']),
      managerAllowed: _bool(json['manager_allowed']),
      scannerSuspended: _bool(json['scanner_suspended']),
      scannerSuspensionReason: '${json['scanner_suspension_reason'] ?? ''}',
      roles: ((json['roles'] as List?) ?? const [])
          .map((role) => '$role')
          .toList(),
    );
  }
}

class GoshenScannerOperator {
  const GoshenScannerOperator({
    required this.id,
    required this.name,
    required this.email,
    required this.avatar,
    required this.roles,
    required this.lastSeenAt,
    required this.isVerified,
    required this.isBlocked,
    required this.scannerSuspended,
    required this.scannerSuspensionReason,
    required this.scannerSuspendedAt,
  });

  final int id;
  final String name;
  final String email;
  final String avatar;
  final List<String> roles;
  final DateTime? lastSeenAt;
  final bool isVerified;
  final bool isBlocked;
  final bool scannerSuspended;
  final String scannerSuspensionReason;
  final DateTime? scannerSuspendedAt;

  factory GoshenScannerOperator.fromJson(Map<String, dynamic> json) {
    return GoshenScannerOperator(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      avatar: '${json['avatar'] ?? ''}',
      roles: ((json['roles'] as List?) ?? const [])
          .map((role) => '$role')
          .toList(),
      lastSeenAt: _date(json['last_seen_at']),
      isVerified: _bool(json['is_verified']),
      isBlocked: _bool(json['is_blocked']),
      scannerSuspended: _bool(json['scanner_suspended']),
      scannerSuspensionReason: '${json['scanner_suspension_reason'] ?? ''}',
      scannerSuspendedAt: _date(json['scanner_suspended_at']),
    );
  }
}

class GoshenScannerTicket {
  const GoshenScannerTicket({
    required this.publicId,
    required this.ticketNumber,
    required this.status,
    required this.eventName,
    required this.ticketType,
    required this.attendeeName,
    required this.bookingStatus,
    required this.days,
    required this.checkedInDays,
    required this.issuedAt,
  });

  final String publicId;
  final String ticketNumber;
  final String status;
  final String eventName;
  final String ticketType;
  final String attendeeName;
  final String bookingStatus;
  final List<GoshenScannerEventDay> days;
  final List<GoshenScannerCheckIn> checkedInDays;
  final DateTime? issuedAt;

  factory GoshenScannerTicket.fromJson(Map<String, dynamic> json) {
    final event = Map<String, dynamic>.from(json['event'] as Map? ?? {});
    return GoshenScannerTicket(
      publicId: '${json['public_id'] ?? ''}',
      ticketNumber: '${json['ticket_number'] ?? ''}',
      status: '${json['status'] ?? ''}',
      eventName: '${event['name'] ?? ''}',
      ticketType: '${json['ticket_type'] ?? ''}',
      attendeeName: '${json['attendee_name'] ?? ''}',
      bookingStatus: '${json['booking_status'] ?? ''}',
      days: ((event['days'] as List?) ?? const [])
          .map((item) =>
              GoshenScannerEventDay.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      checkedInDays: ((json['checked_in_days'] as List?) ?? const [])
          .map((item) =>
              GoshenScannerCheckIn.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      issuedAt: _date(json['issued_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'public_id': publicId,
      'ticket_number': ticketNumber,
      'status': status,
      'ticket_type': ticketType,
      'attendee_name': attendeeName,
      'booking_status': bookingStatus,
      'issued_at': issuedAt?.toIso8601String(),
      'event': {
        'name': eventName,
        'days': days.map((day) => day.toJson()).toList(),
      },
      'checked_in_days':
          checkedInDays.map((checkIn) => checkIn.toJson()).toList(),
    };
  }

  bool get isCheckedIn => status == 'checked_in' || checkedInDays.isNotEmpty;
}

class GoshenScannerManifest {
  const GoshenScannerManifest({
    required this.generatedAt,
    required this.expiresAt,
    required this.ttlSeconds,
    required this.version,
    required this.tickets,
  });

  final DateTime? generatedAt;
  final DateTime? expiresAt;
  final int ttlSeconds;
  final int version;
  final List<GoshenScannerTicket> tickets;

  factory GoshenScannerManifest.fromJson(Map<String, dynamic> json) {
    return GoshenScannerManifest(
      generatedAt: _date(json['generated_at']),
      expiresAt: _date(json['expires_at']),
      ttlSeconds: int.tryParse('${json['ttl_seconds'] ?? 0}') ?? 0,
      version: int.tryParse('${json['manifest_version'] ?? 1}') ?? 1,
      tickets: ((json['tickets'] as List?) ?? const [])
          .map((item) =>
              GoshenScannerTicket.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'generated_at': generatedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'ttl_seconds': ttlSeconds,
      'manifest_version': version,
      'tickets': tickets.map((ticket) => ticket.toJson()).toList(),
    };
  }
}

class GoshenScannerEventDay {
  const GoshenScannerEventDay({
    required this.dayNumber,
    required this.title,
    required this.startsAt,
  });

  final int dayNumber;
  final String title;
  final DateTime? startsAt;

  factory GoshenScannerEventDay.fromJson(Map<String, dynamic> json) {
    return GoshenScannerEventDay(
      dayNumber: int.tryParse('${json['day_number'] ?? 1}') ?? 1,
      title: '${json['title'] ?? ''}',
      startsAt: _date(json['starts_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_number': dayNumber,
      'title': title,
      'starts_at': startsAt?.toIso8601String(),
    };
  }
}

class GoshenScannerCheckIn {
  const GoshenScannerCheckIn({
    required this.dayNumber,
    required this.checkedInAt,
    required this.source,
  });

  final int dayNumber;
  final DateTime? checkedInAt;
  final String source;

  factory GoshenScannerCheckIn.fromJson(Map<String, dynamic> json) {
    return GoshenScannerCheckIn(
      dayNumber: int.tryParse('${json['day_number'] ?? 1}') ?? 1,
      checkedInAt: _date(json['checked_in_at']),
      source: '${json['source'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_number': dayNumber,
      'checked_in_at': checkedInAt?.toIso8601String(),
      'source': source,
    };
  }
}

class GoshenScannerStats {
  const GoshenScannerStats({
    required this.eventName,
    required this.registered,
    required this.checkedIn,
    required this.notYetCheckedIn,
    required this.genderBreakdown,
    required this.ageGroupBreakdown,
    required this.generatedAt,
  });

  final String eventName;
  final int registered;
  final int checkedIn;
  final int notYetCheckedIn;
  final List<GoshenScannerStatsRow> genderBreakdown;
  final List<GoshenScannerStatsRow> ageGroupBreakdown;
  final DateTime? generatedAt;

  factory GoshenScannerStats.fromJson(Map<String, dynamic> json) {
    final event = Map<String, dynamic>.from(json['event'] as Map? ?? {});
    return GoshenScannerStats(
      eventName: '${event['name'] ?? 'Goshen Retreat'}',
      registered: int.tryParse('${json['registered'] ?? 0}') ?? 0,
      checkedIn: int.tryParse('${json['checked_in'] ?? 0}') ?? 0,
      notYetCheckedIn: int.tryParse('${json['not_yet_checked_in'] ?? 0}') ?? 0,
      genderBreakdown: ((json['gender_breakdown'] as List?) ?? const [])
          .map((item) =>
              GoshenScannerStatsRow.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      ageGroupBreakdown: ((json['age_group_breakdown'] as List?) ?? const [])
          .map((item) =>
              GoshenScannerStatsRow.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      generatedAt: _date(json['generated_at']),
    );
  }
}

class GoshenScannerStatsRow {
  const GoshenScannerStatsRow({
    required this.code,
    required this.label,
    required this.registered,
    required this.checkedIn,
  });

  final String code;
  final String label;
  final int registered;
  final int checkedIn;

  int get notYetCheckedIn {
    final remaining = registered - checkedIn;
    return remaining < 0 ? 0 : remaining;
  }

  factory GoshenScannerStatsRow.fromJson(Map<String, dynamic> json) {
    return GoshenScannerStatsRow(
      code: '${json['code'] ?? ''}',
      label: '${json['label'] ?? 'Not specified'}',
      registered: int.tryParse('${json['registered'] ?? 0}') ?? 0,
      checkedIn: int.tryParse('${json['checked_in'] ?? 0}') ?? 0,
    );
  }
}

class GoshenManagementSummary {
  const GoshenManagementSummary({
    required this.event,
    required this.totals,
    required this.breakdowns,
    required this.registrations,
    required this.attendees,
  });

  final GoshenManagementEvent event;
  final GoshenManagementTotals totals;
  final GoshenManagementBreakdowns breakdowns;
  final List<GoshenManagementRegistrationRow> registrations;
  final List<GoshenManagementAttendeeRow> attendees;

  factory GoshenManagementSummary.fromJson(Map<String, dynamic> json) {
    return GoshenManagementSummary(
      event: GoshenManagementEvent.fromJson(
        Map<String, dynamic>.from(json['event'] as Map? ?? {}),
      ),
      totals: GoshenManagementTotals.fromJson(
        Map<String, dynamic>.from(json['totals'] as Map? ?? {}),
      ),
      breakdowns: GoshenManagementBreakdowns.fromJson(
        Map<String, dynamic>.from(json['breakdowns'] as Map? ?? {}),
      ),
      registrations: ((json['registrations'] as List?) ?? const [])
          .map((item) => GoshenManagementRegistrationRow.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
      attendees: ((json['attendees'] as List?) ?? const [])
          .map((item) => GoshenManagementAttendeeRow.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  bool get hasRows => registrations.isNotEmpty || attendees.isNotEmpty;
}

class GoshenManagementEvent {
  const GoshenManagementEvent({
    required this.publicId,
    required this.name,
    required this.registration,
  });

  final String publicId;
  final String name;
  final GoshenRegistrationStatus registration;

  factory GoshenManagementEvent.fromJson(Map<String, dynamic> json) {
    return GoshenManagementEvent(
      publicId: '${json['public_id'] ?? json['id'] ?? ''}',
      name: '${json['name'] ?? 'Goshen Retreat'}',
      registration: GoshenRegistrationStatus.fromJson(
        Map<String, dynamic>.from(json['registration'] as Map? ?? {}),
        fallbackOpen: _bool(json['registration_open'] ?? true),
        fallbackReason: '${json['registration_closed_reason'] ?? ''}',
      ),
    );
  }
}

class GoshenManagementTotals {
  const GoshenManagementTotals({
    required this.registrations,
    required this.attendees,
    required this.paidRegistrations,
    required this.pendingRegistrations,
    required this.cancelledRegistrations,
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.walletPaidAmount,
    required this.voucherPaidAmount,
    required this.onlinePaidAmount,
    required this.currency,
  });

  final int registrations;
  final int attendees;
  final int paidRegistrations;
  final int pendingRegistrations;
  final int cancelledRegistrations;
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;
  final double walletPaidAmount;
  final double voucherPaidAmount;
  final double onlinePaidAmount;
  final String currency;

  factory GoshenManagementTotals.fromJson(Map<String, dynamic> json) {
    return GoshenManagementTotals(
      registrations: _intValue(json, 'registrations'),
      attendees: _intValue(json, 'attendees'),
      paidRegistrations: _intValue(json, 'paid_registrations'),
      pendingRegistrations: _intValue(json, 'pending_registrations'),
      cancelledRegistrations: _intValue(json, 'cancelled_registrations'),
      totalAmount: _doubleValue(json, 'total_amount'),
      paidAmount: _doubleValue(json, 'paid_amount'),
      balanceAmount: _doubleValue(json, 'balance_amount'),
      walletPaidAmount: _doubleValue(json, 'wallet_paid_amount'),
      voucherPaidAmount: _doubleValue(json, 'voucher_paid_amount'),
      onlinePaidAmount: _doubleValue(json, 'online_paid_amount'),
      currency: '${json['currency'] ?? 'GBP'}'.trim().isEmpty
          ? 'GBP'
          : '${json['currency'] ?? 'GBP'}',
    );
  }

  String money(double value) => '$currency ${_money(value)}'.trim();

  double get paidProgress {
    if (totalAmount <= 0) return 0;
    final progress = paidAmount / totalAmount;
    if (progress.isNaN || progress.isInfinite) return 0;
    return progress.clamp(0, 1).toDouble();
  }
}

class GoshenManagementBreakdowns {
  const GoshenManagementBreakdowns({
    required this.gender,
    required this.ageGroup,
    required this.freeChurchBusInterest,
    required this.volunteerDepartment,
    required this.ticketType,
    required this.company,
    required this.designation,
    required this.bookingStatus,
    required this.paymentMode,
    required this.privacyConsent,
  });

  final List<GoshenManagementBreakdownRow> gender;
  final List<GoshenManagementBreakdownRow> ageGroup;
  final List<GoshenManagementBreakdownRow> freeChurchBusInterest;
  final List<GoshenManagementBreakdownRow> volunteerDepartment;
  final List<GoshenManagementBreakdownRow> ticketType;
  final List<GoshenManagementBreakdownRow> company;
  final List<GoshenManagementBreakdownRow> designation;
  final List<GoshenManagementBreakdownRow> bookingStatus;
  final List<GoshenManagementBreakdownRow> paymentMode;
  final List<GoshenManagementBreakdownRow> privacyConsent;

  factory GoshenManagementBreakdowns.fromJson(Map<String, dynamic> json) {
    List<GoshenManagementBreakdownRow> rows(String key) {
      return ((json[key] as List?) ?? const [])
          .map((item) => GoshenManagementBreakdownRow.fromJson(
              Map<String, dynamic>.from(item)))
          .toList();
    }

    return GoshenManagementBreakdowns(
      gender: rows('gender'),
      ageGroup: rows('age_group'),
      freeChurchBusInterest: rows('free_church_bus_interest'),
      volunteerDepartment: rows('volunteer_department'),
      ticketType: rows('ticket_type'),
      company: rows('company'),
      designation: rows('designation'),
      bookingStatus: rows('booking_status'),
      paymentMode: rows('payment_mode'),
      privacyConsent: rows('privacy_consent'),
    );
  }
}

class GoshenManagementBreakdownRow {
  const GoshenManagementBreakdownRow({
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

  factory GoshenManagementBreakdownRow.fromJson(Map<String, dynamic> json) {
    final key = '${json['key'] ?? json['code'] ?? json['value'] ?? ''}';
    final label = '${json['label'] ?? json['name'] ?? ''}'.trim();
    return GoshenManagementBreakdownRow(
      key: key,
      label:
          label.isEmpty ? _humanStatus(key, fallback: 'Not specified') : label,
      count: _intValue(json, 'count'),
      amount: json.containsKey('amount') ? _doubleValue(json, 'amount') : null,
      percentage: json.containsKey('percentage')
          ? _doubleValue(json, 'percentage')
          : null,
    );
  }
}

class GoshenManagementRegistrationRow {
  const GoshenManagementRegistrationRow({
    required this.publicId,
    required this.reference,
    required this.name,
    required this.email,
    required this.status,
    required this.paymentMode,
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.attendeesCount,
    this.createdAt,
  });

  final String publicId;
  final String reference;
  final String name;
  final String email;
  final String status;
  final String paymentMode;
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;
  final int attendeesCount;
  final DateTime? createdAt;

  factory GoshenManagementRegistrationRow.fromJson(Map<String, dynamic> json) {
    return GoshenManagementRegistrationRow(
      publicId: _stringValue(json, const ['public_id', 'booking_id', 'id']),
      reference: _stringValue(json,
          const ['reference', 'booking_reference', 'ticket_reference', 'code']),
      name: _stringValue(
          json, const ['name', 'customer_name', 'full_name', 'member_name']),
      email: _stringValue(json, const ['email', 'customer_email']),
      status: _humanStatus(
        _stringValue(json, const ['status_label', 'status', 'booking_status']),
        fallback: 'Unknown',
      ),
      paymentMode: _humanStatus(
        _stringValue(
            json, const ['payment_mode_label', 'payment_mode', 'mode']),
        fallback: 'Not set',
      ),
      totalAmount: _doubleValueFromKeys(
          json, const ['total_amount', 'total', 'amount', 'booking_total']),
      paidAmount:
          _doubleValueFromKeys(json, const ['paid_amount', 'paid_total']),
      balanceAmount:
          _doubleValueFromKeys(json, const ['balance_amount', 'balance']),
      attendeesCount: _intValueFromKeys(
          json, const ['attendees_count', 'attendee_count', 'quantity']),
      createdAt: _date(json['created_at'] ?? json['registered_at']),
    );
  }

  String get displayName => name.trim().isEmpty ? 'Unnamed member' : name;
  String get displayReference =>
      reference.trim().isEmpty ? publicId : reference;
}

class GoshenManagementAttendeeRow {
  const GoshenManagementAttendeeRow({
    required this.name,
    required this.email,
    required this.phone,
    required this.ticketType,
    required this.company,
    required this.designation,
    required this.gender,
    required this.ageGroup,
    required this.freeChurchBusInterest,
    required this.volunteerDepartment,
    required this.bookingReference,
    required this.status,
  });

  final String name;
  final String email;
  final String phone;
  final String ticketType;
  final String company;
  final String designation;
  final String gender;
  final String ageGroup;
  final String freeChurchBusInterest;
  final String volunteerDepartment;
  final String bookingReference;
  final String status;

  factory GoshenManagementAttendeeRow.fromJson(Map<String, dynamic> json) {
    return GoshenManagementAttendeeRow(
      name: _stringValue(json, const ['name', 'full_name', 'attendee_name']),
      email: _stringValue(json, const ['email', 'attendee_email']),
      phone: _stringValue(json, const ['phone', 'phone_number']),
      ticketType: _stringValue(json, const ['ticket_type', 'ticket_name']),
      company: _stringValue(json, const ['company']),
      designation: _stringValue(json, const ['designation']),
      gender: _humanStatus(
        _stringValue(json, const ['gender_label', 'gender']),
        fallback: 'Not specified',
      ),
      ageGroup: _humanStatus(
        _stringValue(json, const ['age_group_label', 'age_group']),
        fallback: 'Not specified',
      ),
      freeChurchBusInterest: _humanStatus(
        _stringValue(json, const [
          'free_church_bus_interest_label',
          'free_church_bus_interest'
        ]),
        fallback: 'Not specified',
      ),
      volunteerDepartment: _humanStatus(
        _stringValue(
            json, const ['volunteer_department_label', 'volunteer_department']),
        fallback: 'Not specified',
      ),
      bookingReference: _stringValue(
          json, const ['booking_reference', 'reference', 'booking_public_id']),
      status: _humanStatus(
        _stringValue(json, const ['status', 'booking_status']),
        fallback: 'Unknown',
      ),
    );
  }

  String get displayName => name.trim().isEmpty ? 'Unnamed attendee' : name;
  String get displayCompany =>
      company.trim().isEmpty ? 'Not provided' : company;
  String get displayDesignation =>
      designation.trim().isEmpty ? 'Not provided' : designation;
}

class GoshenManagedMember {
  const GoshenManagedMember({
    required this.id,
    required this.name,
    required this.triumphantId,
    required this.profileTitle,
    required this.maritalStatus,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.gender,
    required this.memberType,
    required this.countryOfResidence,
    required this.stateCountyProvince,
    required this.address,
    required this.profileMissingFields,
  });

  final int id;
  final String name;
  final String triumphantId;
  final String profileTitle;
  final String maritalStatus;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String gender;
  final String memberType;
  final String countryOfResidence;
  final String stateCountyProvince;
  final String address;
  final List<String> profileMissingFields;

  factory GoshenManagedMember.fromJson(Map<String, dynamic> json) {
    return GoshenManagedMember(
      id: _intValue(json, 'id'),
      name: _stringValue(json, const ['name', 'full_name']),
      triumphantId: _stringValue(
        json,
        const ['triumphant_id', 'triumphantId'],
      ),
      profileTitle: _stringValue(
          json, const ['profile_title', 'profileTitle', 'salutation', 'title']),
      maritalStatus:
          _stringValue(json, const ['marital_status', 'maritalStatus']),
      firstName: _stringValue(json, const ['first_name', 'firstName']),
      lastName: _stringValue(json, const ['last_name', 'lastName']),
      email: _stringValue(json, const ['email']),
      phone: _stringValue(json, const ['phone']),
      gender: _stringValue(json, const ['gender']),
      memberType: _stringValue(json, const ['member_type', 'memberType']),
      countryOfResidence: _stringValue(
        json,
        const ['country_of_residence', 'countryOfResidence'],
      ),
      stateCountyProvince: _stringValue(
        json,
        const ['state_county_province', 'stateCountyProvince'],
      ),
      address: _stringValue(json, const ['address']),
      profileMissingFields:
          ((json['profile_missing_fields'] as List?) ?? const [])
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList(),
    );
  }

  bool get profileComplete => profileMissingFields.isEmpty;
  String get displayName => name.trim().isEmpty ? email : name;
  String get displayTriumphantId =>
      triumphantId.trim().isEmpty ? 'Not assigned' : triumphantId;
}

class GoshenAccommodationManagementSummary {
  const GoshenAccommodationManagementSummary({
    required this.event,
    required this.totals,
    required this.statusBreakdown,
    required this.eligibleAttendees,
    required this.allocations,
    this.generatedAt,
  });

  final GoshenManagementEvent event;
  final GoshenAccommodationManagementTotals totals;
  final List<GoshenManagementBreakdownRow> statusBreakdown;
  final List<GoshenAccommodationEligibleAttendee> eligibleAttendees;
  final List<GoshenAccommodationManagementAllocation> allocations;
  final DateTime? generatedAt;

  factory GoshenAccommodationManagementSummary.fromJson(
      Map<String, dynamic> json) {
    return GoshenAccommodationManagementSummary(
      event: GoshenManagementEvent.fromJson(
        Map<String, dynamic>.from(json['event'] as Map? ?? {}),
      ),
      totals: GoshenAccommodationManagementTotals.fromJson(
        Map<String, dynamic>.from(json['totals'] as Map? ?? {}),
      ),
      statusBreakdown: ((json['status_breakdown'] as List?) ?? const [])
          .map((item) => GoshenManagementBreakdownRow.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
      eligibleAttendees: ((json['eligible_attendees'] as List?) ?? const [])
          .map((item) => GoshenAccommodationEligibleAttendee.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
      allocations: ((json['allocations'] as List?) ?? const [])
          .map((item) => GoshenAccommodationManagementAllocation.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
      generatedAt: _date(json['generated_at']),
    );
  }
}

class GoshenAccommodationManagementTotals {
  const GoshenAccommodationManagementTotals({
    required this.eligibleAttendees,
    required this.allocations,
    required this.allocated,
    required this.unallocated,
    required this.assigned,
    required this.changed,
    required this.removed,
  });

  final int eligibleAttendees;
  final int allocations;
  final int allocated;
  final int unallocated;
  final int assigned;
  final int changed;
  final int removed;

  factory GoshenAccommodationManagementTotals.fromJson(
      Map<String, dynamic> json) {
    return GoshenAccommodationManagementTotals(
      eligibleAttendees: _intValue(json, 'eligible_attendees'),
      allocations: _intValue(json, 'allocations'),
      allocated: _intValue(json, 'allocated'),
      unallocated: _intValue(json, 'unallocated'),
      assigned: _intValue(json, 'assigned'),
      changed: _intValue(json, 'changed'),
      removed: _intValue(json, 'removed'),
    );
  }

  double get allocationProgress {
    if (eligibleAttendees <= 0) return 0;
    final progress = allocated / eligibleAttendees;
    if (progress.isNaN || progress.isInfinite) return 0;
    return progress.clamp(0, 1).toDouble();
  }
}

class GoshenAccommodationEligibleAttendee {
  const GoshenAccommodationEligibleAttendee({
    required this.id,
    required this.publicId,
    required this.name,
    required this.email,
    required this.phone,
    required this.company,
    required this.designation,
    required this.ticketType,
    required this.ticketId,
    required this.ticketNumber,
    required this.ticketStatus,
    required this.bookingReference,
    required this.bookingStatus,
    this.currentAllocation,
  });

  final int id;
  final String publicId;
  final String name;
  final String email;
  final String phone;
  final String company;
  final String designation;
  final String ticketType;
  final int ticketId;
  final String ticketNumber;
  final String ticketStatus;
  final String bookingReference;
  final String bookingStatus;
  final GoshenAccommodationManagementAllocation? currentAllocation;

  factory GoshenAccommodationEligibleAttendee.fromJson(
      Map<String, dynamic> json) {
    final allocationJson = json['current_allocation'];
    return GoshenAccommodationEligibleAttendee(
      id: _intValue(json, 'id'),
      publicId: _stringValue(json, const ['public_id']),
      name: _stringValue(json, const ['name', 'attendee_name']),
      email: _stringValue(json, const ['email', 'attendee_email']),
      phone: _stringValue(json, const ['phone', 'attendee_phone']),
      company: _stringValue(json, const ['company', 'attendee_company']),
      designation:
          _stringValue(json, const ['designation', 'attendee_designation']),
      ticketType: _stringValue(json, const ['ticket_type']),
      ticketId: _intValue(json, 'ticket_id'),
      ticketNumber: _stringValue(json, const ['ticket_number']),
      ticketStatus: _humanStatus(
        _stringValue(json, const ['ticket_status']),
        fallback: 'Unknown',
      ),
      bookingReference: _stringValue(json, const ['booking_public_id']),
      bookingStatus: _humanStatus(
        _stringValue(
            json, const ['booking_status_label', 'booking_status', 'status']),
        fallback: 'Unknown',
      ),
      currentAllocation: allocationJson is Map
          ? GoshenAccommodationManagementAllocation.fromJson(
              Map<String, dynamic>.from(allocationJson))
          : null,
    );
  }

  String get displayName => name.trim().isEmpty ? 'Unnamed attendee' : name;
  String get displayTicket =>
      ticketNumber.trim().isEmpty ? ticketType : ticketNumber;
  String get displayContact =>
      [email, phone].where((value) => value.trim().isNotEmpty).join('\n');
  bool get hasAllocation => currentAllocation != null;
}

class GoshenAccommodationManagementAllocation {
  const GoshenAccommodationManagementAllocation({
    required this.id,
    required this.status,
    required this.attendeeId,
    required this.attendeeName,
    required this.attendeeEmail,
    required this.ticketId,
    required this.ticketNumber,
    required this.ticketType,
    required this.building,
    required this.room,
    required this.bed,
    required this.checkInNote,
    required this.visibleDetails,
    this.assignedAt,
    this.updatedAt,
  });

  final int id;
  final String status;
  final int attendeeId;
  final String attendeeName;
  final String attendeeEmail;
  final int ticketId;
  final String ticketNumber;
  final String ticketType;
  final String building;
  final String room;
  final String bed;
  final String checkInNote;
  final Map<String, dynamic> visibleDetails;
  final DateTime? assignedAt;
  final DateTime? updatedAt;

  factory GoshenAccommodationManagementAllocation.fromJson(
      Map<String, dynamic> json) {
    final attendee = _dynamicMap(json['attendee']);
    return GoshenAccommodationManagementAllocation(
      id: _intValue(json, 'id'),
      status: '${json['status'] ?? 'assigned'}',
      attendeeId: _intValue(json, 'attendee_id'),
      attendeeName: _stringValue(json, const ['attendee_name', 'name']),
      attendeeEmail: _stringValue(json, const ['attendee_email', 'email']),
      ticketId: _intValue(json, 'ticket_id'),
      ticketNumber: _stringValue(json, const ['ticket_number']),
      ticketType: _stringValue(json, const ['ticket_type']),
      building: _stringValue(json, const ['building']),
      room: _stringValue(json, const ['room']),
      bed: _stringValue(json, const ['bed']),
      checkInNote: _stringValue(json, const ['check_in_note']),
      visibleDetails: _dynamicMap(json['attendee_visible_details']),
      assignedAt: _date(json['assigned_at']),
      updatedAt: _date(json['updated_at']),
    ).copyWith(
      attendeeName: _stringValue(attendee, const ['name']),
    );
  }

  GoshenAccommodationManagementAllocation copyWith({
    String? attendeeName,
  }) {
    return GoshenAccommodationManagementAllocation(
      id: id,
      status: status,
      attendeeId: attendeeId,
      attendeeName: (attendeeName ?? this.attendeeName).trim().isEmpty
          ? this.attendeeName
          : attendeeName ?? this.attendeeName,
      attendeeEmail: attendeeEmail,
      ticketId: ticketId,
      ticketNumber: ticketNumber,
      ticketType: ticketType,
      building: building,
      room: room,
      bed: bed,
      checkInNote: checkInNote,
      visibleDetails: visibleDetails,
      assignedAt: assignedAt,
      updatedAt: updatedAt,
    );
  }

  String get statusLabel => _humanStatus(status, fallback: 'Assigned');

  String get displayName =>
      attendeeName.trim().isEmpty ? 'Unnamed attendee' : attendeeName;

  String get locationLabel {
    final parts = [
      if (building.trim().isNotEmpty) building.trim(),
      if (room.trim().isNotEmpty) 'Room $room',
      if (bed.trim().isNotEmpty) 'Bed $bed',
    ];
    return parts.isEmpty ? 'No room details yet' : parts.join(' · ');
  }
}

class GoshenOfflineCheckIn {
  const GoshenOfflineCheckIn({
    required this.localId,
    required this.identifier,
    required this.dayNumber,
    required this.checkedInAt,
    required this.attendeeName,
    required this.ticketNumber,
  });

  final String localId;
  final String identifier;
  final int dayNumber;
  final DateTime checkedInAt;
  final String attendeeName;
  final String ticketNumber;

  factory GoshenOfflineCheckIn.fromJson(Map<String, dynamic> json) {
    return GoshenOfflineCheckIn(
      localId: '${json['local_id'] ?? ''}',
      identifier: '${json['identifier'] ?? ''}',
      dayNumber: int.tryParse('${json['day_number'] ?? 1}') ?? 1,
      checkedInAt: _date(json['checked_in_at']) ?? DateTime.now(),
      attendeeName: '${json['attendee_name'] ?? ''}',
      ticketNumber: '${json['ticket_number'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'local_id': localId,
      'identifier': identifier,
      'day_number': dayNumber,
      'checked_in_at': checkedInAt.toIso8601String(),
      'attendee_name': attendeeName,
      'ticket_number': ticketNumber,
    };
  }

  Map<String, dynamic> toSyncPayload({String? deviceId}) {
    return {
      'local_id': localId,
      'identifier': identifier,
      'day_number': dayNumber,
      'checked_in_at': checkedInAt.toIso8601String(),
      if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
    };
  }
}

String _featureImageUrl(Map<String, dynamic> json) {
  final direct = _stringValue(json, const [
    'feature_image_url',
    'featureImageUrl',
    'feature_image_path',
    'featureImagePath',
    'banner_image_url',
    'image_url',
  ]);
  if (direct.isNotEmpty) return direct;

  final image = json['feature_image'];
  if (image is Map) {
    return _stringValue(Map<String, dynamic>.from(image), const [
      'url',
      'path',
      'image_url',
      'image_path',
      'src',
    ]);
  }

  return _firstStringValue([image]);
}

List<GoshenRegistrationField> _registrationFieldsFromJson(
  Map<String, dynamic> json,
) {
  final form = _dynamicMap(json['registration_form']);
  final raw = _listValue(form, const ['attendee_fields', 'attendeeFields'])
      .followedBy(_listValue(json, const ['attendee_fields', 'attendeeFields']))
      .toList();

  final fields = raw
      .whereType<Map>()
      .map((item) =>
          GoshenRegistrationField.fromJson(Map<String, dynamic>.from(item)))
      .where((field) => field.key.isNotEmpty && field.label.isNotEmpty)
      .toList();

  final uniqueFields = _uniqueRegistrationFields(fields);
  if (uniqueFields.isNotEmpty) return uniqueFields;

  return _defaultRegistrationFields();
}

List<GoshenRegistrationField> _uniqueRegistrationFields(
  List<GoshenRegistrationField> fields,
) {
  final unique = <String, GoshenRegistrationField>{};
  final orderedFields = [...fields]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  for (final field in orderedFields) {
    final key = _registrationFieldIdentity(field.key);
    if (key.isEmpty) continue;
    unique.putIfAbsent(key, () => field);
  }

  return unique.values.toList();
}

String _registrationFieldIdentity(String key) {
  final normalized = key
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  const aliases = {
    'age': 'age_group',
    'agegroup': 'age_group',
    'free_bus': 'free_church_bus_interest',
    'freechurchbus': 'free_church_bus_interest',
    'free_church_bus': 'free_church_bus_interest',
    'free_church_bus_consent': 'free_church_bus_interest',
    'church_bus': 'free_church_bus_interest',
    'bus_interest': 'free_church_bus_interest',
    'volunteer': 'volunteer_department',
    'volunteer_choice': 'volunteer_department',
    'volunteer_department_choice': 'volunteer_department',
  };
  return aliases[normalized] ?? normalized;
}

List<GoshenRegistrationField> _defaultRegistrationFields() {
  GoshenRegistrationField field(
    String key,
    String label,
    String type,
    bool required,
    int sortOrder,
    List<GoshenRegistrationFieldOption> options,
  ) {
    return GoshenRegistrationField(
      id: 0,
      key: key,
      label: label,
      type: type,
      isRequired: required,
      isUnique: false,
      sortOrder: sortOrder,
      options: options,
    );
  }

  GoshenRegistrationFieldOption option(String label, String value) =>
      GoshenRegistrationFieldOption(
        label: label,
        value: value,
        imagePath: '',
        imageUrl: '',
        colorHex: '',
        fee: 0,
        feeLabel: '',
        currency: '',
      );

  return [
    field('company', 'Company', 'text', false, 10, const []),
    field('designation', 'Designation', 'select', true, 20, [
      option('Please Select', ''),
      option('Member', 'member'),
      option('Worker', 'worker'),
      option('Minister', 'minister'),
      option('Pastor', 'pastor'),
      option('Guest', 'guest'),
      option('Other', 'other'),
    ]),
    field('gender', 'Gender', 'select', true, 30, [
      option('Please Select', ''),
      option('Male', 'male'),
      option('Female', 'female'),
    ]),
    field('age_group', 'Age group', 'select', true, 40, [
      option('Please Select', ''),
      option('Child', 'child'),
      option('Teen', 'teen'),
      option('Young adult', 'young_adult'),
      option('Adult', 'adult'),
      option('Senior', 'senior'),
    ]),
    field(
      'free_church_bus_interest',
      'Interested in joining FREE church bus',
      'select',
      true,
      50,
      [
        option('Please Select', ''),
        option('Yes', 'yes'),
        option('No thanks', 'no_thanks'),
      ],
    ),
    field(
      'volunteer_department',
      'What department would you like to volunteer in?',
      'select',
      true,
      60,
      [
        option('Please Select', ''),
        option('Children department', 'children_department'),
        option('Intercessory', 'intercessory'),
        option('Media', 'media'),
        option('Protocol', 'protocol'),
        option('Sanctuary', 'sanctuary'),
        option('No Chance at the moment', 'no_chance_at_the_moment'),
      ],
    ),
  ];
}

String _firstStringValue(Iterable<dynamic> values) {
  for (final value in values) {
    final text = '${value ?? ''}'.trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}

String _youtubeUrl({required String rawUrl, required String videoId}) {
  final parsed = Uri.tryParse(rawUrl.trim());
  if (parsed != null && parsed.hasScheme && _isYoutubeHost(parsed.host)) {
    return rawUrl.trim();
  }

  if (videoId.trim().isEmpty) return '';
  return 'https://www.youtube.com/watch?v=${Uri.encodeComponent(videoId.trim())}';
}

String _youtubeVideoIdFromUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '';
  final parsed = Uri.tryParse(raw);
  if (parsed == null) return '';

  final directId = parsed.host.isEmpty && !raw.contains('/');
  if (directId) return raw;

  if (!_isYoutubeHost(parsed.host)) return '';

  final queryId = parsed.queryParameters['v']?.trim() ?? '';
  if (queryId.isNotEmpty) return queryId;

  final segments = parsed.pathSegments;
  if (segments.isEmpty) return '';

  if (parsed.host.toLowerCase().contains('youtu.be')) {
    return segments.first.trim();
  }

  for (final marker in const ['embed', 'shorts', 'live', 'v']) {
    final index = segments.indexOf(marker);
    if (index >= 0 && index + 1 < segments.length) {
      return segments[index + 1].trim();
    }
  }

  return '';
}

bool _isYoutubeHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'youtu.be' ||
      normalized == 'youtube.com' ||
      normalized.endsWith('.youtube.com') ||
      normalized == 'youtube-nocookie.com' ||
      normalized.endsWith('.youtube-nocookie.com');
}

List<dynamic> _listValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is List) return value;
    if (value is Map) {
      final nested = Map<String, dynamic>.from(value);
      for (final nestedKey in const ['data', 'history', 'items', 'records']) {
        final nestedValue = nested[nestedKey];
        if (nestedValue is List) return nestedValue;
      }
    }
  }
  return const [];
}

Map<String, dynamic> _dynamicMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value)
      ..removeWhere((_, item) => '${item ?? ''}'.trim().isEmpty);
  }

  if (value is List) {
    final entries = <String, dynamic>{};
    for (var index = 0; index < value.length; index += 1) {
      final item = value[index];
      if (item is Map) {
        final nested = Map<String, dynamic>.from(item);
        final key =
            '${nested['label'] ?? nested['key'] ?? nested['name'] ?? ''}'
                .trim();
        final detail = nested['value'] ?? nested['text'] ?? nested['detail'];
        if (key.isNotEmpty && '${detail ?? ''}'.trim().isNotEmpty) {
          entries[key] = detail;
        }
        continue;
      }

      final raw = '${item ?? ''}'.trim();
      if (raw.isNotEmpty) entries['Detail ${index + 1}'] = raw;
    }
    return entries;
  }

  return const {};
}

Map<String, String> _stringMap(Map<dynamic, dynamic> value) {
  return value.map(
    (key, item) => MapEntry('$key', '${item ?? ''}'),
  )..removeWhere((_, item) => item.trim().isEmpty);
}

Map<String, dynamic> _referralSummaryJson(Map<String, dynamic> json) {
  final nested = _dynamicMap(
    json['referral'] ??
        json['referral_summary'] ??
        json['referralSummary'] ??
        json['referrals'],
  );
  final nestedPoints = _dynamicMap(nested['points']);
  final nestedSettings = _dynamicMap(nested['settings']);

  return {
    ...json,
    ...nested,
    ...nestedSettings,
    ...nestedPoints,
  };
}

List<dynamic> _referralEntriesJson(Map<String, dynamic> json) {
  final direct = _listValue(json, const [
    'referral_points',
    'referralPoints',
    'referral_point_entries',
    'referralPointEntries',
    'point_entries',
    'pointEntries',
    'referrals',
  ]);
  if (direct.isNotEmpty) return direct;

  final referral = _dynamicMap(
    json['referral'] ??
        json['referral_summary'] ??
        json['referralSummary'] ??
        json['referrals'],
  );
  return _listValue(referral, const [
    'points',
    'entries',
    'point_entries',
    'pointEntries',
    'history',
    'records',
  ]);
}

String _stringValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = '${json[key] ?? ''}'.trim();
    if (raw.isNotEmpty && raw.toLowerCase() != 'null') return raw;
  }
  return '';
}

int _intValue(Map<String, dynamic> json, String key) =>
    int.tryParse('${json[key] ?? 0}') ?? 0;

int _intValueFromKeys(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key)) return _intValue(json, key);
  }
  return 0;
}

double _doubleValue(Map<String, dynamic> json, String key) =>
    double.tryParse('${json[key] ?? 0}') ?? 0;

double _doubleValueFromKeys(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key)) return _doubleValue(json, key);
  }
  return 0;
}

int _roundedIntValueFromKeys(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) continue;
    final value = double.tryParse('${json[key] ?? 0}') ?? 0;
    return value.round();
  }
  return 0;
}

DateTime? _date(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

bool _bool(dynamic value) {
  final raw = '${value ?? ''}'.toLowerCase().trim();
  return value == true || value == 1 || raw == '1' || raw == 'true';
}

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String _formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _humanStatus(String value, {required String fallback}) {
  final cleaned = value.replaceAll('_', ' ').trim();
  if (cleaned.isEmpty) return fallback;
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

String _money(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _pointsLabel(int value) {
  final suffix = value == 1 ? 'point' : 'points';
  return '$value $suffix';
}
