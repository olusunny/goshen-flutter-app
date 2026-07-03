class DonationAccountCategory {
  const DonationAccountCategory({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.flagIcon,
    required this.color,
    required this.accounts,
  });

  final int id;
  final String name;
  final String currencyCode;
  final String flagIcon;
  final String color;
  final List<DonationBankAccount> accounts;

  factory DonationAccountCategory.fromJson(Map<String, dynamic> json) {
    return DonationAccountCategory(
      id: int.parse(json['id'].toString()),
      name: (json['name'] ?? '').toString(),
      currencyCode: (json['currency_code'] ?? '').toString(),
      flagIcon: (json['flag_icon'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      accounts: ((json['accounts'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => DonationBankAccount.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }
}

class DonationBankAccount {
  const DonationBankAccount({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.sortCode,
    required this.routingNumber,
    required this.swiftCode,
    required this.iban,
    required this.instructions,
  });

  final int id;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String sortCode;
  final String routingNumber;
  final String swiftCode;
  final String iban;
  final String instructions;

  factory DonationBankAccount.fromJson(Map<String, dynamic> json) {
    return DonationBankAccount(
      id: int.parse(json['id'].toString()),
      bankName: (json['bank_name'] ?? '').toString(),
      accountName: (json['account_name'] ?? '').toString(),
      accountNumber: (json['account_number'] ?? '').toString(),
      sortCode: (json['sort_code'] ?? '').toString(),
      routingNumber: (json['routing_number'] ?? '').toString(),
      swiftCode: (json['swift_code'] ?? '').toString(),
      iban: (json['iban'] ?? '').toString(),
      instructions: (json['instructions'] ?? '').toString(),
    );
  }
}
