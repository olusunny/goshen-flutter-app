import 'package:churchapp_flutter/models/Userdata.dart';
import 'package:churchapp_flutter/service/MobileSessionService.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session sync retains the existing token when profile data omits it',
      () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: const {
          'status': 'ok',
          'user': {'id': 1, 'email': 'member@example.test'},
        },
      )),
    ));

    final refreshed = await MobileSessionService(dio: dio).sync(
      Userdata(apiToken: 'saved-token', email: 'member@example.test'),
    );

    expect(refreshed.apiToken, 'saved-token');
  });
}
