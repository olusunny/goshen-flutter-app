import 'package:flutter/material.dart';
import '../providers/BibleModel.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../screens/BibleViewScreen.dart';
import '../utils/my_colors.dart';
import '../i18n/strings.g.dart';
import '../screens/BibleSearchScreen.dart';
import '../screens/BibleVersionsScreen.dart';

class BibleScreen extends StatefulWidget {
  static const routeName = "/biblescreen";

  @override
  _BibleScreenState createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  @override
  Widget build(BuildContext context) {
    BibleModel bibleModel = Provider.of<BibleModel>(context);
    int bibleversionsize = bibleModel.downloadedBibleList.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.biblebooks),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              tooltip: t.downloadmoreversions,
              onPressed: () {
                Navigator.of(context).pushNamed(BibleVersionsScreen.routeName);
              },
              icon: Icon(Icons.download_for_offline_outlined),
              iconSize: 25,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              onPressed: () {
                Navigator.of(context).pushNamed(BibleSearchScreen.routeName);
              },
              icon: Icon(Icons.search),
              iconSize: 25,
            ),
          )
        ],
      ),
      body: bibleversionsize == 0 ? EmptyLayout() : BibleViewScreen(),
    );
  }
}

class EmptyLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA);
    final card = isDark ? const Color(0xFF102532) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF102532);
    final muted = isDark ? Colors.white70 : const Color(0xFF60707A);

    return ColoredBox(
      color: background,
      child: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 38),
            child: Material(
              color: card,
              borderRadius: BorderRadius.circular(30),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  Navigator.of(context)
                      .pushNamed(BibleVersionsScreen.routeName);
                },
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8EC),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.22 : 0.07),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Lottie.asset(
                        "assets/lottie/bible.json",
                        height: 190,
                        width: 190,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Start reading offline',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: text,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Download at least one Bible version to read, search, highlight, and study scripture anytime.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted,
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download_for_offline_rounded),
                          label: const Text(
                            'Download Bible',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MyColors.primary,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.of(context)
                                .pushNamed(BibleVersionsScreen.routeName);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
