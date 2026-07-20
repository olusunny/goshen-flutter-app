import 'package:churchapp_flutter/service/ControlHubUsersApi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a Control Hub wallet voucher redemption response', () {
    final result = ControlHubWalletVoucherRedemption.fromJson(const {
      'message': 'Voucher added to Member Goshen wallet.',
      'usage': {
        'amount': 25.01,
        'currency': 'GBP',
      },
      'data': {
        'currency': 'GBP',
        'balance': 35.02,
      },
    });

    expect(result.message, 'Voucher added to Member Goshen wallet.');
    expect(result.amount, 25.01);
    expect(result.currency, 'GBP');
    expect(result.balance, 35.02);
  });
}
