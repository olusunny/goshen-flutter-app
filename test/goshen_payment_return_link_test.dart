import 'package:churchapp_flutter/utils/goshen_payment_return_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseGoshenPaymentReturnLink', () {
    test('recognizes wallet success from portal HTTPS return URL', () {
      final result = parseGoshenPaymentReturnLink(Uri.parse(
        'https://portal.goshenretreat.uk/app/wallet?wallet=success&session_id=cs_test_123',
      ));

      expect(result, isNotNull);
      expect(result!.success, isTrue);
      expect(result.flow, GoshenPaymentReturnFlow.wallet);
      expect(result.wallet, isTrue);
    });

    test('recognizes wallet cancellation from portal HTTPS return URL', () {
      final result = parseGoshenPaymentReturnLink(Uri.parse(
        'https://portal.goshenretreat.uk/app/wallet?wallet=cancelled',
      ));

      expect(result, isNotNull);
      expect(result!.success, isFalse);
      expect(result.flow, GoshenPaymentReturnFlow.wallet);
    });

    test('recognizes retreat checkout return from portal HTTPS URL', () {
      final result = parseGoshenPaymentReturnLink(Uri.parse(
        'https://portal.goshenretreat.uk/app/payments?checkout=success&session_id=cs_test_123',
      ));

      expect(result, isNotNull);
      expect(result!.success, isTrue);
      expect(result.flow, GoshenPaymentReturnFlow.retreat);
    });

    test('recognizes triumphant custom wallet scheme', () {
      final result = parseGoshenPaymentReturnLink(Uri.parse(
        'triumphant://goshen-wallet/success?session_id=cs_test_123',
      ));

      expect(result, isNotNull);
      expect(result!.success, isTrue);
      expect(result.flow, GoshenPaymentReturnFlow.wallet);
    });

    test('recognizes custom giving scheme by flow query', () {
      final result = parseGoshenPaymentReturnLink(Uri.parse(
        'triumphant://goshen-payment/success?flow=giving&session_id=cs_test_123',
      ));

      expect(result, isNotNull);
      expect(result!.success, isTrue);
      expect(result.flow, GoshenPaymentReturnFlow.giving);
      expect(result.wallet, isFalse);
    });

    test('ignores the portal home path without checkout status', () {
      final result = parseGoshenPaymentReturnLink(Uri.parse(
        'https://portal.goshenretreat.uk/app',
      ));

      expect(result, isNull);
    });
  });
}
