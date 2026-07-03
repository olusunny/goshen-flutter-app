import 'package:dio/dio.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/Pastor.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';
import 'NoitemScreen.dart';

class PastorsScreen extends StatefulWidget {
  static const routeName = "/pastors";

  const PastorsScreen({Key? key}) : super(key: key);

  @override
  State<PastorsScreen> createState() => _PastorsScreenState();
}

class _PastorsScreenState extends State<PastorsScreen> {
  bool isLoading = true;
  bool isError = false;
  List<Pastor> pastors = [];

  Future<void> loadPastors() async {
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final response = await Dio().get(ApiUrl.FETCH_PASTORS);
      final res = decodeApiResponse(response.data);
      final parsed = (res['pastors'] as List? ?? [])
          .whereType<Map>()
          .map((item) => Pastor.fromJson(Map<String, dynamic>.from(item)))
          .where((pastor) => pastor.imageUrl.isNotEmpty)
          .toList();
      setState(() {
        pastors = parsed;
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        isError = true;
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadPastors();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF0C2230),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: Column(
          children: [
            _PastorsHeader(onBack: () => Navigator.of(context).pop()),
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
        message: 'Unable to load pastors right now. Pull to retry.',
        onClick: loadPastors,
      );
    }
    if (pastors.isEmpty) {
      return NoitemScreen(
        title: 'No pastors listed yet',
        message:
            'Pastors with profile images will appear here once configured.',
        onClick: loadPastors,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF0C2230),
      onRefresh: loadPastors,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        itemCount: pastors.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _PastorCard(pastor: pastors[index]),
      ),
    );
  }
}

class _PastorsHeader extends StatelessWidget {
  const _PastorsHeader({required this.onBack});

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
                    child: const Icon(Icons.groups_2_outlined,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Church Leadership',
                          style: TextStyle(
                            color: Color(0xFFFFC857),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Our Pastors',
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
                'View church pastors and call directly when you need pastoral support.',
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

class _PastorCard extends StatelessWidget {
  const _PastorCard({required this.pastor});

  final Pastor pastor;

  Future<void> _call() async {
    if (pastor.phoneNumber.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: pastor.phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _whatsApp() async {
    final phone = _formatWhatsAppPhone(pastor.phoneNumber);
    if (phone == null) return;

    final appUri = Uri.parse('whatsapp://send?phone=$phone');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
      return;
    }

    final webUri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  String? _formatWhatsAppPhone(String rawPhone) {
    var digits = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('+')) {
      digits = digits.substring(1);
    } else if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length >= 10) {
      digits = '234${digits.substring(1)}';
    } else if (digits.length == 10) {
      digits = '234$digits';
    }

    digits = digits.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length < 8 ? null : digits;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF102532) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF102532);
    final muted = isDark ? Colors.white60 : const Color(0xFF60707A);

    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.network(
              pastor.imageUrl,
              width: 86,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 86,
                height: 96,
                color: const Color(0xFFE7EEF2),
                child: const Icon(Icons.person_outline_rounded, size: 34),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pastor.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: text, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  pastor.roleTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: muted, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed:
                              pastor.phoneNumber.trim().isEmpty ? null : _call,
                          icon: const Icon(Icons.phone_in_talk_outlined,
                              size: 18),
                          label: Text(pastor.phoneNumber.trim().isEmpty
                              ? 'No phone'
                              : 'Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB522),
                            disabledBackgroundColor: isDark
                                ? Colors.white12
                                : const Color(0xFFE2E8EC),
                            foregroundColor: const Color(0xFF0C2230),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed:
                              _formatWhatsAppPhone(pastor.phoneNumber) == null
                                  ? null
                                  : _whatsApp,
                          icon:
                              const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            disabledBackgroundColor: isDark
                                ? Colors.white12
                                : const Color(0xFFE2E8EC),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
