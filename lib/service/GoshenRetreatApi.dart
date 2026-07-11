import 'package:dio/dio.dart';

import '../models/GoshenRetreat.dart';
import '../models/Userdata.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';

class GoshenRetreatApi {
  GoshenRetreatApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static bool? _enabledCache;
  static List<GoshenRetreatEvent>? _eventsCache;
  static final Map<String, GoshenMemberRetreatData> _memberDataCache = {};
  static final Map<String, GoshenScannerStatus> _scannerStatusCache = {};

  bool? get cachedEnabled => _enabledCache;

  List<GoshenRetreatEvent>? get cachedEvents => _eventsCache;

  GoshenMemberRetreatData? cachedMyRetreatData(Userdata user) =>
      _memberDataCache[_userCacheKey(user)];

  GoshenScannerStatus? cachedScannerStatus(Userdata user) =>
      _scannerStatusCache[_userCacheKey(user)];

  Future<bool> isEnabled() async {
    final response = await _dio.get(ApiUrl.GOSHEN_RETREAT_STATUS);
    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    final enabled = data['enabled'] == true || '${data['enabled']}' == '1';
    _enabledCache = enabled;
    return enabled;
  }

  Future<List<GoshenRetreatEvent>> fetchEvents() async {
    final response = await _dio.get(ApiUrl.GOSHEN_RETREAT_EVENTS);
    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    final events = ((data['data'] as List?) ?? const [])
        .map((item) =>
            GoshenRetreatEvent.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    _eventsCache = events;
    return events;
  }

  Future<GoshenRetreatEvent> fetchEvent(String publicId) async {
    final response = await _dio.get(ApiUrl.goshenRetreatEvent(publicId));
    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    return GoshenRetreatEvent.fromJson(
      Map<String, dynamic>.from(data['data'] as Map),
    );
  }

  Future<GoshenMemberRetreatData> fetchMyRetreatData(Userdata user) async {
    try {
      final response = await _dio.post(
        ApiUrl.GOSHEN_RETREAT_ME,
        options: _mobileOptions(user),
        data: {
          'data': {
            'email': user.email,
            'api_token': user.apiToken,
          }
        },
      );

      final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
      if (data['status'] == 'error') {
        throw Exception(data['message'] ?? 'Unable to load registrations.');
      }

      final payload = Map<String, dynamic>.from(data['data'] as Map? ?? {});
      final memberData = GoshenMemberRetreatData.fromJson(payload);
      _memberDataCache[_userCacheKey(user)] = memberData;
      return memberData;
    } on DioException catch (error) {
      throw Exception(_friendlyApiError(
        error,
        'Unable to load your Goshen Retreat registrations right now. Please try again shortly.',
      ));
    }
  }

  Future<List<GoshenRegistration>> fetchMyRegistrations(Userdata user) async {
    return (await fetchMyRetreatData(user)).registrations;
  }

  Future<GoshenScannerStatus> fetchScannerStatus(Userdata user) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_SCANNER_STATUS,
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] == 'error') {
      throw Exception(data['message'] ?? 'Unable to check scanner access.');
    }

    final status = GoshenScannerStatus.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
    _scannerStatusCache[_userCacheKey(user)] = status;
    return status;
  }

  Future<List<GoshenScannerOperator>> fetchScannerOperators(
      Userdata user) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_SCANNER_OPERATORS,
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load scanner operators.');
    }

    final payload = Map<String, dynamic>.from(data['data'] as Map? ?? {});
    return ((payload['operators'] as List?) ?? const [])
        .map((item) =>
            GoshenScannerOperator.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<GoshenScannerOperator> toggleScannerOperator({
    required Userdata user,
    required int userId,
    required bool suspend,
    String? reason,
  }) async {
    final response = await _dio.post(
      ApiUrl.goshenScannerOperatorToggle(userId),
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
          'suspend': suspend,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to update scanner access.');
    }

    final payload = Map<String, dynamic>.from(data['data'] as Map? ?? {});
    return GoshenScannerOperator.fromJson(
      Map<String, dynamic>.from(payload['operator'] as Map? ?? {}),
    );
  }

  Future<GoshenScannerTicket> lookupTicket({
    required Userdata user,
    required String identifier,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_SCANNER_LOOKUP,
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
          'identifier': identifier,
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to find this ticket.');
    }

    return GoshenScannerTicket.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Future<List<GoshenScannerTicket>> searchTickets({
    required Userdata user,
    required String query,
    required String lookupMode,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_SCANNER_LOOKUP,
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
          'lookup_mode': lookupMode,
          'query': query,
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to search tickets.');
    }

    final payload = Map<String, dynamic>.from(data['data'] as Map? ?? {});
    return ((payload['matches'] as List?) ?? const [])
        .map((item) =>
            GoshenScannerTicket.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> checkInTicket({
    required Userdata user,
    required String identifier,
    int dayNumber = 1,
    String? deviceId,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_SCANNER_CHECK_IN,
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
          'identifier': identifier,
          'day_number': dayNumber,
          'device_id': deviceId,
          'scan_mode': 'online',
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to check in this ticket.');
    }

    return {
      ...data,
      'data': GoshenScannerTicket.fromJson(
        Map<String, dynamic>.from(data['data'] as Map? ?? {}),
      ),
    };
  }

  Future<Map<String, dynamic>> syncOfflineCheckIns({
    required Userdata user,
    required List<GoshenOfflineCheckIn> items,
    String? deviceId,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_SCANNER_SYNC,
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
          if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
          'items': items
              .map((item) => item.toSyncPayload(deviceId: deviceId))
              .toList(),
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to sync offline check-ins.');
    }

    return Map<String, dynamic>.from(data['data'] as Map? ?? {});
  }

  Future<List<GoshenScannerTicket>> fetchScannerManifest({
    required Userdata user,
    required GoshenRetreatEvent event,
  }) async {
    final manifest = await fetchScannerManifestData(user: user, event: event);
    return manifest.tickets;
  }

  Future<GoshenScannerManifest> fetchScannerManifestData({
    required Userdata user,
    required GoshenRetreatEvent event,
  }) async {
    final response = await _dio.post(
      ApiUrl.goshenScannerManifest(event.publicId),
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load scanner manifest.');
    }

    final payload = Map<String, dynamic>.from(data['data'] as Map? ?? {});
    return GoshenScannerManifest.fromJson(payload);
  }

  Future<GoshenScannerStats> fetchScannerStats({
    required Userdata user,
    required GoshenRetreatEvent event,
  }) async {
    final response = await _dio.post(
      ApiUrl.goshenScannerStats(event.publicId),
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load scanner stats.');
    }

    return GoshenScannerStats.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Future<GoshenManagementSummary> fetchManagementSummary({
    required Userdata user,
    required GoshenRetreatEvent event,
  }) async {
    final response = await _dio.post(
      ApiUrl.goshenRetreatManagementSummary(event.publicId),
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load registration stats.');
    }

    return GoshenManagementSummary.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Future<GoshenRetreatEvent> fetchRetreatSetup({
    required Userdata user,
    required GoshenRetreatEvent event,
  }) {
    return _postRetreatSetup(
      url: ApiUrl.goshenRetreatSetup(event.publicId),
      user: user,
      payload: const {},
      fallback: 'Unable to load retreat setup.',
    );
  }

  Future<GoshenRetreatEvent> saveRetreatSetupOverview({
    required Userdata user,
    required GoshenRetreatEvent event,
    required Map<String, dynamic> payload,
  }) {
    return _postRetreatSetup(
      url: ApiUrl.goshenRetreatSetupOverview(event.publicId),
      user: user,
      payload: payload,
      fallback: 'Unable to save retreat setup.',
    );
  }

  Future<GoshenRetreatEvent> saveRetreatSetupSchedule({
    required Userdata user,
    required GoshenRetreatEvent event,
    required Map<String, dynamic> payload,
  }) {
    return _postRetreatSetup(
      url: ApiUrl.goshenRetreatSetupSchedules(event.publicId),
      user: user,
      payload: payload,
      fallback: 'Unable to save schedule.',
    );
  }

  Future<GoshenRetreatEvent> deleteRetreatSetupSchedule({
    required Userdata user,
    required GoshenRetreatEvent event,
    required int scheduleId,
  }) {
    return _postRetreatSetup(
      url: ApiUrl.goshenRetreatSetupScheduleDelete(
        event.publicId,
        '$scheduleId',
      ),
      user: user,
      payload: const {},
      fallback: 'Unable to delete schedule.',
    );
  }

  Future<GoshenRetreatEvent> saveRetreatSetupTicketType({
    required Userdata user,
    required GoshenRetreatEvent event,
    required Map<String, dynamic> payload,
  }) {
    return _postRetreatSetup(
      url: ApiUrl.goshenRetreatSetupTicketTypes(event.publicId),
      user: user,
      payload: payload,
      fallback: 'Unable to save ticket type.',
    );
  }

  Future<GoshenRetreatEvent> deleteRetreatSetupTicketType({
    required Userdata user,
    required GoshenRetreatEvent event,
    required String ticketTypeId,
  }) {
    return _postRetreatSetup(
      url: ApiUrl.goshenRetreatSetupTicketTypeDelete(
        event.publicId,
        ticketTypeId,
      ),
      user: user,
      payload: const {},
      fallback: 'Unable to delete ticket type.',
    );
  }

  Future<GoshenRetreatEvent> saveRetreatSetupRegistrationField({
    required Userdata user,
    required GoshenRetreatEvent event,
    required Map<String, dynamic> payload,
  }) {
    return _postRetreatSetup(
      url: ApiUrl.goshenRetreatSetupRegistrationFields(event.publicId),
      user: user,
      payload: payload,
      fallback: 'Unable to save registration field.',
    );
  }

  Future<GoshenRetreatEvent> deleteRetreatSetupRegistrationField({
    required Userdata user,
    required GoshenRetreatEvent event,
    required int fieldId,
  }) {
    return _postRetreatSetup(
      url: ApiUrl.goshenRetreatSetupRegistrationFieldDelete(
        event.publicId,
        '$fieldId',
      ),
      user: user,
      payload: const {},
      fallback: 'Unable to delete registration field.',
    );
  }

  Future<GoshenRetreatEvent> _postRetreatSetup({
    required String url,
    required Userdata user,
    required Map<String, dynamic> payload,
    required String fallback,
  }) async {
    try {
      final response = await _dio.post(
        url,
        options: _mobileOptions(user),
        data: {
          'data': {
            'email': user.email,
            'api_token': user.apiToken,
            ...payload,
          }
        },
      );

      final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
      if (data['status'] != 'ok') {
        throw Exception(data['message'] ?? fallback);
      }

      final wrapper = Map<String, dynamic>.from(data['data'] as Map? ?? {});
      final eventPayload =
          Map<String, dynamic>.from(wrapper['event'] as Map? ?? {});
      final updated = GoshenRetreatEvent.fromJson(eventPayload);
      _mergeEventCache(updated);
      return updated;
    } on DioException catch (error) {
      throw Exception(_friendlyApiError(error, fallback));
    }
  }

  void _mergeEventCache(GoshenRetreatEvent updated) {
    final events = _eventsCache;
    if (events == null || events.isEmpty) {
      _eventsCache = [updated];
      return;
    }

    var replaced = false;
    _eventsCache = events.map((event) {
      if (event.publicId == updated.publicId) {
        replaced = true;
        return updated;
      }
      return event;
    }).toList();

    if (!replaced) {
      final current = _eventsCache ?? const <GoshenRetreatEvent>[];
      _eventsCache = [updated, ...current];
    }
  }

  Future<GoshenAccommodationManagementSummary> fetchAccommodationManagement({
    required Userdata user,
    required GoshenRetreatEvent event,
  }) async {
    final response = await _dio.post(
      ApiUrl.goshenRetreatAccommodationManagement(event.publicId),
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(
          data['message'] ?? 'Unable to load accommodation allocations.');
    }

    return GoshenAccommodationManagementSummary.fromJson(
      Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  Future<GoshenAccommodationManagementAllocation> saveAccommodationAllocation({
    required Userdata user,
    required GoshenRetreatEvent event,
    required int attendeeId,
    int? allocationId,
    int? ticketId,
    required String status,
    required String building,
    required String room,
    required String bed,
    required String checkInNote,
  }) async {
    final payload = {
      'email': user.email,
      'api_token': user.apiToken,
      'status': status,
      'building': building.trim(),
      'room': room.trim(),
      'bed': bed.trim(),
      'check_in_note': checkInNote.trim(),
      if (ticketId != null && ticketId > 0) 'ticket_id': ticketId,
    };

    final response = allocationId != null && allocationId > 0
        ? await _dio.post(
            ApiUrl.goshenAccommodationAllocation('$allocationId'),
            options: _mobileOptions(user),
            data: {'data': payload},
          )
        : await _dio.post(
            ApiUrl.GOSHEN_ACCOMMODATION_ALLOCATIONS,
            options: _mobileOptions(user),
            data: {
              'data': {
                ...payload,
                'event_id': event.publicId,
                'attendee_id': attendeeId,
              }
            },
          );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(
          data['message'] ?? 'Unable to save accommodation allocation.');
    }

    return GoshenAccommodationManagementAllocation.fromJson(
      Map<String, dynamic>.from(data['allocation'] as Map? ?? {}),
    );
  }

  Future<Map<String, dynamic>> startBooking({
    required GoshenRetreatEvent event,
    required GoshenTicketType ticketType,
    required int quantity,
    required Userdata user,
    int? managedMemberId,
    String paymentMode = 'outright',
    bool freeChurchBusConsent = false,
    bool ukPrivacyConsent = false,
    bool applyPayInFullDiscount = true,
    double fieldOptionFeeTotal = 0,
    List<Map<String, dynamic>> fieldOptionFees = const [],
    String referralCode = '',
    String voucherCode = '',
    List<Map<String, dynamic>> attendees = const [],
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_RETREAT_BOOKINGS,
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
          'event_id': event.publicId,
          if (managedMemberId != null) 'managed_member_id': managedMemberId,
          'ticket_type_id': ticketType.publicId,
          'payment_mode': paymentMode,
          if (voucherCode.trim().isNotEmpty) 'voucher_code': voucherCode.trim(),
          'quantity': quantity,
          'free_church_bus_consent': freeChurchBusConsent,
          'uk_privacy_consent': ukPrivacyConsent,
          'privacy_policy_version': 'uk-gdpr-2026-06',
          'apply_pay_in_full_discount': applyPayInFullDiscount,
          'field_option_fee_total': fieldOptionFeeTotal,
          'field_option_fees': fieldOptionFees,
          if (referralCode.trim().isNotEmpty)
            'referral_code': referralCode.trim(),
          'attendees': attendees,
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to start registration.');
    }

    return Map<String, dynamic>.from(data['booking'] as Map);
  }

  Future<List<GoshenManagedMember>> searchManagedMembers({
    required Userdata user,
    required String query,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_RETREAT_MEMBERS_SEARCH,
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
          'query': query.trim(),
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to search members.');
    }

    final payload = Map<String, dynamic>.from(data['data'] as Map? ?? {});
    return ((payload['members'] as List?) ?? const [])
        .map((item) =>
            GoshenManagedMember.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<GoshenManagedMember> createManagedMember({
    required Userdata user,
    required Map<String, dynamic> member,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_RETREAT_MEMBERS,
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
          ...member,
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to create member profile.');
    }

    final payload = Map<String, dynamic>.from(data['data'] as Map? ?? {});
    return GoshenManagedMember.fromJson(
      Map<String, dynamic>.from(payload['member'] as Map? ?? {}),
    );
  }

  /// Expected backend shape:
  /// POST api/goshen-retreat/referrals/convert
  /// data: {email, api_token}
  /// response: {status: "ok", message: "...", data: {registrations,
  /// referral, referral_points, accommodation_allocations, giving_history}}
  Future<GoshenMemberRetreatData> convertReferralPointsToWallet(
    Userdata user,
  ) async {
    try {
      final response = await _dio.post(
        ApiUrl.GOSHEN_RETREAT_REFERRAL_CONVERT,
        options: _mobileOptions(user),
        data: {
          'data': {
            'email': user.email,
            'api_token': user.apiToken,
          }
        },
      );

      final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
      if (data['status'] != 'ok') {
        throw Exception(
          data['message'] ??
              'Unable to convert referral points to wallet funds.',
        );
      }

      final payload = Map<String, dynamic>.from(data['data'] as Map? ?? {});
      if (payload.containsKey('registrations') ||
          payload.containsKey('referral') ||
          payload.containsKey('referral_points') ||
          payload.containsKey('referralPoints')) {
        final memberData = GoshenMemberRetreatData.fromJson(payload);
        _memberDataCache[_userCacheKey(user)] = memberData;
        return memberData;
      }

      return fetchMyRetreatData(user);
    } on FormatException {
      throw Exception(
        'Referral wallet conversion is not available yet. Please try again after the retreat team enables the backend endpoint.',
      );
    } on DioException catch (error) {
      throw Exception(_friendlyApiError(
        error,
        'Referral wallet conversion is not available right now. Please try again shortly.',
      ));
    }
  }

  Future<GoshenRetreatEvent> updateRegistrationStatus({
    required Userdata user,
    required GoshenRetreatEvent event,
    required bool registrationOpen,
    String? reason,
  }) async {
    final response = await _dio.post(
      ApiUrl.goshenRetreatRegistrationStatus(event.publicId),
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
          'registration_open': registrationOpen,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(
          data['message'] ?? 'Unable to update registration status.');
    }

    final payload = Map<String, dynamic>.from(data['data'] as Map? ?? {});
    return GoshenRetreatEvent.fromJson(
      Map<String, dynamic>.from(payload['event'] as Map? ?? {}),
    );
  }

  Future<Map<String, dynamic>> checkoutPayment({
    required GoshenRegistration registration,
    required GoshenInstallment payment,
    required Userdata user,
  }) async {
    final response = await _dio.post(
      ApiUrl.goshenRetreatCheckout(
        registration.publicId,
        payment.publicId,
      ),
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to start secure checkout.');
    }

    return Map<String, dynamic>.from(data['checkout'] as Map? ?? {});
  }

  Future<GoshenRegistration> payBookingWithWallet({
    required GoshenRegistration registration,
    required Userdata user,
  }) async {
    final response = await _dio.post(
      ApiUrl.goshenRetreatWalletPay(registration.publicId),
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to pay from wallet.');
    }

    return GoshenRegistration.fromJson(
      Map<String, dynamic>.from(data['booking'] as Map? ?? {}),
    );
  }

  Future<GoshenVoucherVerification> verifyVoucher({
    required Userdata user,
    required String voucherCode,
    GoshenRetreatEvent? event,
    double? amount,
    String? currency,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_RETREAT_VOUCHER_VERIFY,
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
          'voucher_code': voucherCode.trim(),
          if (event != null) 'event_id': event.publicId,
          if (amount != null) 'amount': amount,
          if (currency != null && currency.trim().isNotEmpty)
            'currency': currency.trim(),
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    final payload = Map<String, dynamic>.from(
      data['data'] is Map ? data['data'] as Map : data,
    );
    if (data['status'] != 'ok' && payload.isEmpty) {
      throw Exception(data['message'] ?? 'Unable to verify voucher.');
    }

    return GoshenVoucherVerification.fromJson({
      ...payload,
      if (!payload.containsKey('message')) 'message': data['message'] ?? '',
    });
  }

  Future<GoshenRegistration> payBookingWithVoucher({
    required GoshenRegistration registration,
    required Userdata user,
    required String voucherCode,
  }) async {
    final response = await _dio.post(
      ApiUrl.goshenRetreatVoucherPay(registration.publicId),
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
          'voucher_code': voucherCode.trim(),
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to pay with voucher.');
    }

    return GoshenRegistration.fromJson(
      Map<String, dynamic>.from(data['booking'] as Map? ?? {}),
    );
  }

  Future<List<GoshenGeneratedVoucher>> generateVouchers({
    required Userdata user,
    GoshenRetreatEvent? event,
    required String label,
    required double amount,
    required String currency,
    required int quantity,
    required String purpose,
    int maxUses = 1,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_RETREAT_VOUCHERS_GENERATE,
      options: _mobileOptions(user),
      data: voucherGenerationPayload(
        user: user,
        label: label,
        amount: amount,
        currency: currency,
        quantity: quantity,
        maxUses: maxUses,
        purpose: purpose,
        event: event,
      ),
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to generate vouchers.');
    }

    return ((data['data'] as List?) ?? const [])
        .map((item) =>
            GoshenGeneratedVoucher.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Map<String, dynamic> voucherGenerationPayload({
    required Userdata user,
    required String label,
    required double amount,
    required String currency,
    required int quantity,
    required int maxUses,
    required String purpose,
    GoshenRetreatEvent? event,
  }) =>
      {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
          'label': label.trim(),
          'amount': amount,
          'currency': currency.trim().toUpperCase(),
          'quantity': quantity,
          'max_uses': maxUses,
          'purpose': purpose,
          if (event != null) 'event_id': event.publicId,
        }
      };

  Future<List<GoshenVoucherUsage>> fetchVoucherUsages({
    required Userdata user,
    GoshenRetreatEvent? event,
    int limit = 100,
  }) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_RETREAT_VOUCHER_USAGES,
      options: _mobileOptions(user),
      data: {
        'data': {
          'email': user.email,
          'api_token': user.apiToken,
          if (event != null) 'event_id': event.publicId,
          'limit': limit,
        }
      },
    );

    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load voucher usage.');
    }

    return ((data['data'] as List?) ?? const [])
        .map((item) =>
            GoshenVoucherUsage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<GoshenRegistration> cancelBooking({
    required GoshenRegistration registration,
    required Userdata user,
    String reason = 'Cancelled from the mobile app.',
  }) async {
    try {
      final response = await _dio.post(
        ApiUrl.goshenRetreatCancel(registration.publicId),
        options: _mobileOptions(user),
        data: {
          'data': {
            'email': user.email,
            'api_token': user.apiToken,
            'reason': reason,
          }
        },
      );

      final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
      if (data['status'] != 'ok') {
        throw Exception(data['message'] ?? 'Unable to cancel registration.');
      }

      return GoshenRegistration.fromJson(
        Map<String, dynamic>.from(data['booking'] as Map? ?? {}),
      );
    } on DioException catch (error) {
      throw Exception(_friendlyApiError(
        error,
        'Unable to cancel this registration right now. Please try again shortly.',
      ));
    }
  }

  Options _mobileOptions(Userdata user) {
    final token = (user.apiToken ?? '').trim();
    return Options(
      validateStatus: (status) => status != null && status < 500,
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  String _userCacheKey(Userdata user) {
    final token = (user.apiToken ?? '').trim();
    return token.isNotEmpty ? token : '${user.email ?? ''}'.trim();
  }

  String _friendlyApiError(DioException error, String fallback) {
    final status = error.response?.statusCode ?? 0;
    if (status >= 500) return fallback;

    final responseData = error.response?.data;
    if (responseData is Map) {
      final message = responseData['message'];
      if (message != null && '$message'.trim().isNotEmpty) {
        return '$message';
      }
    }

    if (responseData is String &&
        responseData.trim().isNotEmpty &&
        !responseData.trimLeft().startsWith('<')) {
      return responseData;
    }

    return fallback;
  }
}
