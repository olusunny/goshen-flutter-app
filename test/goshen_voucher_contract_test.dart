import 'package:churchapp_flutter/models/GoshenRetreat.dart';
import 'package:churchapp_flutter/models/Userdata.dart';
import 'package:churchapp_flutter/service/GoshenRetreatApi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retreat date label uses event start and end dates without schedules',
      () {
    final event = GoshenRetreatEvent.fromJson(const {
      'id': 1,
      'public_id': 'evt_1',
      'name': 'Goshen Retreat 2026',
      'slug': 'goshen-retreat-2026',
      'start_date': '2026-08-05',
      'end_date': '2026-08-08',
      'schedules': [],
      'ticket_types': [],
    });

    expect(event.dateLabel, 'Aug 5, 2026 - Aug 8, 2026');
    expect(event.countdownTarget, DateTime(2026, 8, 5));
  });

  test('wallet funding voucher exposes the correct purpose label', () {
    final voucher = GoshenVoucherInfo.fromJson(const {
      'id': 1,
      'purpose': 'wallet_funding',
      'currency': 'GBP',
      'amount': 25,
    });

    expect(voucher.purpose, GoshenVoucherInfo.purposeWalletFunding);
    expect(voucher.purposeLabel, 'Wallet Funding');
  });

  test('legacy voucher payload defaults to payment purpose', () {
    final voucher = GoshenVoucherInfo.fromJson(const {
      'id': 1,
      'currency': 'GBP',
      'amount': 25,
    });

    expect(voucher.purpose, GoshenVoucherInfo.purposePayments);
    expect(voucher.purposeLabel, 'For Payments');
  });

  test('wallet funding generation payload omits event id', () {
    final user = Userdata(
      email: 'manager@example.test',
      apiToken: 'api-token',
    );

    final payload = GoshenRetreatApi.voucherGenerationPayload(
      user: user,
      label: ' Wallet funding ',
      amount: 25,
      currency: 'gbp',
      quantity: 1,
      maxUses: 1,
      purpose: GoshenVoucherInfo.purposeWalletFunding,
      redemptionType: GoshenVoucherInfo.redemptionFixed,
    );
    final data = Map<String, dynamic>.from(payload['data'] as Map);

    expect(data['purpose'], GoshenVoucherInfo.purposeWalletFunding);
    expect(data['label'], 'Wallet funding');
    expect(data['currency'], 'GBP');
    expect(data.containsKey('event_id'), isFalse);
  });
}
