import 'package:churchapp_flutter/models/GoshenRetreat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps payment-exempt child ticket family details from API metadata', () {
    final ticket = GoshenTicket.fromJson(const {
      'public_id': 'ticket_child_1',
      'ticket_number': 'GOSHEN-CHILD-001',
      'attendee_name': 'Joy Adeola',
      'currency': 'GBP',
      'amount_paid': 0,
      'custom_fields': {
        'family_name': "Adeola's Family",
        'family_role': 'child',
        'family_age': 12,
        'gender': 'female',
        'father_name': 'David Adeola',
        'mother_name': 'Grace Adeola',
        'payment_exempt': true,
      },
    });

    expect(ticket.isFamilyMember, isTrue);
    expect(ticket.isChild, isTrue);
    expect(ticket.familyRoleLabel, 'Child');
    expect(ticket.familyAge, 12);
    expect(ticket.genderLabel, 'Female');
    expect(ticket.parentLabel, 'Father: David Adeola · Mother: Grace Adeola');
    expect(ticket.amountPaidLabel, 'Children Complementary Ticket');
    expect(ticket.paymentSummaryLabel, 'Children Complementary Ticket');
  });

  test('does not mislabel a normal unpaid ticket as complimentary', () {
    final ticket = GoshenTicket.fromJson(const {
      'public_id': 'ticket_pending_1',
      'currency': 'GBP',
      'amount_paid': 0,
    });

    expect(ticket.paymentExempt, isFalse);
    expect(ticket.amountPaidLabel, 'Not recorded');
    expect(ticket.paymentSummaryLabel, 'Paid Not recorded');
  });
}
