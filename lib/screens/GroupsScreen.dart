import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../auth/LoginScreen.dart';
import '../models/ChurchGroup.dart';
import '../providers/AppStateManager.dart';
import '../utils/Alerts.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';
import 'NoitemScreen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  static const routeName = '/church-groups';

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  bool isLoading = true;
  bool isError = false;
  List<ChurchGroup> groups = [];

  @override
  void initState() {
    super.initState();
    loadGroups();
  }

  Future<void> loadGroups() async {
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final response = await Dio().get(ApiUrl.FETCH_GROUPS);
      final res = decodeApiResponse(response.data);
      final parsed = (res['groups'] as List? ?? [])
          .whereType<Map>()
          .map((item) => ChurchGroup.fromJson(Map<String, dynamic>.from(item)))
          .where((group) => group.name.toLowerCase() != 'no group')
          .toList();
      if (!mounted) return;
      setState(() {
        groups = parsed;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isError = true;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _GroupsHeader(onBack: () => Navigator.of(context).pop()),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 18));
    }
    if (isError) {
      return NoitemScreen(
        title: 'Ooops!',
        message: 'Unable to load church groups right now. Pull to retry.',
        onClick: loadGroups,
      );
    }
    if (groups.isEmpty) {
      return NoitemScreen(
        title: 'No groups yet',
        message: 'Church groups will appear here once configured by admin.',
        onClick: loadGroups,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF0C2230),
      onRefresh: loadGroups,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _GroupCard(
          group: groups[index],
          onJoin: () => _requestJoin(groups[index]),
        ),
      ),
    );
  }

  Future<void> _requestJoin(ChurchGroup group) async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null || !user.isVerified) {
      Navigator.pushNamed(context, LoginScreen.routeName);
      return;
    }
    try {
      final response = await Dio().post(
        '${ApiUrl.FETCH_GROUPS}/${group.id}/join',
        data: jsonEncode({
          'data': {'email': user.email, 'api_token': user.apiToken}
        }),
      );
      final res = decodeApiResponse(response.data);
      if (!mounted) return;
      Alerts.show(context, 'Group request',
          '${res['message'] ?? 'Your request has been sent.'}');
    } catch (e) {
      if (!mounted) return;
      Alerts.show(context, 'Group request',
          'Unable to send your group request right now.');
    }
  }
}

class _GroupsHeader extends StatelessWidget {
  const _GroupsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 18, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C2230), Color(0xFF153F50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.diversity_3_outlined,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Church Community',
                        style: TextStyle(
                          color: Color(0xFFFFC857),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Church Groups',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Explore church groups, leaders, assistants, functions, and active members.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onJoin});

  final ChurchGroup group;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF102532) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF102532);
    final muted = isDark ? Colors.white60 : const Color(0xFF60707A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB522),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.groups_2_rounded,
                    color: Color(0xFF0C2230), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: text,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      '${group.membersCount} members',
                      style: TextStyle(
                          color: muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (group.functions.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(group.functions,
                style: TextStyle(color: muted, fontSize: 14, height: 1.45)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _GroupRolePill(
                  label: 'Leader',
                  value: group.leaderName.isEmpty
                      ? 'Not assigned'
                      : group.leaderName,
                  avatar: group.leaderAvatar,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GroupRolePill(
                  label: 'Assistant',
                  value: group.assistantName.isEmpty
                      ? 'Not assigned'
                      : group.assistantName,
                  avatar: group.assistantAvatar,
                ),
              ),
            ],
          ),
          if (group.members.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.members.take(8).map((member) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundImage: member.avatar.isEmpty
                        ? null
                        : NetworkImage(member.avatar),
                    child: member.avatar.isEmpty
                        ? Text(member.name.isEmpty ? '?' : member.name[0])
                        : null,
                  ),
                  label: Text(member.name),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onJoin,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Request to join'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB522),
                foregroundColor: const Color(0xFF0C2230),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupRolePill extends StatelessWidget {
  const _GroupRolePill({
    required this.label,
    required this.value,
    required this.avatar,
  });

  final String label;
  final String value;
  final String avatar;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE8EEF2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFFFB522),
            backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
            child: avatar.isEmpty
                ? Icon(Icons.person_outline_rounded,
                    size: 18, color: const Color(0xFF0C2230))
                : null,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color:
                            isDark ? Colors.white54 : const Color(0xFF7B8890),
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF17262A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
