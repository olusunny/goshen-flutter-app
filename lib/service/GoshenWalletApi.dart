import 'package:dio/dio.dart';

import '../models/GoshenWallet.dart';
import '../models/Userdata.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';

class GoshenWalletApi {
  GoshenWalletApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static final Map<String, GoshenWallet> _walletCache = {};

  GoshenWallet? cachedWallet(Userdata user) =>
      _walletCache[_userCacheKey(user)];

  Future<GoshenWallet> fetchWallet(Userdata user) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_WALLET,
      options: _mobileOptions(user),
      data: {'data': _authPayload(user)},
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load your wallet.');
    }

    final wallet = GoshenWallet.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
    _walletCache[_userCacheKey(user)] = wallet;
    return wallet;
  }

  Future<WalletSecurityResetStatus> walletSecurityResetStatus(
      Userdata user) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_WALLET_SECURITY_RESET_STATUS,
      options: _mobileOptions(user),
      data: {'data': _authPayload(user)},
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(
        data['message'] ?? 'Unable to check wallet security reset status.',
      );
    }

    return WalletSecurityResetStatus.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Future<WalletSecurityResetStatus> acknowledgeWalletSecurityReset(
      Userdata user) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_WALLET_SECURITY_RESET_ACK,
      options: _mobileOptions(user),
      data: {'data': _authPayload(user)},
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(
        data['message'] ?? 'Unable to acknowledge wallet security reset.',
      );
    }

    return WalletSecurityResetStatus.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Future<GoshenWallet> updateGoal({
    required Userdata user,
    required double amount,
    required String label,
    String currency = 'GBP',
    int? goalId,
  }) async {
    final response = await _dio.post(
      goalId == null
          ? ApiUrl.GOSHEN_WALLET_GOAL
          : ApiUrl.goshenWalletGoal(goalId.toString()),
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          if (goalId != null) 'goal_id': goalId,
          'goal_amount': amount,
          'goal_label': label,
          'currency': currency,
        }
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to update wallet goal.');
    }

    return GoshenWallet.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Future<GoshenWallet> createGoal({
    required Userdata user,
    required double amount,
    required String label,
    String currency = 'GBP',
    bool isPrimary = false,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_WALLET_GOALS,
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          'goal_amount': amount,
          'goal_label': label,
          'currency': currency,
          'is_primary': isPrimary,
        }
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to add wallet goal.');
    }

    return GoshenWallet.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Future<GoshenWallet> cancelGoal({
    required Userdata user,
    int? goalId,
  }) async {
    final response = await _dio.post(
      goalId == null
          ? ApiUrl.GOSHEN_WALLET_GOAL_CANCEL
          : ApiUrl.goshenWalletGoalCancel(goalId.toString()),
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          if (goalId != null) 'goal_id': goalId,
        }
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to cancel wallet goal.');
    }

    return GoshenWallet.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Future<GoshenWallet> transfer({
    required Userdata user,
    required String recipient,
    required double amount,
    String currency = 'GBP',
    String? note,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_WALLET_TRANSFER,
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          'recipient': recipient,
          'amount': amount,
          'currency': currency,
          if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
        }
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to transfer wallet funds.');
    }

    return GoshenWallet.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Future<Map<String, dynamic>> createTopUpCheckout({
    required Userdata user,
    required double amount,
    String currency = 'GBP',
    bool savePaymentMethod = false,
    int? savingsPlanId,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_WALLET_TOP_UP_CHECKOUT,
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          'amount': amount,
          'currency': currency,
          'save_payment_method': savePaymentMethod,
          if (savingsPlanId != null) 'savings_plan_id': savingsPlanId,
        }
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(
          data['message'] ?? 'Unable to start secure wallet top-up.');
    }

    return Map<String, dynamic>.from(data['checkout'] as Map? ?? {});
  }

  Future<GoshenWallet> redeemTopUpVoucher({
    required Userdata user,
    required String code,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_WALLET_TOP_UP_VOUCHER,
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          'code': code,
        }
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to apply wallet voucher.');
    }

    final wallet = GoshenWallet.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
    _walletCache[_userCacheKey(user)] = wallet;
    return wallet;
  }

  Future<GoshenWallet> createWithdrawal({
    required Userdata user,
    required double amount,
    required String currency,
    required String bankName,
    required String accountName,
    required String accountNumber,
    String? sortCode,
    String? iban,
    String? userNote,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_WALLET_WITHDRAWALS,
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          'amount': amount,
          'currency': currency,
          'bank_name': bankName,
          'account_name': accountName,
          'account_number': accountNumber,
          if ((sortCode ?? '').trim().isNotEmpty) 'sort_code': sortCode!.trim(),
          if ((iban ?? '').trim().isNotEmpty) 'iban': iban!.trim(),
          if ((userNote ?? '').trim().isNotEmpty) 'user_note': userNote!.trim(),
        }
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(
          data['message'] ?? 'Unable to submit withdrawal request.');
    }

    final wallet = GoshenWallet.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
    _walletCache[_userCacheKey(user)] = wallet;
    return wallet;
  }

  Future<GoshenWallet> cancelWithdrawal({
    required Userdata user,
    required GoshenWalletWithdrawalRequest request,
  }) async {
    final response = await _dio.post(
      ApiUrl.goshenWalletWithdrawalCancel(request.id.toString()),
      options: _mobileOptions(user),
      data: {'data': _authPayload(user)},
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(
          data['message'] ?? 'Unable to cancel withdrawal request.');
    }

    final wallet = GoshenWallet.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
    _walletCache[_userCacheKey(user)] = wallet;
    return wallet;
  }

  Future<Map<String, dynamic>> fetchWithdrawalManagement(Userdata user) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_WALLET_WITHDRAWALS_MANAGEMENT,
      options: _mobileOptions(user),
      data: {'data': _authPayload(user)},
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(
          data['message'] ?? 'Unable to load wallet withdrawal requests.');
    }

    return Map<String, dynamic>.from(data['data'] as Map? ?? {});
  }

  Future<GoshenWalletWithdrawalRequest> updateWithdrawalStatus({
    required Userdata user,
    required GoshenWalletWithdrawalRequest request,
    required String status,
    String? adminNote,
    String? payoutReference,
  }) async {
    final response = await _dio.post(
      ApiUrl.goshenWalletWithdrawalManagementStatus(request.id.toString()),
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          'status': status,
          if ((adminNote ?? '').trim().isNotEmpty)
            'admin_note': adminNote!.trim(),
          if ((payoutReference ?? '').trim().isNotEmpty)
            'payout_reference': payoutReference!.trim(),
        }
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(
          data['message'] ?? 'Unable to update withdrawal request.');
    }

    return GoshenWalletWithdrawalRequest.fromJson(
      Map<String, dynamic>.from(data['withdrawal'] as Map? ?? {}),
    );
  }

  Future<GoshenWallet> createSavingsPlan({
    required Userdata user,
    required double amount,
    required String frequency,
    int? totalCycles,
    String currency = 'GBP',
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_WALLET_SAVINGS_PLANS,
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          'amount': amount,
          'currency': currency,
          'frequency': frequency,
          if (totalCycles != null) 'remaining_cycles': totalCycles,
        }
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to create savings plan.');
    }

    return GoshenWallet.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Future<GoshenWallet> updateSavingsPlan({
    required Userdata user,
    required GoshenWalletSavingsPlan plan,
    required String status,
    double? amount,
    String? currency,
    String? frequency,
    int? remainingCycles,
  }) async {
    final response = await _dio.post(
      ApiUrl.goshenWalletSavingsPlan(plan.id.toString()),
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          'status': status,
          if (amount != null) 'amount': amount,
          if (currency != null) 'currency': currency,
          if (frequency != null) 'frequency': frequency,
          if (remainingCycles != null) 'remaining_cycles': remainingCycles,
        }
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to update savings plan.');
    }

    return GoshenWallet.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> _authPayload(Userdata user) {
    final token = (user.apiToken ?? '').trim();
    if (token.isEmpty) {
      throw Exception('Please sign in again to manage your Goshen wallet.');
    }

    return {
      'email': user.email,
      'api_token': token,
    };
  }

  String _userCacheKey(Userdata user) {
    final token = (user.apiToken ?? '').trim();
    return token.isNotEmpty ? token : '${user.email ?? ''}'.trim();
  }

  Options _mobileOptions(Userdata user) {
    final token = (user.apiToken ?? '').trim();
    return Options(
      validateStatus: (status) => status != null && status < 600,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  Map<String, dynamic> _decodeMap(dynamic value) {
    try {
      return Map<String, dynamic>.from(decodeApiResponse(value));
    } on FormatException {
      throw Exception(
        'The server returned an unexpected page instead of wallet data. Please try again shortly.',
      );
    } on TypeError {
      throw Exception('The wallet response was not in the expected format.');
    }
  }
}
