import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/TransportationArrangement.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';

class TransportationArrangementsScreen extends StatefulWidget {
  const TransportationArrangementsScreen({Key? key}) : super(key: key);

  static const routeName = '/transportation-arrangements';

  @override
  State<TransportationArrangementsScreen> createState() =>
      _TransportationArrangementsScreenState();
}

class _TransportationArrangementsScreenState
    extends State<TransportationArrangementsScreen> {
  bool _isLoading = true;
  bool _isError = false;
  List<TransportationArrangement> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    try {
      final response = await Dio().post(
        ApiUrl.TRANSPORTATION_ARRANGEMENTS,
        data: {
          'data': {'program_name': '72Hours'}
        },
      );

      final res = decodeApiResponse(response.data);
      final raw = res['transportation_arrangements'];
      final parsed = raw is List
          ? raw
              .whereType<Map>()
              .map((json) => TransportationArrangement.fromJson(
                    Map<String, dynamic>.from(json),
                  ))
              .toList()
          : <TransportationArrangement>[];

      if (!mounted) return;
      setState(() {
        _items = parsed;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isError = true;
      });
    }
  }

  Future<void> _call(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) {
      _showMessage('No phone number is available for this contact.');
      return;
    }

    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    _showMessage('This device cannot start a phone call right now.');
  }

  Future<void> _copyPhone(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) {
      _showMessage('No phone number is available to copy.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: cleanPhone));
    _showMessage('Phone number copied.');
  }

  Future<void> _sharePhone(String name, String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) {
      _showMessage('No phone number is available to share.');
      return;
    }

    final cleanName = name.trim().isEmpty ? 'Pickup contact' : name.trim();
    await Share.share(
      '$cleanName\n$cleanPhone\n72Hours transportation contact',
      subject: '72Hours transportation contact',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA),
      body: SafeArea(
        child: Column(
          children: [
            _TransportHeader(onBack: () => Navigator.of(context).pop()),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 18));
    }

    if (_isError) {
      return _TransportStateMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Unable to load transportation',
        message: 'Please check your connection and try again.',
        buttonText: 'Retry',
        onPressed: _loadItems,
      );
    }

    if (_items.isEmpty) {
      return _TransportStateMessage(
        icon: Icons.directions_bus_filled_outlined,
        title: 'No active bus arrangement yet',
        message:
            'Transportation details for 72Hours will appear here once the admin publishes them.',
        buttonText: 'Refresh',
        onPressed: _loadItems,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF0C2230),
      onRefresh: _loadItems,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _TransportCard(
          arrangement: _items[index],
          onCall: _call,
          onCopyPhone: _copyPhone,
          onSharePhone: _sharePhone,
        ),
      ),
    );
  }
}

class _TransportHeader extends StatelessWidget {
  const _TransportHeader({required this.onBack});

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
                  child: const Icon(
                    Icons.directions_bus_filled_outlined,
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
                        '72Hours',
                        style: TextStyle(
                          color: Color(0xFFFFC857),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Transportation Arrangement',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
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
              'Find your city pickup point, driver contact, and location coordinator for the 72Hours program.',
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

class _TransportCard extends StatelessWidget {
  const _TransportCard({
    required this.arrangement,
    required this.onCall,
    required this.onCopyPhone,
    required this.onSharePhone,
  });

  final TransportationArrangement arrangement;
  final Future<void> Function(String phone) onCall;
  final Future<void> Function(String phone) onCopyPhone;
  final Future<void> Function(String name, String phone) onSharePhone;

  @override
  Widget build(BuildContext context) {
    final routeSubtitle = [
      arrangement.eventTitle,
      if (arrangement.state.isNotEmpty) arrangement.state,
    ].where((value) => value.trim().isNotEmpty).join(' • ');

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFECF4F7),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2230),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        arrangement.cityTown,
                        style: const TextStyle(
                          color: Color(0xFF102532),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (routeSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          routeSubtitle,
                          style: const TextStyle(
                            color: Color(0xFF60707A),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2D2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    arrangement.programName,
                    style: const TextStyle(
                      color: Color(0xFF8A5E00),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  icon: Icons.pin_drop_outlined,
                  label: 'Pickup point',
                  value: arrangement.busLocation,
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final pillWidth = (constraints.maxWidth - 20) / 3;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: pillWidth,
                          child: _InfoPill(
                            icon: Icons.airport_shuttle_outlined,
                            label: 'Bus type',
                            value: arrangement.busType.isEmpty
                                ? 'Not specified'
                                : arrangement.busType,
                          ),
                        ),
                        SizedBox(
                          width: pillWidth,
                          child: _InfoPill(
                            icon: Icons.directions_bus_rounded,
                            label: 'Buses',
                            value: arrangement.busesAvailable == null
                                ? 'Not set'
                                : '${arrangement.busesAvailable} ${arrangement.busesAvailable == 1 ? 'bus' : 'buses'}',
                          ),
                        ),
                        SizedBox(
                          width: pillWidth,
                          child: _InfoPill(
                            icon: Icons.groups_2_outlined,
                            label: 'Capacity',
                            value: arrangement.passengerCapacity == null
                                ? 'Not set'
                                : '${arrangement.passengerCapacity} seats',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                if (arrangement.driverName.trim().isNotEmpty ||
                    arrangement.driverPhone.trim().isNotEmpty) ...[
                  _ContactTile(
                    title: arrangement.driverName.isEmpty
                        ? 'Driver'
                        : arrangement.driverName,
                    subtitle: 'Bus driver',
                    phone: arrangement.driverPhone,
                    icon: Icons.person_pin_circle_outlined,
                    onCall: onCall,
                    onCopyPhone: onCopyPhone,
                    onSharePhone: onSharePhone,
                  ),
                  const SizedBox(height: 10),
                ],
                ...arrangement.contacts.asMap().entries.map((entry) {
                  final contact = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          entry.key == arrangement.contacts.length - 1 ? 0 : 10,
                    ),
                    child: _ContactTile(
                      title: contact.name.isEmpty
                          ? 'Location contact'
                          : contact.name,
                      subtitle: arrangement.contacts.length > 1
                          ? 'Pickup contact ${entry.key + 1}'
                          : 'Pickup contact',
                      phone: contact.phone,
                      icon: Icons.support_agent_outlined,
                      onCall: onCall,
                      onCopyPhone: onCopyPhone,
                      onSharePhone: onSharePhone,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF0C2230), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF7B8890),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF17262A),
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0C2230), size: 22),
          const SizedBox(height: 8),
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
            value,
            style: const TextStyle(
              color: Color(0xFF17262A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.title,
    required this.subtitle,
    required this.phone,
    required this.icon,
    required this.onCall,
    required this.onCopyPhone,
    required this.onSharePhone,
  });

  final String title;
  final String subtitle;
  final String phone;
  final IconData icon;
  final Future<void> Function(String phone) onCall;
  final Future<void> Function(String phone) onCopyPhone;
  final Future<void> Function(String name, String phone) onSharePhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE8EEF2)),
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
                  title,
                  style: const TextStyle(
                    color: Color(0xFF17262A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF687780),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  SelectableText(
                    phone.trim(),
                    style: const TextStyle(
                      color: Color(0xFF0C2230),
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ContactActionButton(
                icon: Icons.copy_rounded,
                label: 'Copy phone number',
                backgroundColor: const Color(0xFFECF4F7),
                foregroundColor: const Color(0xFF0C2230),
                onPressed: () => onCopyPhone(phone),
              ),
              const SizedBox(height: 7),
              _ContactActionButton(
                icon: Icons.ios_share_rounded,
                label: 'Share phone number',
                backgroundColor: const Color(0xFFECF4F7),
                foregroundColor: const Color(0xFF0C2230),
                onPressed: () => onSharePhone(title, phone),
              ),
              const SizedBox(height: 7),
              _ContactActionButton(
                icon: Icons.call_rounded,
                label: 'Call phone number',
                backgroundColor: const Color(0xFFFFB522),
                foregroundColor: const Color(0xFF0C2230),
                onPressed: () => onCall(phone),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  const _ContactActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 40,
        height: 40,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            elevation: 0,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _TransportStateMessage extends StatelessWidget {
  const _TransportStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF0C2230).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF0C2230), size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF17262A),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF687780),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C2230),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
