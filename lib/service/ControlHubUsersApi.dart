import 'package:dio/dio.dart';

import '../models/Userdata.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';

class ControlHubUsersApi {
  ControlHubUsersApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<List<ControlHubMobileUser>> fetchUsers(
    Userdata user, {
    String query = '',
  }) async {
    final response = await _dio.post(
      ApiUrl.CONTROL_HUB_MOBILE_USERS_SEARCH,
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          if (query.trim().isNotEmpty) 'query': query.trim(),
        }
      },
    );

    final data = _decodedResponse(response);
    _throwWhenUnavailable(response, data);
    if (data['status'] == 'error') {
      throw Exception(data['message'] ?? 'Unable to load mobile users.');
    }

    final payload = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;
    final rawUsers = payload['users'] ?? payload['data'] ?? payload['items'];
    return ((rawUsers as List?) ?? const [])
        .whereType<Map>()
        .map((item) =>
            ControlHubMobileUser.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ControlHubMobileUser> createUser({
    required Userdata user,
    required Map<String, dynamic> profile,
  }) async {
    final response = await _dio.post(
      ApiUrl.CONTROL_HUB_MOBILE_USERS,
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          ...profile,
        }
      },
    );
    final data = _decodedResponse(response);
    _throwWhenUnavailable(response, data);
    return _userFromResponse(data, 'Unable to create mobile user.');
  }

  Future<ControlHubMobileUser> updateUser({
    required Userdata user,
    required int userId,
    required Map<String, dynamic> profile,
  }) async {
    final response = await _dio.post(
      ApiUrl.controlHubMobileUser('$userId'),
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._authPayload(user),
          ...profile,
        }
      },
    );
    final data = _decodedResponse(response);
    _throwWhenUnavailable(response, data);
    return _userFromResponse(data, 'Unable to update mobile user.');
  }

  Future<void> deleteUser({
    required Userdata user,
    required int userId,
  }) async {
    final response = await _dio.delete(
      ApiUrl.controlHubMobileUser('$userId'),
      options: _mobileOptions(user),
      data: {'data': _authPayload(user)},
    );
    final data = _decodedResponse(response);
    _throwWhenUnavailable(response, data);
    if (data['status'] == 'error') {
      throw Exception(data['message'] ?? 'Unable to delete mobile user.');
    }
  }

  ControlHubMobileUser _userFromResponse(
    Map<String, dynamic> data,
    String fallback,
  ) {
    if (data['status'] == 'error') {
      throw Exception(data['message'] ?? fallback);
    }
    final payload = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;
    final rawUser = payload['user'] ?? payload['mobile_user'] ?? payload;
    return ControlHubMobileUser.fromJson(Map<String, dynamic>.from(rawUser));
  }

  Map<String, dynamic> _decodedResponse(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status == 404 || status == 405 || status == 501) {
      throw const ControlHubUsersUnavailableException();
    }
    final decoded = decodeApiResponse(response.data);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  void _throwWhenUnavailable(
    Response<dynamic> response,
    Map<String, dynamic> data,
  ) {
    final status = response.statusCode ?? 0;
    final message = '${data['message'] ?? data['error'] ?? ''}'.trim();
    if (status == 404 || status == 405 || status == 501) {
      throw const ControlHubUsersUnavailableException();
    }
    if (message.toLowerCase().contains('not found') ||
        message.toLowerCase().contains('not implemented')) {
      throw const ControlHubUsersUnavailableException();
    }
  }

  Map<String, dynamic> _authPayload(Userdata user) {
    return {
      'email': user.email,
      'api_token': user.apiToken,
    };
  }

  Options _mobileOptions(Userdata user) {
    final token = (user.apiToken ?? '').trim();
    return Options(
      validateStatus: (status) => status != null && status < 600,
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }
}

class ControlHubUsersUnavailableException implements Exception {
  const ControlHubUsersUnavailableException();
}

class ControlHubMobileUser {
  const ControlHubMobileUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.profileTitle,
    required this.maritalStatus,
    required this.gender,
    required this.memberType,
    required this.role,
    required this.activated,
  });

  final int id;
  final String name;
  final String email;
  final String phone;
  final String profileTitle;
  final String maritalStatus;
  final String gender;
  final String memberType;
  final String role;
  final int activated;

  factory ControlHubMobileUser.fromJson(Map<String, dynamic> json) {
    return ControlHubMobileUser(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: _readString(json, const ['name', 'full_name']),
      email: _readString(json, const ['email']),
      phone: _readString(json, const ['phone']),
      profileTitle: _readString(
          json, const ['profile_title', 'profileTitle', 'salutation', 'title']),
      maritalStatus:
          _readString(json, const ['marital_status', 'maritalStatus']),
      gender: _readString(json, const ['gender']),
      memberType: _readString(json, const ['member_type', 'memberType']),
      role: _readString(json, const ['role', 'role_name', 'account_type']),
      activated: int.tryParse('${json['activated'] ?? 0}') ?? 0,
    );
  }

  String get displayName => name.trim().isEmpty ? email : name;
  String get statusLabel => activated == 0 ? 'Active' : 'Pending';
}

String _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = '${json[key] ?? ''}'.trim();
    if (raw.isNotEmpty && raw.toLowerCase() != 'null') return raw;
  }
  return '';
}
