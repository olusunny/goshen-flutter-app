import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../models/ScreenArguements.dart';
import '../models/Userdata.dart';
import '../providers/AppStateManager.dart';
import '../utils/Alerts.dart';
import '../utils/ApiUrl.dart';
import '../utils/my_colors.dart';
import 'UserProfileScreen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const routeName = '/notification-settings';

  @override
  SettingsRouteState createState() => SettingsRouteState();
}

class SettingsRouteState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  final Dio _dio = Dio();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<_NotificationPreferenceItem> _items = [];

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      final userdata =
          Provider.of<AppStateManager>(context, listen: false).userdata;
      if (userdata != null) {
        _loadItems(userdata);
      }
    });
  }

  Future<void> _loadItems(Userdata userdata) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _dio.post(
        ApiUrl.fetchUserSettings,
        data: jsonEncode({
          'data': {
            'email': userdata.email,
            'api_token': userdata.apiToken,
          }
        }),
      );
      final data = _decodeResponse(response.data);

      if (data['status'] == 'error') {
        throw Exception(data['message'] ?? data['msg'] ?? 'Unable to load.');
      }

      final categories = (data['categories'] as List? ?? [])
          .map((item) => _NotificationPreferenceItem.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList();

      if (!mounted) return;
      setState(() {
        _items = categories;
        _loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _error =
            'Unable to load notification preferences right now. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _saveItems(Userdata userdata) async {
    setState(() => _saving = true);
    Alerts.showProgressDialog(context, t.processingpleasewait);

    try {
      final preferences = {
        for (final item in _items) item.key: item.enabled,
      };
      final response = await _dio.post(
        ApiUrl.updateUserSettings,
        data: jsonEncode({
          'data': {
            'email': userdata.email,
            'api_token': userdata.apiToken,
            'notification_preferences': preferences,
          }
        }),
      );
      final data = _decodeResponse(response.data);
      if (mounted) Navigator.of(context).pop();

      if (data['status'] == 'error') {
        Alerts.show(
          context,
          t.error,
          data['message']?.toString() ??
              data['msg']?.toString() ??
              'Unable to save notification preferences.',
        );
      } else {
        final categories = (data['categories'] as List? ?? [])
            .map((item) => _NotificationPreferenceItem.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
        if (mounted) {
          setState(() => _items = categories);
          Alerts.show(context, t.success,
              data['message']?.toString() ?? 'Notification preferences saved.');
        }
      }
    } catch (exception) {
      if (mounted) {
        Navigator.of(context).pop();
        Alerts.show(context, t.error,
            'Unable to save notification preferences right now.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _decodeResponse(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      return Map<String, dynamic>.from(jsonDecode(value) as Map);
    }
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userdata = Provider.of<AppStateManager>(context).userdata;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF071923) : const Color(0xFFF3F8FA);
    final cardColor = dark ? const Color(0xFF0C2230) : Colors.white;
    final textColor = dark ? Colors.white : const Color(0xFF0C2230);
    final muted = dark ? Colors.white70 : const Color(0xFF65717A);
    const gold = Color(0xFFFFB522);

    if (userdata == null) {
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0C2230),
          elevation: 0,
          title: const Text('Notification settings'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_active_outlined,
                      color: MyColors.primary, size: 42),
                  const SizedBox(height: 14),
                  Text(
                    'Sign in to manage notifications',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notification preferences are saved to your account, so please sign in first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C2230),
        elevation: 0,
        title: const Text('Notification settings'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: MyColors.primary,
          onRefresh: () => _loadItems(userdata),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            children: [
              _ProfileCard(
                userdata: userdata,
                cardColor: cardColor,
                textColor: textColor,
                mutedColor: muted,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(dark ? 0.22 : 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: MyColors.primary.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.notifications_active_outlined,
                            color: MyColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose what reaches you',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Turn categories on or off anytime. Essential account and security messages may still be sent.',
                                style: TextStyle(
                                  color: muted,
                                  height: 1.35,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 34),
                          child: CupertinoActivityIndicator(),
                        ),
                      )
                    else if (_error != null)
                      _ErrorState(
                        message: _error!,
                        onRetry: () => _loadItems(userdata),
                      )
                    else
                      ..._items.map(
                        (item) => _PreferenceTile(
                          item: item,
                          dark: dark,
                          textColor: textColor,
                          mutedColor: muted,
                          onChanged: (value) {
                            setState(() => item.enabled = value);
                          },
                        ),
                      ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _saving || _loading
                            ? null
                            : () => _saveItems(userdata),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save preferences'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: const Color(0xFF0C2230),
                          disabledBackgroundColor:
                              gold.withOpacity(dark ? 0.42 : 0.58),
                          disabledForegroundColor:
                              const Color(0xFF0C2230).withOpacity(0.58),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.userdata,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
  });

  final Userdata userdata;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () {
        Navigator.pushNamed(
          context,
          UserProfileScreen.routeName,
          arguments: ScreenArguements(items: userdata),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 56,
                height: 56,
                child: CachedNetworkImage(
                  imageUrl: userdata.avatar ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CupertinoActivityIndicator()),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFFEAF0F2),
                    child: Icon(Icons.person_rounded, color: mutedColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userdata.name ?? 'Member',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userdata.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: mutedColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: mutedColor),
          ],
        ),
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.item,
    required this.dark,
    required this.textColor,
    required this.mutedColor,
    required this.onChanged,
  });

  final _NotificationPreferenceItem item;
  final bool dark;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFB522);
    final tileBackground =
        dark ? const Color(0xFF123142) : const Color(0xFFF5F8FA);
    final iconBackground = item.enabled
        ? (dark ? gold.withOpacity(0.18) : MyColors.primary.withOpacity(0.12))
        : mutedColor.withOpacity(dark ? 0.16 : 0.12);
    final iconColor = item.enabled
        ? (dark ? gold : MyColors.primary)
        : (dark ? Colors.white60 : mutedColor);
    final borderColor = item.enabled
        ? (dark ? gold.withOpacity(0.32) : MyColors.primary.withOpacity(0.34))
        : (dark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.08));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: tileBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _iconFor(item.key),
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mutedColor,
                    height: 1.35,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 54,
            child: Switch(
              value: item.enabled,
              onChanged: onChanged,
              activeThumbColor: dark ? gold : MyColors.primary,
              activeTrackColor:
                  (dark ? gold : MyColors.primary).withOpacity(0.35),
              inactiveThumbColor: dark ? Colors.white70 : Colors.white,
              inactiveTrackColor:
                  dark ? Colors.white.withOpacity(0.18) : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'events':
        return Icons.event_available_rounded;
      case 'media':
        return Icons.play_circle_outline_rounded;
      case 'prayer_wall':
        return Icons.volunteer_activism_rounded;
      case 'prophetic_decree':
        return Icons.mic_rounded;
      case 'testimonies':
        return Icons.auto_awesome_rounded;
      case 'accommodation':
        return Icons.hotel_rounded;
      case 'groups':
        return Icons.groups_rounded;
      case 'giving':
        return Icons.favorite_border_rounded;
      case 'devotional':
      case 'devotionals':
        return Icons.auto_stories_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.35),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _NotificationPreferenceItem {
  _NotificationPreferenceItem({
    required this.key,
    required this.label,
    required this.description,
    required this.enabled,
  });

  final String key;
  final String label;
  final String description;
  bool enabled;

  factory _NotificationPreferenceItem.fromJson(Map<String, dynamic> json) {
    return _NotificationPreferenceItem(
      key: json['key']?.toString() ?? 'general',
      label: json['label']?.toString() ?? 'Notification',
      description: json['description']?.toString() ?? '',
      enabled: _readBool(json['enabled']),
    );
  }
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  if (value == null) return true;
  final text = value.toString().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes' || text == 'on';
}
