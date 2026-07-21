import 'package:churchapp_flutter/models/Userdata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts the explicit member-wallet capability from the session API',
      () {
    final user = Userdata.fromJson(const {
      'email': 'admin@example.test',
      'api_token': 'token',
      'roles': ['event_manager'],
      'can_charge_goshen_member_wallet': true,
    });

    expect(user.canChargeManagedMemberWallet, isTrue);
  });

  test('accepts a named member-wallet permission from the session API', () {
    final user = Userdata.fromJson(const {
      'email': 'admin@example.test',
      'api_token': 'token',
      'permissions': ['charge_goshen_member_wallet'],
    });

    expect(user.canChargeManagedMemberWallet, isTrue);
  });

  test('does not infer a member-wallet charge capability from a role', () {
    final user = Userdata.fromJson(const {
      'email': 'admin@example.test',
      'api_token': 'token',
      'roles': ['admin'],
    });

    expect(user.canChargeManagedMemberWallet, isFalse);
  });

  test('persists the explicit capability with the cached session', () {
    final source = Userdata.fromJson(const {
      'email': 'admin@example.test',
      'api_token': 'token',
      'can_charge_goshen_member_wallet': true,
    });

    final cached = Userdata.fromMap(source.toMap());

    expect(cached.canChargeManagedMemberWallet, isTrue);
  });
}
