import 'package:churchapp_flutter/features/church_birthday_celebrations/church_birthday_greeting_store.dart';
import 'package:churchapp_flutter/models/Userdata.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a greeting cache failure does not block birthday detail state',
      () async {
    final store = ChurchBirthdayGreetingStore(
      preferencesLoader: () => Future<SharedPreferences>.error(
        StateError('Local storage unavailable'),
      ),
    );
    final member = Userdata(email: 'member@example.test');

    expect(await store.read(member, 'cb_1'), isNull);
    await store.write(member, 'cb_1', 42);
    await store.clear(member, 'cb_1');
  });
}
