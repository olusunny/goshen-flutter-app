import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/strings.g.dart';
import '../models/Branches.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';
import 'NoitemScreen.dart';

class BranchesScreen extends StatelessWidget {
  static const routeName = "/branches";

  const BranchesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF0C2230),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F8FA),
        body: Column(
          children: [
            _BranchesHeader(onBack: () => Navigator.of(context).pop()),
            Expanded(child: BranchesPageBody()),
          ],
        ),
      ),
    );
  }
}

class BranchesPageBody extends StatefulWidget {
  @override
  _BranchesPageBodyState createState() => _BranchesPageBodyState();
}

class _BranchesPageBodyState extends State<BranchesPageBody> {
  bool isLoading = true;
  bool isError = false;
  List<Branches> items = [];

  Future<void> loadItems() async {
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final response = await Dio().get(ApiUrl.FETCH_BRANCHES);
      final res = decodeApiResponse(response.data);
      final parsed = (res["branches"] as List? ?? [])
          .whereType<Map>()
          .map((json) => Branches.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      setState(() {
        isLoading = false;
        items = parsed;
      });
    } catch (_) {
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 18));
    }
    if (isError) {
      return NoitemScreen(
        title: t.oops,
        message: t.dataloaderror,
        onClick: loadItems,
      );
    }
    if (items.isEmpty) {
      return NoitemScreen(
        title: 'No branches yet',
        message: 'Branch information will appear here once published.',
        onClick: loadItems,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF0C2230),
      onRefresh: loadItems,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => BranchCard(branch: items[index]),
      ),
    );
  }
}

class _BranchesHeader extends StatelessWidget {
  const _BranchesHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
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
                    child: const Icon(
                      Icons.church_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MFM Triumphant Church',
                          style: TextStyle(
                            color: Color(0xFFFFC857),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Our Branches',
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
                'Find branch contacts and open Google Maps directions to worship with us.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BranchCard extends StatelessWidget {
  const BranchCard({Key? key, required this.branch}) : super(key: key);

  final Branches branch;

  Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMaps() async {
    final lat = branch.latitude;
    final lng = branch.longitude;
    final address = (branch.address ?? '').trim();
    final query = lat != null && lng != null ? '$lat,$lng' : address;
    if (query.isEmpty) return;
    await _launch(Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(query)}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = (branch.phone ?? '').trim().isNotEmpty;
    final hasEmail = (branch.email ?? '').trim().isNotEmpty;
    final hasDirectionsTarget = (branch.address ?? '').trim().isNotEmpty ||
        (branch.latitude != null && branch.longitude != null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120C2230),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2230),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.church_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.name ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF102532),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if ((branch.pastor ?? '').isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          branch.pastor!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF60707A),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _BranchInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: branch.address ?? '',
              actionIcon: Icons.directions_outlined,
              onTap: _openMaps,
              isActionEnabled: hasDirectionsTarget,
            ),
            if (hasPhone) ...[
              const SizedBox(height: 10),
              _BranchInfoRow(
                icon: Icons.call_outlined,
                label: 'Phone',
                value: branch.phone!,
                actionIcon: Icons.phone_in_talk_outlined,
                onTap: () => _launch(Uri(scheme: 'tel', path: branch.phone)),
              ),
            ],
            if (hasEmail) ...[
              const SizedBox(height: 10),
              _BranchInfoRow(
                icon: Icons.mail_outline,
                label: 'Email',
                value: branch.email!,
                actionIcon: Icons.outgoing_mail,
                onTap: () => _launch(Uri(scheme: 'mailto', path: branch.email)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BranchInfoRow extends StatelessWidget {
  const _BranchInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.actionIcon,
    required this.onTap,
    this.isActionEnabled,
  });

  final IconData icon;
  final String label;
  final String value;
  final IconData actionIcon;
  final VoidCallback onTap;
  final bool? isActionEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0C2230).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF0C2230)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF7B8890),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? 'Not configured' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF17262A),
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 42,
            height: 42,
            child: ElevatedButton(
              onPressed: (isActionEnabled ?? value.isNotEmpty) ? onTap : null,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: const Color(0xFFFFB522),
                foregroundColor: const Color(0xFF0C2230),
                disabledBackgroundColor: const Color(0xFFE2E8EC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Icon(actionIcon, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
