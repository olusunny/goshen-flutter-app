class GoshenFamilyRegistrationDraft {
  GoshenFamilyRegistrationDraft({
    this.name = '',
    GoshenFamilyParentDraft? father,
    GoshenFamilyParentDraft? mother,
    List<GoshenFamilyChildDraft>? children,
  })  : father = father ?? GoshenFamilyParentDraft(included: true),
        mother = mother ?? GoshenFamilyParentDraft(),
        children = children ?? [];

  String name;
  final GoshenFamilyParentDraft father;
  final GoshenFamilyParentDraft mother;
  final List<GoshenFamilyChildDraft> children;

  int get includedParentCount =>
      [father, mother].where((parent) => parent.included).length;

  int get memberCount => includedParentCount + children.length;

  int get payableCount =>
      includedParentCount + children.where((child) => child.isPayable).length;

  int get complimentaryCount =>
      children.where((child) => child.isComplimentary).length;

  Map<String, dynamic> toPayload() => {
        'name': name.trim(),
        if (father.included) 'father': father.toPayload(),
        if (mother.included) 'mother': mother.toPayload(),
        'children': children.map((child) => child.toPayload()).toList(),
      };

  String? validationMessage({
    required int minimumMembers,
    required int maximumMembers,
  }) {
    if (name.trim().isEmpty) return 'Enter a family name.';
    if (name.trim().length > 120) {
      return 'Family name must be 120 characters or fewer.';
    }
    if (includedParentCount == 0) {
      return 'Add at least one parent to the family registration.';
    }
    if (children.length > 18) {
      return 'You can add up to 18 children to one family registration.';
    }
    for (final entry in {'Father': father, 'Mother': mother}.entries) {
      if (entry.value.included && entry.value.firstName.trim().isEmpty) {
        return "Enter the ${entry.key.toLowerCase()}'s first name.";
      }
      if (entry.value.email.trim().isNotEmpty && !_isEmail(entry.value.email)) {
        return 'Enter a valid email address for ${entry.key.toLowerCase()}.';
      }
    }
    for (var index = 0; index < children.length; index += 1) {
      final message = children[index].validationMessage(index + 1);
      if (message != null) return message;
    }
    if (memberCount < minimumMembers) {
      return 'Please add at least $minimumMembers family member${minimumMembers == 1 ? '' : 's'} for this ticket.';
    }
    if (memberCount > maximumMembers) {
      return 'You can register up to $maximumMembers family members with this ticket.';
    }
    return null;
  }
}

class GoshenFamilyParentDraft {
  GoshenFamilyParentDraft({
    this.included = false,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
  });

  bool included;
  String firstName;
  String lastName;
  String email;
  String phone;

  Map<String, dynamic> toPayload() => {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
      };
}

class GoshenFamilyChildDraft {
  GoshenFamilyChildDraft({
    this.firstName = '',
    this.lastName = '',
    this.age = '',
    this.gender = '',
    this.email = '',
    this.phone = '',
    this.adultConfirmation = false,
  });

  String firstName;
  String lastName;
  String age;
  String gender;
  String email;
  String phone;
  bool adultConfirmation;

  int? get parsedAge => int.tryParse(age.trim());
  bool get isAdult => (parsedAge ?? 0) >= 18;
  bool get isPayable => (parsedAge ?? 0) >= 15;
  bool get isComplimentary => (parsedAge ?? 0) >= 1 && !isPayable;

  Map<String, dynamic> toPayload() => {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'age': parsedAge ?? age.trim(),
        'gender': gender.trim().toLowerCase(),
        'email': email.trim(),
        'phone': phone.trim(),
        'adult_confirmation': adultConfirmation,
      };

  String? validationMessage(int position) {
    if (firstName.trim().isEmpty) {
      return "Enter child $position's first name.";
    }
    if (lastName.trim().isEmpty) {
      return "Enter child $position's last name.";
    }
    final value = parsedAge;
    if (value == null || value < 1 || value > 120) {
      return 'Enter a whole age from 1 to 120 for child $position.';
    }
    if (gender.trim().toLowerCase() != 'male' &&
        gender.trim().toLowerCase() != 'female') {
      return 'Select male or female for child $position.';
    }
    if (email.trim().isNotEmpty && !_isEmail(email)) {
      return 'Enter a valid email address for child $position.';
    }
    if (isAdult) {
      if (email.trim().isEmpty || phone.trim().isEmpty) {
        return 'Children aged 18 or over need an email address and phone number.';
      }
      if (!adultConfirmation) {
        return 'Confirm that child $position is 18 or over.';
      }
    }
    return null;
  }
}

bool _isEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
