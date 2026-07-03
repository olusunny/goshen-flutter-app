import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../models/DynamicForm.dart';
import '../models/Userdata.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';

class DynamicFormApi {
  DynamicFormApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static final Map<String, List<DynamicForm>> _formsCache = {};

  List<DynamicForm>? cachedForms(Userdata? user) =>
      _formsCache[_cacheKey(user)];

  Future<List<DynamicForm>> fetchForms(Userdata? user) async {
    final response = await _dio.get(
      ApiUrl.DYNAMIC_FORMS,
      options: _jsonOptions(user),
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load forms.');
    }

    final forms = ((data['data'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => DynamicForm.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    _formsCache[_cacheKey(user)] = forms;
    return forms;
  }

  Future<DynamicForm> fetchForm({
    required String form,
    Userdata? user,
  }) async {
    final response = await _dio.get(
      ApiUrl.dynamicForm(form),
      options: _jsonOptions(user),
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to load this form.');
    }

    final payload = data['data'];
    if (payload is! Map) {
      throw const FormatException('The form response was incomplete.');
    }

    return DynamicForm.fromJson(Map<String, dynamic>.from(payload));
  }

  Future<DynamicFormSubmitResult> submitForm({
    required DynamicForm form,
    required Map<String, dynamic> answers,
    required Map<String, PlatformFile> files,
    required String paymentMethod,
    Userdata? user,
    String? name,
    String? email,
    String? phone,
  }) async {
    final payload = <String, dynamic>{
      'answers': answers,
      if (form.requiresPayment) 'payment_method': paymentMethod,
      if ((name ?? '').trim().isNotEmpty) 'name': name!.trim(),
      if ((email ?? '').trim().isNotEmpty) 'email': email!.trim(),
      if ((phone ?? '').trim().isNotEmpty) 'phone': phone!.trim(),
      if ((user?.apiToken ?? '').trim().isNotEmpty)
        'api_token': user!.apiToken!.trim(),
    };

    final formData = FormData();
    formData.fields.add(MapEntry('data', jsonEncode(payload)));

    for (final entry in files.entries) {
      final path = entry.value.path;
      if (path == null || path.trim().isEmpty) {
        throw Exception('The selected file for ${entry.key} is not available.');
      }
      formData.files.add(MapEntry(
        'files[${entry.key}]',
        await MultipartFile.fromFile(path, filename: entry.value.name),
      ));
    }

    final response = await _dio.post(
      ApiUrl.dynamicFormSubmit(form.identifier),
      options: _jsonOptions(user, multipart: true),
      data: formData,
    );

    final data = _decodeMap(response.data);
    if (data['status'] != 'ok') {
      throw Exception(data['message'] ?? 'Unable to submit this form.');
    }

    return DynamicFormSubmitResult.fromJson(data);
  }

  Options _jsonOptions(Userdata? user, {bool multipart = false}) {
    final token = user?.apiToken?.trim() ?? '';
    return Options(
      validateStatus: (status) => status != null && status < 600,
      headers: {
        'Accept': 'application/json',
        if (!multipart) 'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  Map<String, dynamic> _decodeMap(dynamic value) {
    final decoded = decodeApiResponse(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  String _cacheKey(Userdata? user) {
    final token = user?.apiToken?.trim() ?? '';
    return token.isEmpty ? 'guest' : token;
  }
}
