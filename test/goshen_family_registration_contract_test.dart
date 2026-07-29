import 'package:churchapp_flutter/models/GoshenFamilyRegistration.dart';
import 'package:churchapp_flutter/models/GoshenRetreat.dart';
import 'package:churchapp_flutter/models/Userdata.dart';
import 'package:churchapp_flutter/service/GoshenRetreatApi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final event = GoshenRetreatEvent.fromJson(const {
    'id': 1,
    'public_id': 'event_1',
    'name': 'Goshen Retreat 2026',
    'ticket_types': [],
  });
  final ticket = GoshenTicketType.fromJson(const {
    'id': 1,
    'public_id': 'family_1',
    'name': 'Goshen Family',
    'currency': 'GBP',
    'price': 300,
  });
  final user = Userdata(email: 'parent@example.test', apiToken: 'api-token');

  test('sends only selected parents and structured manual-age children', () {
    final family = GoshenFamilyRegistrationDraft(
      name: "Adeola's Family",
      father: GoshenFamilyParentDraft(
        included: true,
        firstName: 'David',
        lastName: 'Adeola',
        email: 'parent@example.test',
      ),
      children: [
        GoshenFamilyChildDraft(
          firstName: 'Joy',
          lastName: 'Adeola',
          age: '12',
          gender: 'female',
        ),
        GoshenFamilyChildDraft(
          firstName: 'John',
          lastName: 'Adeola',
          age: '18',
          gender: 'male',
          email: 'john@example.test',
          phone: '+447700900001',
          adultConfirmation: true,
        ),
      ],
    );

    expect(
      family.validationMessage(
        minimumMembers: 2,
        maximumMembers: 6,
        registrantEmail: 'parent@example.test',
        registrantPhone: '',
      ),
      isNull,
    );
    expect(family.payableCount, 2);
    expect(family.complimentaryCount, 1);

    final payload = GoshenRetreatApi.bookingPayload(
      user: user,
      event: event,
      ticketType: ticket,
      quantity: family.memberCount,
      attendees: const [],
      family: family.toPayload(),
    );
    final data = Map<String, dynamic>.from(payload['data'] as Map);
    final familyPayload = Map<String, dynamic>.from(data['family'] as Map);

    expect(familyPayload['name'], "Adeola's Family");
    expect(familyPayload.containsKey('father'), isTrue);
    expect(familyPayload.containsKey('mother'), isFalse);
    expect(familyPayload['children'], [
      {
        'first_name': 'Joy',
        'last_name': 'Adeola',
        'age': 12,
        'gender': 'female',
        'email': '',
        'phone': '',
        'adult_confirmation': false,
      },
      {
        'first_name': 'John',
        'last_name': 'Adeola',
        'age': 18,
        'gender': 'male',
        'email': 'john@example.test',
        'phone': '+447700900001',
        'adult_confirmation': true,
      },
    ]);
    expect(data['attendees'], isEmpty);
  });

  test('enforces a last name and adult identity details for each child', () {
    final noLastName = GoshenFamilyChildDraft(
      firstName: 'Joy',
      age: '12',
      gender: 'female',
    );
    final adultWithoutIdentity = GoshenFamilyChildDraft(
      firstName: 'John',
      lastName: 'Adeola',
      age: '18',
      gender: 'male',
    );

    expect(noLastName.validationMessage(1), "Enter child 1's last name.");
    expect(
      adultWithoutIdentity.validationMessage(2),
      'Children aged 18 or over need an email address and phone number.',
    );
  });

  test('requires one selected parent to match the signed-in account', () {
    final family = GoshenFamilyRegistrationDraft(
      name: 'Example Family',
      father: GoshenFamilyParentDraft(
        included: true,
        firstName: 'David',
        email: 'different@example.test',
      ),
      children: [
        GoshenFamilyChildDraft(
          firstName: 'Joy',
          lastName: 'Example',
          age: '12',
          gender: 'female',
        ),
      ],
    );

    expect(
      family.validationMessage(
        minimumMembers: 2,
        maximumMembers: 6,
        registrantEmail: 'parent@example.test',
        registrantPhone: '+447700900001',
      ),
      'Use your signed-in email address or phone number for at least one parent.',
    );
  });
}
