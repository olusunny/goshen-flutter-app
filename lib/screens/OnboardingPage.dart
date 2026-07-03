import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../providers/AppStateManager.dart';
import '../screens/HomePage.dart';
import '../utils/my_colors.dart';
import '../utils/TextStyles.dart';
import '../models/Onboarder.dart';
import '../i18n/strings.g.dart';

class OnboardingPage extends StatefulWidget {
  static const routeName = "/onboarding";
  OnboardingPage();

  @override
  OnboarderPageState createState() => new OnboarderPageState();
}

class OnboarderPageState extends State<OnboardingPage> {
  final List<Onboarder> onboarderItem = Onboarder.getOnboardingItems(
      t.onboardingpagetitles, t.onboardingpagehints);
  PageController pageController = PageController(
    initialPage: 0,
  );
  int page = 0;
  bool isLast = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Container(color: Colors.grey[100])),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Column(children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                PageView(
                  onPageChanged: onPageViewChange,
                  controller: pageController,
                  children: buildPageViewItem(),
                ),
                Row(
                  children: <Widget>[
                    const Spacer(),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14, top: 8),
                        child: IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: MyColors.grey_40),
                          onPressed: _finishOnboarding,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: buildDots(context),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C2230),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                onPressed: () {
                  if (isLast) {
                    _finishOnboarding();
                    return;
                  }
                  pageController.nextPage(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLast ? t.done : t.next,
                      style: TextStyles.subhead(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLast ? Icons.home_rounded : Icons.arrow_forward_rounded,
                      color: const Color(0xFFFFC857),
                    ),
                  ],
                ),
              ),
            ),
          )
        ]),
      ),
    );
  }

  void _finishOnboarding() {
    Provider.of<AppStateManager>(context, listen: false)
        .setUserSeenOnboardingPage(true);
    Navigator.pushReplacementNamed(context, HomePage.routeName);
  }

  void onPageViewChange(int _page) {
    page = _page;
    isLast = _page == onboarderItem.length - 1;
    setState(() {});
  }

  List<Widget> buildPageViewItem() {
    List<Widget> widgets = [];
    for (int index = 0; index < onboarderItem.length; index++) {
      final onboarder = onboarderItem[index];
      final copy = _OnboardingCopy.forIndex(index, onboarder);
      Widget wg = Container(
        padding: const EdgeInsets.fromLTRB(28, 72, 28, 20),
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 430),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.055),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _OnboardingGraphicPainter(index: index),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 228,
                        height: 228,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FBFC),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE8EEF2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Lottie.asset(
                            onboarder.image,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        copy.title,
                        textAlign: TextAlign.center,
                        style: TextStyles.medium(context).copyWith(
                            color: const Color(0xFF102532),
                            fontFamily: "serif",
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                            fontSize: 25),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 92,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC857),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        copy.hint,
                        textAlign: TextAlign.center,
                        style: TextStyles.subhead(context).copyWith(
                          color: const Color(0xFF60707A),
                          fontSize: 16,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      );
      widgets.add(wg);
    }
    return widgets;
  }

  Widget buildDots(BuildContext context) {
    Widget widget;

    List<Widget> dots = [];
    for (int i = 0; i < onboarderItem.length; i++) {
      final selected = page == i;
      Widget w = AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 8,
        width: selected ? 24 : 8,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0C2230) : MyColors.grey_20,
          borderRadius: BorderRadius.circular(99),
        ),
      );
      dots.add(w);
    }
    widget = Row(
      mainAxisSize: MainAxisSize.min,
      children: dots,
    );
    return widget;
  }
}

class _OnboardingCopy {
  const _OnboardingCopy({required this.title, required this.hint});

  final String title;
  final String hint;

  static _OnboardingCopy forIndex(int index, Onboarder fallback) {
    const copies = [
      _OnboardingCopy(
        title: 'Welcome to MFM Triumphant Church',
        hint:
            'Stay close to worship, teaching, prayer, and church updates wherever you are.',
      ),
      _OnboardingCopy(
        title: 'Everything in One Place',
        hint:
            'Find events, Bible tools, notes, giving, branches, and church resources with ease.',
      ),
      _OnboardingCopy(
        title: 'Messages and Live Worship',
        hint:
            'Watch videos, listen to audio messages, and join live services from anywhere.',
      ),
      _OnboardingCopy(
        title: 'Join the Community',
        hint:
            'Create your account to share prayer requests, receive updates, and stay connected.',
      ),
    ];

    if (index >= 0 && index < copies.length) {
      return copies[index];
    }
    return _OnboardingCopy(title: fallback.title, hint: fallback.hint);
  }
}

class _OnboardingGraphicPainter extends CustomPainter {
  const _OnboardingGraphicPainter({required this.index});

  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = [
      const Color(0xFFFFC857),
      const Color(0xFF2C9B88),
      const Color(0xFFD94D7B),
      const Color(0xFF0C2230),
    ][index % 4];
    final line = Paint()
      ..color = accent.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.86, size.height * 0.12),
        radius: size.width * 0.58,
      ));

    canvas.drawRect(Offset.zero & size, glow);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.08), 72, line);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.08), 112, line);

    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.82)
      ..cubicTo(size.width * 0.25, size.height * 0.68, size.width * 0.43,
          size.height * 0.96, size.width * 0.64, size.height * 0.76)
      ..cubicTo(size.width * 0.82, size.height * 0.58, size.width * 0.9,
          size.height * 0.86, size.width * 1.02, size.height * 0.7);
    canvas.drawPath(path, line);

    final dot = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(size.width * (0.12 + i * 0.06), size.height * 0.18),
        3,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OnboardingGraphicPainter oldDelegate) {
    return oldDelegate.index != index;
  }
}
