class TransportationArrangement {
  const TransportationArrangement({
    required this.id,
    required this.programName,
    required this.eventTitle,
    required this.cityTown,
    required this.state,
    required this.busLocation,
    required this.busType,
    required this.passengerCapacity,
    required this.busesAvailable,
    required this.driverName,
    required this.driverPhone,
    required this.contactPersonName,
    required this.contactPersonPhone,
    required this.contacts,
    required this.isActive,
  });

  final int id;
  final String programName;
  final String eventTitle;
  final String cityTown;
  final String state;
  final String busLocation;
  final String busType;
  final int? passengerCapacity;
  final int? busesAvailable;
  final String driverName;
  final String driverPhone;
  final String contactPersonName;
  final String contactPersonPhone;
  final List<TransportationContact> contacts;
  final bool isActive;

  factory TransportationArrangement.fromJson(Map<String, dynamic> json) {
    final rawContacts = json['contacts'];
    final contacts = rawContacts is List
        ? rawContacts
            .whereType<Map>()
            .map((contact) => TransportationContact.fromJson(
                  Map<String, dynamic>.from(contact),
                ))
            .where((contact) =>
                contact.name.isNotEmpty || contact.phone.isNotEmpty)
            .toList()
        : <TransportationContact>[];

    if (contacts.isEmpty &&
        ('${json['contact_person_name'] ?? ''}'.trim().isNotEmpty ||
            '${json['contact_person_phone'] ?? ''}'.trim().isNotEmpty)) {
      contacts.add(TransportationContact(
        name: '${json['contact_person_name'] ?? ''}',
        phone: '${json['contact_person_phone'] ?? ''}',
      ));
    }

    return TransportationArrangement(
      id: int.tryParse('${json['id']}') ?? 0,
      programName: '${json['program_name'] ?? '72Hours'}',
      eventTitle: '${json['event_title'] ?? json['program_name'] ?? '72Hours'}',
      cityTown: '${json['city_town'] ?? ''}',
      state: '${json['state'] ?? ''}',
      busLocation: '${json['bus_location'] ?? ''}',
      busType: '${json['bus_type'] ?? ''}',
      passengerCapacity: json['passenger_capacity'] == null
          ? null
          : int.tryParse('${json['passenger_capacity']}'),
      busesAvailable: json['buses_available'] == null
          ? null
          : int.tryParse('${json['buses_available']}'),
      driverName: '${json['driver_name'] ?? ''}',
      driverPhone: '${json['driver_phone'] ?? ''}',
      contactPersonName: '${json['contact_person_name'] ?? ''}',
      contactPersonPhone: '${json['contact_person_phone'] ?? ''}',
      contacts: contacts,
      isActive: json['is_active'] == true || '${json['is_active']}' == '1',
    );
  }
}

class TransportationContact {
  const TransportationContact({
    required this.name,
    required this.phone,
  });

  final String name;
  final String phone;

  factory TransportationContact.fromJson(Map<String, dynamic> json) {
    return TransportationContact(
      name: '${json['name'] ?? ''}'.trim(),
      phone: '${json['phone'] ?? ''}'.trim(),
    );
  }
}
