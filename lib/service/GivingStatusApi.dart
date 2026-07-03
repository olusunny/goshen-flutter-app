import 'package:dio/dio.dart';

import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';

class GivingStatusApi {
  GivingStatusApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static Map<String, dynamic>? _statusCache;

  Map<String, dynamic>? get cachedStatus => _statusCache;

  Future<Map<String, dynamic>> fetchStatus() async {
    final response = await _dio.get(ApiUrl.GIVING_STRIPE_STATUS);
    final data = Map<String, dynamic>.from(decodeApiResponse(response.data));
    _statusCache = data;
    return data;
  }
}
