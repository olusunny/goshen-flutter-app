class ChurchGroupMember {
  const ChurchGroupMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.avatar,
    this.email = '',
    this.gender = '',
    this.aboutMe = '',
  });

  final int id;
  final String name;
  final String phone;
  final String avatar;
  final String email;
  final String gender;
  final String aboutMe;

  factory ChurchGroupMember.fromJson(Map<String, dynamic> json) {
    return ChurchGroupMember(
      id: int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      avatar: '${json['avatar'] ?? ''}',
      email: '${json['email'] ?? ''}',
      gender: '${json['gender'] ?? ''}',
      aboutMe: '${json['about_me'] ?? ''}',
    );
  }
}

class ChurchGroupJoinRequest {
  const ChurchGroupJoinRequest({
    required this.id,
    required this.status,
    required this.message,
    required this.user,
  });

  final int id;
  final String status;
  final String message;
  final ChurchGroupMember user;

  factory ChurchGroupJoinRequest.fromJson(Map<String, dynamic> json) {
    return ChurchGroupJoinRequest(
      id: int.tryParse('${json['id']}') ?? 0,
      status: '${json['status'] ?? ''}',
      message: '${json['message'] ?? ''}',
      user: ChurchGroupMember.fromJson(
        Map<String, dynamic>.from(json['user'] as Map? ?? {}),
      ),
    );
  }
}

class ChurchGroup {
  const ChurchGroup({
    required this.id,
    required this.name,
    required this.functions,
    required this.leaderName,
    required this.leaderAvatar,
    required this.assistantName,
    required this.assistantAvatar,
    required this.membersCount,
    required this.members,
    required this.isActive,
    required this.sortOrder,
    this.pendingRequests = const [],
  });

  final int id;
  final String name;
  final String functions;
  final String leaderName;
  final String leaderAvatar;
  final String assistantName;
  final String assistantAvatar;
  final int membersCount;
  final List<ChurchGroupMember> members;
  final List<ChurchGroupJoinRequest> pendingRequests;
  final bool isActive;
  final int sortOrder;

  factory ChurchGroup.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    final rawRequests = json['pending_requests'];
    return ChurchGroup(
      id: int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? ''}',
      functions: '${json['functions'] ?? ''}',
      leaderName: '${json['leader_name'] ?? ''}',
      leaderAvatar: '${json['leader_avatar'] ?? ''}',
      assistantName: '${json['assistant_name'] ?? ''}',
      assistantAvatar: '${json['assistant_avatar'] ?? ''}',
      membersCount: int.tryParse('${json['members_count']}') ?? 0,
      members: rawMembers is List
          ? rawMembers
              .whereType<Map>()
              .map((item) =>
                  ChurchGroupMember.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
      pendingRequests: rawRequests is List
          ? rawRequests
              .whereType<Map>()
              .map((item) => ChurchGroupJoinRequest.fromJson(
                  Map<String, dynamic>.from(item)))
              .toList()
          : const [],
      isActive: _readBool(json['is_active']),
      sortOrder: int.tryParse('${json['sort_order']}') ?? 0,
    );
  }
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase() ?? '';
  return text == '1' || text == 'true' || text == 'yes';
}
