class GoshenWallet {
  const GoshenWallet({
    required this.id,
    required this.currency,
    required this.balance,
    required this.goalId,
    required this.goalAmount,
    required this.goalLabel,
    required this.savedPaymentMethod,
    required this.requiresCheckoutSetup,
    required this.securityReset,
    required this.goals,
    required this.ledger,
    required this.savingsPlans,
    required this.withdrawalRequests,
  });

  final int id;
  final String currency;
  final double balance;
  final int? goalId;
  final double? goalAmount;
  final String? goalLabel;
  final bool savedPaymentMethod;
  final bool requiresCheckoutSetup;
  final WalletSecurityResetStatus securityReset;
  final List<GoshenWalletGoal> goals;
  final List<GoshenWalletLedgerEntry> ledger;
  final List<GoshenWalletSavingsPlan> savingsPlans;
  final List<GoshenWalletWithdrawalRequest> withdrawalRequests;

  double get progress {
    final goal = goalAmount ?? 0;
    if (goal <= 0) return 0;
    return (balance / goal).clamp(0, 1).toDouble();
  }

  factory GoshenWallet.fromJson(Map<String, dynamic> json) {
    final ledger = ((json['ledger'] as List?) ?? const [])
        .map((item) =>
            GoshenWalletLedgerEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final plans = ((json['savings_plans'] as List?) ?? const [])
        .map((item) =>
            GoshenWalletSavingsPlan.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final goals = ((json['goals'] as List?) ?? const [])
        .map((item) =>
            GoshenWalletGoal.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final withdrawalRequests =
        ((json['withdrawal_requests'] as List?) ?? const [])
            .map((item) => GoshenWalletWithdrawalRequest.fromJson(
                Map<String, dynamic>.from(item)))
            .toList();

    return GoshenWallet(
      id: _readInt(json['id']) ?? 0,
      currency: '${json['currency'] ?? 'GBP'}',
      balance: _readDouble(json['balance']),
      goalId: _readInt(json['goal_id']),
      goalAmount:
          json['goal_amount'] == null ? null : _readDouble(json['goal_amount']),
      goalLabel: json['goal_label']?.toString(),
      savedPaymentMethod: _readBool(json['saved_payment_method']),
      requiresCheckoutSetup: _readBool(json['requires_checkout_setup']),
      securityReset: WalletSecurityResetStatus.fromJson(
        Map<String, dynamic>.from(json['security_reset'] as Map? ?? {}),
      ),
      goals: goals,
      ledger: ledger,
      savingsPlans: plans,
      withdrawalRequests: withdrawalRequests,
    );
  }
}

class GoshenWalletGoal {
  const GoshenWalletGoal({
    required this.id,
    required this.status,
    required this.label,
    required this.currency,
    required this.targetAmount,
    required this.isPrimary,
    required this.progress,
    this.targetAt,
  });

  final int id;
  final String status;
  final String label;
  final String currency;
  final double targetAmount;
  final bool isPrimary;
  final double progress;
  final DateTime? targetAt;

  bool get isActive => status == 'active';

  factory GoshenWalletGoal.fromJson(Map<String, dynamic> json) {
    return GoshenWalletGoal(
      id: _readInt(json['id']) ?? 0,
      status: '${json['status'] ?? ''}',
      label: '${json['label'] ?? 'Goshen Retreat savings'}',
      currency: '${json['currency'] ?? 'GBP'}',
      targetAmount: _readDouble(json['target_amount']),
      isPrimary: _readBool(json['is_primary']),
      progress: _readDouble(json['progress']).clamp(0, 1).toDouble(),
      targetAt: _readDate(json['target_at']),
    );
  }
}

class WalletSecurityResetStatus {
  const WalletSecurityResetStatus({
    required this.resetRequired,
    this.requestedAt,
    this.acknowledgedAt,
    this.message,
  });

  final bool resetRequired;
  final DateTime? requestedAt;
  final DateTime? acknowledgedAt;
  final String? message;

  factory WalletSecurityResetStatus.fromJson(Map<String, dynamic> json) {
    return WalletSecurityResetStatus(
      resetRequired: _readBool(json['reset_required']),
      requestedAt: _readDate(json['requested_at']),
      acknowledgedAt: _readDate(json['acknowledged_at']),
      message: json['message']?.toString(),
    );
  }
}

class GoshenWalletLedgerEntry {
  const GoshenWalletLedgerEntry({
    required this.id,
    required this.type,
    required this.direction,
    required this.status,
    required this.description,
    required this.currency,
    required this.amount,
    this.reference,
    this.createdAt,
    this.settledAt,
  });

  final int id;
  final String type;
  final String direction;
  final String status;
  final String description;
  final String currency;
  final double amount;
  final String? reference;
  final DateTime? createdAt;
  final DateTime? settledAt;

  factory GoshenWalletLedgerEntry.fromJson(Map<String, dynamic> json) {
    return GoshenWalletLedgerEntry(
      id: _readInt(json['id']) ?? 0,
      type: '${json['type'] ?? ''}',
      direction: '${json['direction'] ?? ''}',
      status: '${json['status'] ?? ''}',
      description: '${json['description'] ?? ''}',
      currency: '${json['currency'] ?? 'GBP'}',
      amount: _readDouble(json['amount']),
      reference: json['reference']?.toString(),
      createdAt: _readDate(json['created_at']),
      settledAt: _readDate(json['settled_at']),
    );
  }
}

class GoshenWalletSavingsPlan {
  const GoshenWalletSavingsPlan({
    required this.id,
    required this.status,
    required this.frequency,
    required this.currency,
    required this.amount,
    required this.totalCycles,
    required this.completedCycles,
    this.nextChargeAt,
    this.endsAt,
  });

  final int id;
  final String status;
  final String frequency;
  final String currency;
  final double amount;
  final int? totalCycles;
  final int completedCycles;
  final DateTime? nextChargeAt;
  final DateTime? endsAt;

  bool get isActive => status == 'active';

  bool get needsSetup => status == 'setup_required';

  factory GoshenWalletSavingsPlan.fromJson(Map<String, dynamic> json) {
    return GoshenWalletSavingsPlan(
      id: _readInt(json['id']) ?? 0,
      status: '${json['status'] ?? ''}',
      frequency: '${json['frequency'] ?? ''}',
      currency: '${json['currency'] ?? 'GBP'}',
      amount: _readDouble(json['amount']),
      totalCycles: _readInt(json['total_cycles']),
      completedCycles: _readInt(json['completed_cycles']) ?? 0,
      nextChargeAt: _readDate(json['next_charge_at']),
      endsAt: _readDate(json['ends_at']),
    );
  }
}

class GoshenWalletWithdrawalRequest {
  const GoshenWalletWithdrawalRequest({
    required this.id,
    required this.status,
    required this.currency,
    required this.amount,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.sortCode,
    required this.iban,
    required this.payoutReference,
    required this.userNote,
    required this.adminNote,
    required this.memberName,
    required this.memberEmail,
    required this.memberPhone,
    this.requestedAt,
    this.reviewedAt,
    this.paidAt,
    this.cancelledAt,
    this.createdAt,
  });

  final int id;
  final String status;
  final String currency;
  final double amount;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String sortCode;
  final String iban;
  final String payoutReference;
  final String userNote;
  final String adminNote;
  final String memberName;
  final String memberEmail;
  final String memberPhone;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;
  final DateTime? paidAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isOpen => status == 'pending' || status == 'approved';

  factory GoshenWalletWithdrawalRequest.fromJson(Map<String, dynamic> json) {
    final member = Map<String, dynamic>.from(json['member'] as Map? ?? {});
    return GoshenWalletWithdrawalRequest(
      id: _readInt(json['id']) ?? 0,
      status: '${json['status'] ?? ''}',
      currency: '${json['currency'] ?? 'GBP'}',
      amount: _readDouble(json['amount']),
      bankName: '${json['bank_name'] ?? ''}',
      accountName: '${json['account_name'] ?? ''}',
      accountNumber: '${json['account_number'] ?? ''}',
      sortCode: '${json['sort_code'] ?? ''}',
      iban: '${json['iban'] ?? ''}',
      payoutReference: '${json['payout_reference'] ?? ''}',
      userNote: '${json['user_note'] ?? ''}',
      adminNote: '${json['admin_note'] ?? ''}',
      memberName: '${member['name'] ?? ''}',
      memberEmail: '${member['email'] ?? ''}',
      memberPhone: '${member['phone'] ?? ''}',
      requestedAt: _readDate(json['requested_at']),
      reviewedAt: _readDate(json['reviewed_at']),
      paidAt: _readDate(json['paid_at']),
      cancelledAt: _readDate(json['cancelled_at']),
      createdAt: _readDate(json['created_at']),
    );
  }
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double _readDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

bool _readBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  final normalized = value.toString().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
