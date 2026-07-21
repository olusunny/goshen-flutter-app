import 'package:churchapp_flutter/models/GoshenRetreat.dart';
import 'package:churchapp_flutter/models/Userdata.dart';
import 'package:churchapp_flutter/service/GoshenRetreatApi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final user = Userdata(email: 'admin@example.test', apiToken: 'api-token');
  final event = GoshenRetreatEvent.fromJson(const {
    'id': 1,
    'public_id': 'evt_1',
    'name': 'Goshen Retreat 2026',
    'slug': 'goshen-retreat-2026',
    'ticket_types': [],
  });
  final ticketType = GoshenTicketType.fromJson(const {
    'id': 1,
    'public_id': 'ticket_1',
    'name': 'Standard',
    'currency': 'GBP',
    'price': 300,
  });

  test('member wallet booking carries the required admin authorization', () {
    final payload = GoshenRetreatApi.bookingPayload(
      user: user,
      event: event,
      ticketType: ticketType,
      quantity: 1,
      managedMemberId: 96,
      paymentMode: 'wallet',
      adminAuthorization: true,
      adminAuthorizationNote: 'Member confirmed payment by telephone.',
      memberWalletChargeKey: 'mwc_1a2b3c4d_opaque-retry-key',
      attendees: const [
        {
          'first_name': 'Test',
          'last_name': 'Member',
          'email': 'member@example.test',
        },
      ],
    );
    final data = Map<String, dynamic>.from(payload['data'] as Map);

    expect(data['payment_mode'], 'wallet');
    expect(data['managed_member_id'], 96);
    expect(data['admin_authorization'], isTrue);
    expect(
      data['admin_authorization_note'],
      'Member confirmed payment by telephone.',
    );
    expect(data['member_wallet_charge_key'], 'mwc_1a2b3c4d_opaque-retry-key');
    expect(data.containsKey('voucher_code'), isFalse);
  });

  test('member wallet booking rejects a short authorization note', () {
    expect(
      () => GoshenRetreatApi.bookingPayload(
        user: user,
        event: event,
        ticketType: ticketType,
        quantity: 1,
        managedMemberId: 96,
        paymentMode: 'wallet',
        adminAuthorization: true,
        adminAuthorizationNote: 'Confirmed',
      ),
      throwsArgumentError,
    );
  });

  test('self-service wallet booking omits manager authorization fields', () {
    final payload = GoshenRetreatApi.bookingPayload(
      user: user,
      event: event,
      ticketType: ticketType,
      quantity: 1,
      paymentMode: 'wallet',
    );
    final data = Map<String, dynamic>.from(payload['data'] as Map);

    expect(data['payment_mode'], 'wallet');
    expect(data.containsKey('admin_authorization'), isFalse);
    expect(data.containsKey('admin_authorization_note'), isFalse);
    expect(data.containsKey('member_wallet_charge_key'), isFalse);
  });
}
