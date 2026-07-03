class Pastor {
  Pastor({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.phoneNumber,
    required this.roleTitle,
    required this.isActive,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final String imageUrl;
  final String phoneNumber;
  final String roleTitle;
  final bool isActive;
  final int sortOrder;

  factory Pastor.fromJson(Map<String, dynamic> json) {
    return Pastor(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      roleTitle: json['role_title']?.toString() ?? 'Pastor',
      isActive: _readBool(json['is_active']),
      sortOrder: int.tryParse(json['sort_order'].toString()) ?? 0,
    );
  }
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase() ?? '';
  return text == '1' || text == 'true' || text == 'yes';
}
