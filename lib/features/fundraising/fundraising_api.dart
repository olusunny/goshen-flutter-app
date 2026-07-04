import 'package:dio/dio.dart';

import '../../models/Userdata.dart';
import '../../utils/ApiUrl.dart';
import '../../utils/api_response.dart';
import 'fundraising_models.dart';

class FundraisingApi {
  FundraisingApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static FundraisingCampaignResponse? _activeCampaignCache;

  FundraisingCampaignResponse? get cachedActiveCampaign => _activeCampaignCache;

  Future<bool> hasActiveCampaign() async {
    try {
      final response = await fetchActiveCampaign();
      return response.hasActiveCampaign && response.campaign != null;
    } catch (_) {
      return false;
    }
  }

  Future<FundraisingCampaignResponse> fetchActiveCampaign() async {
    final response = await _dio.get(
      ApiUrl.FUNDRAISING_ACTIVE_CAMPAIGN,
      options: _jsonOptions(),
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load project support.');
    }

    final campaignResponse = FundraisingCampaignResponse.fromJson(data);
    _activeCampaignCache = campaignResponse;
    return campaignResponse;
  }

  Future<FundraisingManagementSummary> fetchManagementSummary(
      Userdata user) async {
    final token = user.apiToken?.trim() ?? '';
    final response = await _dio.post(
      ApiUrl.FUNDRAISING_MANAGEMENT_SUMMARY,
      options: _jsonOptions(token: token),
      data: {
        'data': {
          'email': user.email,
          'api_token': token,
        },
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ??
          'Unable to load project support management summary.');
    }

    final payload = data['data'];
    if (payload is! Map) {
      throw const FormatException(
          'Project support summary response did not include data.');
    }

    return FundraisingManagementSummary.fromJson(
      Map<String, dynamic>.from(payload),
    );
  }

  Future<FundraisingManagementCampaignRow> updateManagementCampaignStatus({
    required Userdata user,
    required FundraisingManagementCampaignRow campaign,
    required String status,
  }) async {
    final token = user.apiToken?.trim() ?? '';
    final response = await _dio.post(
      ApiUrl.fundraisingManagementCampaignStatus(campaign.identifier),
      options: _jsonOptions(token: token),
      data: {
        'data': {
          'email': user.email,
          'api_token': token,
          'status': status,
        },
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to update campaign status.');
    }

    final campaignJson = data['campaign'];
    if (campaignJson is! Map) {
      throw const FormatException(
          'Campaign status response did not include campaign data.');
    }

    return FundraisingManagementCampaignRow.fromJson(
      Map<String, dynamic>.from(campaignJson),
    );
  }

  Future<FundraisingContributionResult> contributeFromWallet({
    required Userdata user,
    required FundraisingCampaign campaign,
    required double amount,
    required String idempotencyKey,
    String? message,
    bool anonymous = false,
  }) async {
    final token = user.apiToken?.trim() ?? '';
    final response = await _dio.post(
      ApiUrl.fundraisingCampaignContribute(campaign.identifier),
      options: _jsonOptions(token: token),
      data: {
        'data': {
          'amount': amount,
          if ((message ?? '').trim().isNotEmpty) 'message': message!.trim(),
          'anonymous': anonymous,
          'idempotency_key': idempotencyKey,
        },
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to record contribution.');
    }

    return FundraisingContributionResult.fromJson(data);
  }

  Future<FundraisingCheckoutResult> createStripeCheckout({
    required Userdata user,
    required FundraisingCampaign campaign,
    required double amount,
    required String idempotencyKey,
    String? message,
    bool anonymous = false,
  }) async {
    final token = user.apiToken?.trim() ?? '';
    final response = await _dio.post(
      ApiUrl.fundraisingCampaignCheckout(campaign.identifier),
      options: _jsonOptions(token: token),
      data: {
        'data': {
          'amount': amount,
          if ((message ?? '').trim().isNotEmpty) 'message': message!.trim(),
          'anonymous': anonymous,
          'idempotency_key': idempotencyKey,
        },
      },
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to start secure checkout.');
    }

    return FundraisingCheckoutResult.fromJson(data);
  }

  Options _jsonOptions({String? token}) {
    final cleanToken = token?.trim() ?? '';
    return Options(
      validateStatus: (status) => status != null && status < 600,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (cleanToken.isNotEmpty) 'Authorization': 'Bearer $cleanToken',
      },
    );
  }

  Map<String, dynamic> _decodeMap(dynamic value) {
    final decoded = decodeApiResponse(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }
}
