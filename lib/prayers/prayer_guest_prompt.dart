import 'package:flutter/material.dart';

import '../auth/LoginScreen.dart';
import '../auth/RegisterScreen.dart';

Future<void> showPrayerGuestPrompt(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final card = isDark ? const Color(0xFF102532) : Colors.white;
  final text = isDark ? Colors.white : const Color(0xFF102532);
  final muted = isDark ? Colors.white70 : const Color(0xFF60707A);

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.58),
    builder: (dialogContext) {
      final media = MediaQuery.of(dialogContext);
      final maxHeight = (media.size.height - media.viewInsets.vertical - 32)
          .clamp(320.0, 720.0)
          .toDouble();

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: card,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.16),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: _PrayerPromptGraphicPainter()),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFC857), Color(0xFFFFB522)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFB522)
                                    .withValues(alpha: .3),
                                blurRadius: 18,
                                offset: const Offset(0, 9),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.volunteer_activism_rounded,
                            color: Color(0xFF0C2230),
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Join the Interactive Prayer Wall',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: text,
                            fontSize: 21,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Register or sign in to post prayer requests and take part in the church prayer community.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 14.5,
                            height: 1.42,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PromptFeature(
                          icon: Icons.campaign_rounded,
                          text:
                              'The church Pastor shares a Daily Prophetic Decree over the prayer wall.',
                          color: text,
                          muted: muted,
                        ),
                        _PromptFeature(
                          icon: Icons.mic_rounded,
                          text:
                              'Submit by typing or recording a voice prayer, and choose to post anonymously.',
                          color: text,
                          muted: muted,
                        ),
                        _PromptFeature(
                          icon: Icons.auto_fix_high_rounded,
                          text:
                              'Use AI to rewrite your prayer text before sending it with clarity and care.',
                          color: text,
                          muted: muted,
                        ),
                        _PromptFeature(
                          icon: Icons.groups_rounded,
                          text:
                              'Other members can intentionally respond and pray with voice notes in one community.',
                          color: text,
                          muted: muted,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  Navigator.pushNamed(
                                      context, LoginScreen.routeName);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: text,
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: .13)
                                        : const Color(0xFFE4EBEF),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.w900),
                                ),
                                child: const Text('Sign in'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  Navigator.pushNamed(
                                      context, RegisterScreen.routeName);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB522),
                                  foregroundColor: const Color(0xFF0C2230),
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.w900),
                                ),
                                child: const Text('Register'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PromptFeature extends StatelessWidget {
  const _PromptFeature({
    required this.icon,
    required this.text,
    required this.color,
    required this.muted,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC857).withValues(alpha: .16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFFFB522), size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: muted,
                fontSize: 13.4,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerPromptGraphicPainter extends CustomPainter {
  const _PrayerPromptGraphicPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFC857).withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * .12, size.height * .06),
        radius: size.width * .72,
      ));
    final line = Paint()
      ..color = const Color(0xFFFFC857).withValues(alpha: .14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;

    canvas.drawRect(Offset.zero & size, glow);
    canvas.drawCircle(Offset(size.width * .96, size.height * .04), 80, line);
    canvas.drawCircle(Offset(size.width * .96, size.height * .04), 126, line);
  }

  @override
  bool shouldRepaint(covariant _PrayerPromptGraphicPainter oldDelegate) =>
      false;
}
