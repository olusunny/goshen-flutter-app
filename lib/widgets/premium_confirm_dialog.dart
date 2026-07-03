import 'package:flutter/material.dart';

class PremiumConfirmDialog extends StatelessWidget {
  const PremiumConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel = 'Cancel',
    this.icon = Icons.warning_amber_rounded,
    this.confirmIcon = Icons.check_rounded,
    this.confirmColor = const Color(0xFFFFB522),
    this.isDanger = false,
  });

  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final IconData icon;
  final IconData confirmIcon;
  final Color confirmColor;
  final bool isDanger;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF102532) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF102532);
    final muted = isDark ? Colors.white70 : const Color(0xFF60707A);
    final actionColor = isDanger ? const Color(0xFFE53935) : confirmColor;
    final actionText = isDanger ? Colors.white : const Color(0xFF0C2230);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: card,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.18),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _PremiumDialogGraphicPainter()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isDanger
                              ? const [Color(0xFFFF7B7B), Color(0xFFE53935)]
                              : const [Color(0xFFFFC857), Color(0xFFFFB522)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: actionColor.withValues(
                                alpha: isDark ? 0.22 : 0.32),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color:
                            isDanger ? Colors.white : const Color(0xFF0C2230),
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
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
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: muted,
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: text,
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : const Color(0xFFE4EBEF),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            child: Text(cancelLabel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onConfirm,
                            icon: Icon(confirmIcon, size: 19),
                            label: Text(confirmLabel),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: actionColor,
                              foregroundColor: actionText,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.w900),
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
        ),
      ),
    );
  }
}

class _PremiumDialogGraphicPainter extends CustomPainter {
  const _PremiumDialogGraphicPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final goldFill = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFC857).withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.12, size.height * 0.08),
        radius: size.width * 0.72,
      ));
    final tealFill = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0C2230).withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.94, size.height * 0.08),
        radius: size.width * 0.58,
      ));

    canvas.drawRect(Offset.zero & size, goldFill);
    canvas.drawRect(Offset.zero & size, tealFill);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFFC857).withValues(alpha: 0.16);

    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.1),
        34.0 + (i * 22),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
