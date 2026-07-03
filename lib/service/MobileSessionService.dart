import 'package:dio/dio.dart';

import '../models/Userdata.dart';
import '../utils/ApiUrl.dart';

class MobileSessionExpiredException implements Exception {
  final String message;

  MobileSessionExpiredException([this.message = 'Please sign in again.']);

  @override
  String toString() => message;
}

class MobileSessionService {
  final Dio _dio;

  MobileSessionService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {'Accept': 'application/json'},
              validateStatus: (status) => status != null && status < 500,
            ));

  Future<Userdata> sync(Userdata cachedUser) async {
    final token = cachedUser.apiToken?.trim() ?? '';
    if (token.isEmpty) {
      throw MobileSessionExpiredException();
    }

    final response = await _dio.post(
      ApiUrl.SYNC_MOBILE_SESSION,
      data: {
        'data': {
          'email': cachedUser.email,
          'api_token': token,
        },
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final payload = response.data is Map<String, dynamic>
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};

    final authInvalid = payload['auth_invalid'] == true;
    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        authInvalid) {
      throw MobileSessionExpiredException(
        payload['message']?.toString() ?? 'Please sign in again.',
      );
    }

    if (response.statusCode != 200 ||
        payload['status']?.toString().toLowerCase() != 'ok' ||
        payload['user'] is! Map) {
      throw Exception(payload['message']?.toString() ??
          'Unable to verify saved login right now.');
    }

    return Userdata.fromJson(Map<String, dynamic>.from(payload['user'] as Map));
  }
}
