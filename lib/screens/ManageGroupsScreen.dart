import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/LoginScreen.dart';
import '../models/ChurchGroup.dart';
import '../providers/AppStateManager.dart';
import '../utils/Alerts.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';
import 'NoitemScreen.dart';

class ManageGroupsScreen extends StatefulWidget {
  const ManageGroupsScreen({Key? key}) : super(key: key);

  static const routeName = '/manage-groups';

  @override
  State<ManageGroupsScreen> createState() => _ManageGroupsScreenState();
}

class _ManageGroupsScreenState extends State<ManageGroupsScreen> {
  bool _loading = true;
  bool _error = false;
  bool _accessDenied = false;
  String _message = 'Could not load your managed groups right now.';
  List<ChurchGroup> _groups = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null || !user.isVerified) {
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      return;
    }
    if (!user.canManageChurchGroups) {
      setState(() {
        _loading = false;
        _error = true;
        _accessDenied = true;
        _message =
            'Only assigned group leaders and assistant group leaders can view and manage church groups.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
      _accessDenied = false;
      _message = 'Could not load your managed groups right now.';
    });
    try {
      final response = await Dio().post(
        ApiUrl.MANAGE_GROUPS,
        data: jsonEncode({
          'data': {'email': user.email, 'api_token': user.apiToken}
        }),
      );
      final res = decodeApiResponse(response.data);
      final groups = (res['groups'] as List? ?? [])
          .whereType<Map>()
          .map((item) => ChurchGroup.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final body = error.response?.data;
      final serverMessage = body is Map
          ? '${body['message'] ?? ''}'.trim()
          : '${error.message ?? ''}'.trim();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
        _accessDenied = statusCode == 401 || statusCode == 403;
        _message = _accessDenied
            ? (serverMessage.isNotEmpty
                ? serverMessage
                : 'Only assigned group leaders and assistant group leaders can view and manage church groups.')
            : 'Could not load your managed groups right now.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
        _accessDenied = false;
        _message = 'Could not load your managed groups right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Manage Groups')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CupertinoActivityIndicator());
    if (_error) {
      return NoitemScreen(
        title: _accessDenied ? 'Access restricted' : 'Unable to load',
        message: _message,
        onClick: _load,
      );
    }
    if (_groups.isEmpty) {
      return NoitemScreen(
        title: 'No managed groups',
        message:
            'Only assigned group leaders and assistants can manage groups.',
        onClick: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search members by name or phone',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: 16),
          ..._groups.map((group) => _ManagedGroupCard(
                group: group,
                query: _query,
                onChanged: _load,
              )),
        ],
      ),
    );
  }
}

class _ManagedGroupCard extends StatelessWidget {
  const _ManagedGroupCard({
    required this.group,
    required this.query,
    required this.onChanged,
  });

  final ChurchGroup group;
  final String query;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF102532) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF102532);
    final muted = isDark ? Colors.white60 : const Color(0xFF60707A);
    final filteredMembers = group.members.where((member) {
      final q = query.toLowerCase();
      return q.isEmpty ||
          member.name.toLowerCase().contains(q) ||
          member.phone.toLowerCase().contains(q);
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.name,
              style: TextStyle(
                  color: text, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${group.pendingRequests.length} pending requests',
              style: TextStyle(color: muted)),
          const SizedBox(height: 14),
          if (group.pendingRequests.isNotEmpty) ...[
            Text('Joining Requests',
                style: TextStyle(color: text, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...group.pendingRequests.map((request) => _JoinRequestTile(
                  groupId: group.id,
                  request: request,
                  onChanged: onChanged,
                )),
            const SizedBox(height: 14),
          ],
          Text('Members',
              style: TextStyle(color: text, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (filteredMembers.isEmpty)
            Text('No matching members.', style: TextStyle(color: muted))
          else
            ...filteredMembers.map((member) => _MemberTile(
                  groupId: group.id,
                  member: member,
                  onChanged: onChanged,
                )),
        ],
      ),
    );
  }
}

class _JoinRequestTile extends StatelessWidget {
  const _JoinRequestTile({
    required this.groupId,
    required this.request,
    required this.onChanged,
  });

  final int groupId;
  final ChurchGroupJoinRequest request;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return _PersonTile(
      member: request.user,
      trailing: Wrap(
        spacing: 6,
        children: [
          IconButton(
            tooltip: 'Approve',
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: () => _review(context, 'approve'),
          ),
          IconButton(
            tooltip: 'Reject',
            icon: const Icon(Icons.cancel, color: Colors.redAccent),
            onPressed: () => _review(context, 'reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _review(BuildContext context, String action) async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    try {
      await Dio().post(
        '${ApiUrl.BASEURL}church_group_requests/${request.id}/review',
        data: jsonEncode({
          'data': {
            'email': user?.email,
            'api_token': user?.apiToken,
            'action': action,
          }
        }),
      );
      await onChanged();
    } catch (_) {
      Alerts.show(context, 'Group request',
          'Unable to $action this request right now.');
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.groupId,
    required this.member,
    required this.onChanged,
  });

  final int groupId;
  final ChurchGroupMember member;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return _PersonTile(
      member: member,
      trailing: IconButton(
        tooltip: 'Remove from group',
        icon: const Icon(Icons.person_remove_alt_1_outlined),
        onPressed: () => _remove(context),
      ),
    );
  }

  Future<void> _remove(BuildContext context) async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    try {
      await Dio().post(
        '${ApiUrl.FETCH_GROUPS}/$groupId/members/${member.id}/remove',
        data: jsonEncode({
          'data': {'email': user?.email, 'api_token': user?.apiToken}
        }),
      );
      await onChanged();
    } catch (_) {
      Alerts.show(
          context, 'Group member', 'Unable to remove this member right now.');
    }
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.member, required this.trailing});

  final ChurchGroupMember member;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : const Color(0xFF102532);
    final muted = isDark ? Colors.white60 : const Color(0xFF60707A);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage:
            member.avatar.isEmpty ? null : NetworkImage(member.avatar),
        child: member.avatar.isEmpty
            ? Text(member.name.isEmpty ? '?' : member.name[0])
            : null,
      ),
      title: Text(member.name,
          style: TextStyle(color: text, fontWeight: FontWeight.w800)),
      subtitle: Text(
        [member.phone, member.email]
            .where((item) => item.isNotEmpty)
            .join('\n'),
        style: TextStyle(color: muted),
      ),
      trailing: trailing,
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(member.name),
          content: Text(
            [
              if (member.phone.isNotEmpty) 'Phone: ${member.phone}',
              if (member.email.isNotEmpty) 'Email: ${member.email}',
              if (member.gender.isNotEmpty) 'Gender: ${member.gender}',
              if (member.aboutMe.isNotEmpty) 'About: ${member.aboutMe}',
            ].join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
