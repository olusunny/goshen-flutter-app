import 'package:dio/dio.dart';

import '../models/GoshenQuiz.dart';
import '../models/Userdata.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';
import 'MobileSessionService.dart';

class GoshenQuizApi {
  GoshenQuizApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static final Map<String, List<GoshenQuiz>> _quizCache = {};

  List<GoshenQuiz>? cachedQuizzes(Userdata? user) => _quizCache[_key(user)];

  Future<GoshenQuizManagementSummary> fetchManagementSummary(
    Userdata user,
  ) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_QUIZ_MANAGEMENT_SUMMARY,
      options: _mobileOptions(user),
      data: {'data': _payload(user)},
    );
    final data = _decode(response.data);
    _throwIfSessionExpired(response.statusCode, data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load quiz management.');
    }
    return GoshenQuizManagementSummary.fromJson(
      Map<String, dynamic>.from(data['data'] ?? const {}),
    );
  }

  Future<List<GoshenQuiz>> fetchQuizzes(Userdata user) async {
    final response = await _dio.post(
      ApiUrl.GOSHEN_QUIZZES,
      options: _mobileOptions(user),
      data: {'data': _payload(user)},
    );
    final data = _decode(response.data);
    _throwIfSessionExpired(response.statusCode, data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load quizzes.');
    }
    final quizzes = ((data['data'] as List?) ?? const [])
        .map((item) => GoshenQuiz.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    _quizCache[_key(user)] = quizzes;
    return quizzes;
  }

  Future<GoshenQuiz> fetchQuiz(Userdata user, int quizId) async {
    final response = await _dio.post(
      ApiUrl.goshenQuiz('$quizId'),
      options: _mobileOptions(user),
      data: {'data': _payload(user)},
    );
    final data = _decode(response.data);
    _throwIfSessionExpired(response.statusCode, data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load quiz.');
    }
    return GoshenQuiz.fromJson(Map<String, dynamic>.from(data['data']));
  }

  Future<GoshenQuiz> startQuiz(Userdata user, int quizId) async {
    final response = await _dio.post(
      ApiUrl.goshenQuizStart('$quizId'),
      options: _mobileOptions(user),
      data: {'data': _payload(user)},
    );
    final data = _decode(response.data);
    _throwIfSessionExpired(response.statusCode, data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to start quiz.');
    }
    return GoshenQuiz.fromJson(Map<String, dynamic>.from(data['quiz']));
  }

  Future<GoshenQuiz> submitQuiz(
    Userdata user,
    int quizId,
    Map<int, dynamic> answers,
  ) async {
    final encodedAnswers = <String, dynamic>{};
    answers.forEach((key, value) {
      encodedAnswers['$key'] = value;
    });

    final response = await _dio.post(
      ApiUrl.goshenQuizSubmit('$quizId'),
      options: _mobileOptions(user),
      data: {
        'data': {
          ..._payload(user),
          'answers': encodedAnswers,
        },
      },
    );
    final data = _decode(response.data);
    _throwIfSessionExpired(response.statusCode, data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to submit quiz.');
    }
    return GoshenQuiz.fromJson(Map<String, dynamic>.from(data['quiz']));
  }

  Future<GoshenQuizWinner> payWinnerPrize(
    Userdata user,
    int quizId,
    int winnerId,
  ) async {
    final response = await _dio.post(
      ApiUrl.goshenQuizWinnerPrize('$quizId', '$winnerId'),
      options: _mobileOptions(user),
      data: {'data': _payload(user)},
    );
    final data = _decode(response.data);
    _throwIfSessionExpired(response.statusCode, data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to fund winner prize.');
    }
    return GoshenQuizWinner.fromJson(
      Map<String, dynamic>.from(data['winner']),
    );
  }

  Future<GoshenQuizManagementRow> updateQuizSettings(
    Userdata user,
    GoshenQuizManagementRow quiz, {
    bool? isActive,
    bool? autoSelectWinners,
    bool? showWinnersImmediately,
    bool? walletPrizeEnabled,
    int? winnersCount,
  }) async {
    final updates = <String, dynamic>{
      ..._payload(user),
      if (isActive != null) 'is_active': isActive,
      if (autoSelectWinners != null) 'auto_select_winners': autoSelectWinners,
      if (showWinnersImmediately != null)
        'show_winners_immediately': showWinnersImmediately,
      if (walletPrizeEnabled != null)
        'wallet_prize_enabled': walletPrizeEnabled,
      if (winnersCount != null) 'winners_count': winnersCount,
    };

    final response = await _dio.post(
      ApiUrl.goshenQuizSettings('${quiz.id}'),
      options: _mobileOptions(user),
      data: {'data': updates},
    );
    final data = _decode(response.data);
    _throwIfSessionExpired(response.statusCode, data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to update quiz settings.');
    }
    return GoshenQuizManagementRow.fromJson(
      Map<String, dynamic>.from(data['quiz'] ?? const {}),
    );
  }

  Options _mobileOptions(Userdata user) {
    final token = user.apiToken?.trim() ?? '';
    return Options(
      validateStatus: (status) => status != null && status < 600,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  Map<String, dynamic> _payload(Userdata user) => {
        'email': user.email,
        'api_token': user.apiToken,
      };

  Map<String, dynamic> _decode(dynamic value) {
    final decoded = decodeApiResponse(value);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  void _throwIfSessionExpired(int? statusCode, Map<String, dynamic> data) {
    if (statusCode == 401 || data['auth_invalid'] == true) {
      throw MobileSessionExpiredException(
        data['message']?.toString() ?? 'Please sign in again.',
      );
    }
  }

  static String _key(Userdata? user) => user?.email?.trim().toLowerCase() ?? '';
}
