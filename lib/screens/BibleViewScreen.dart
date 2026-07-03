import '../models/Versions.dart';
import 'package:flutter/material.dart';
import '../i18n/strings.g.dart';
import '../widgets/BibleTTSPlayer.dart';
import 'package:select_dialog/select_dialog.dart';
import '../screens/BibleVersionsScreen.dart';
import '../utils/my_colors.dart';
import '../utils/TextStyles.dart';
import '../models/Bible.dart';
import '../providers/BibleModel.dart';
import 'package:provider/provider.dart';
import '../screens/ColoredHighightedVerses.dart';
import '../widgets/BibleVersesTile.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';

class BibleViewScreen extends StatefulWidget {
  BibleViewScreen();

  @override
  BibleViewScreenRouteState createState() => new BibleViewScreenRouteState();
}

class BibleViewScreenRouteState extends State<BibleViewScreen> {
  Future<List<Bible>>? bibleLoader;
  PageController? controller;
  int itemCount = 0;
  List<Bible>? currentBibleList = [];
  BibleModel? bibleModel;
  String? currentBook;
  int? currentChapter;
  int? currentVerse;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final model = Provider.of<BibleModel>(context);
    if (currentBook != model.selectedBook ||
        currentChapter != model.selectedChapter ||
        currentVerse != model.selectedVerse) {
      final bookChanged = currentBook != model.selectedBook;
      final chapterChanged = currentChapter != model.selectedChapter;

      currentBook = model.selectedBook;
      currentChapter = model.selectedChapter;
      currentVerse = model.selectedVerse;
      itemCount = model.selectedBookLength;

      if (bookChanged || chapterChanged || bibleLoader == null) {
        bibleLoader = model.showCurrentBibleData(model.selectedChapter);
      }

      final int targetPage = model.selectedChapter - 1;

      if (controller != null && controller!.hasClients) {
        // Defer the jump to after the widget tree has rebuilt so the
        // PageView's updated itemCount is in effect.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller != null && controller!.hasClients) {
            if (controller!.page?.round() != targetPage) {
              controller!.jumpToPage(targetPage);
            }
          }
        });
      } else {
        if (controller != null) {
          controller!.dispose();
        }
        controller = PageController(
          initialPage: targetPage,
        );
      }
    }
  }

  void _openDialog(BuildContext _context, String title, Widget content) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(6.0),
          title: Text(title),
          content: Container(height: 230, child: content),
          actions: [
            ElevatedButton(
              child: Text(t.cancel),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            ElevatedButton(
              child: Text(t.set),
              onPressed: () {
                bibleModel!.colorizeSelectedVerses();
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    //Provider.of<BibleModel>(context, listen: false)
    //  .unselectedHighlightedVerses();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bibleModel = Provider.of<BibleModel>(context);
    return Column(
      children: <Widget>[
        Container(
          height: 50,
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                RichText(
                  text: TextSpan(
                      style: TextStyles.subhead(context)
                          .copyWith(fontWeight: FontWeight.w500),
                      children: <TextSpan>[
                        TextSpan(
                          text: bibleModel!.selectedBook +
                              t.chapter +
                              Provider.of<BibleModel>(context, listen: false)
                                  .selectedChapter
                                  .toString(),
                          style: TextStyle(fontSize: 18),
                        ),
                        TextSpan(
                          text: " (" + bibleModel!.selectedVersion! + ")",
                          style: TextStyle(fontSize: 13),
                        )
                      ]),
                ),
                Container(
                  width: 130,
                  height: 2,
                  color: MyColors.primary,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: PageView.builder(
            onPageChanged: (page) {
              print("page changed to = " + page.toString());
              final model = Provider.of<BibleModel>(context, listen: false);
              if (model.selectedChapter != page + 1) {
                final chapter = page + 1;
                setState(() {
                  bibleLoader = model.showCurrentBibleData(chapter);
                });
                model.setCurrentSelectedBibleChapter(chapter);
              }
            },
            itemCount: bibleModel!.selectedBookLength,
            scrollDirection: Axis.horizontal,
            reverse: false,
            controller: controller,
            pageSnapping: true,
            itemBuilder: (BuildContext context, int index) {
              return _BiblePageContent(
                bibleLoader: bibleLoader,
                bibleModel: bibleModel!,
              );
            },
          ),
        ),
        Consumer<BibleModel>(
          builder: (context, bibleModel, child) {
            if (!bibleModel.isStartHighlight) {
              return Container();
            }
            return Container(
              width: double.infinity,
              height: 55,
              child: Row(
                children: <Widget>[
                  Spacer(),
                  Container(width: 15),
                  InkWell(
                      child: Icon(Icons.color_lens,
                          color: Colors.yellow[900], size: 25.0),
                      onTap: () {
                        _openDialog(
                          context,
                          t.selectColor,
                          MaterialColorPicker(
                            selectedColor: Color(bibleModel.selectedColor),
                            allowShades: false,
                            onMainColorChange: (color) {
                              bibleModel.selectedColor = color!.value;
                              print(Color(color.toARGB32()));
                            },
                          ),
                        );
                      }),
                  Container(width: 30),
                  InkWell(
                    child: Icon(Icons.content_copy,
                        color: Colors.purple, size: 23.0),
                    onTap: () {
                      bibleModel.copyHighlightedVerses(context);
                    },
                  ),
                  Container(width: 25),
                  InkWell(
                    child:
                        Icon(Icons.share, color: Colors.lightBlue, size: 25.0),
                    onTap: () {
                      bibleModel.shareHightlightedVerses();
                    },
                  ),
                  Container(width: 25),
                  InkWell(
                    child: Icon(Icons.cancel, color: Colors.red, size: 25.0),
                    onTap: () {
                      bibleModel.stopHighlight();
                    },
                  ),
                  Container(width: 10),
                ],
              ),
            );
          },
        ),
        BibleTTSPlayer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 5),
          height: 50,
          width: double.infinity,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Container(
                      height: double.infinity,
                      child: Material(
                        child: InkWell(
                          onTap: () {
                            if (Provider.of<BibleModel>(context, listen: false)
                                    .selectedChapter >
                                1) {
                              int currentitm = Provider.of<BibleModel>(context,
                                          listen: false)
                                      .selectedChapter -
                                  2;
                              controller!.jumpToPage(currentitm);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.chevron_left,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                        child: Align(
                      alignment: Alignment.center,
                      child: buildProgress(context, bibleModel!),
                    )),
                    Container(
                      height: double.infinity,
                      child: Material(
                        child: InkWell(
                          onTap: () {
                            if (Provider.of<BibleModel>(context, listen: false)
                                    .selectedChapter <
                                itemCount) {
                              controller!.jumpToPage(Provider.of<BibleModel>(
                                      context,
                                      listen: false)
                                  .selectedChapter);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.chevron_right,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 12,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  onPressed: () {
                    showBibleOptionsMenuSheet(context, bibleModel);
                  },
                  icon: Icon(Icons.menu),
                  iconSize: 30,
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget buildProgress(BuildContext context, BibleModel bibleModel) {
    double progress =
        bibleModel.selectedChapter * (1 / bibleModel.selectedBookLength);
    Widget widget = Container(
      height: 4,
      width: 130,
      child: LinearProgressIndicator(
        value: progress,
        valueColor: AlwaysStoppedAnimation<Color>(MyColors.primary),
        backgroundColor: Colors.grey[300],
      ),
    );
    return widget;
  }

  void showBibleOptionsMenuSheet(context, BibleModel? bibleModel) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.visibility),
                  title: Text(
                    t.switchbibleversion,
                    style: TextStyles.subhead(context)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    bibleModel!.selectedVersion!,
                    style: TextStyles.subhead(context).copyWith(fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    showBibleVersionsMenuSheet(context, bibleModel);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.swap_horiz),
                  title: Text(
                    t.switchbiblebook,
                    style: TextStyles.subhead(context)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    bibleModel.selectedBook,
                    style: TextStyles.subhead(context).copyWith(fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    SelectDialog.showModal<String>(
                      context,
                      searchBoxDecoration: InputDecoration(labelText: t.search),
                      label: t.switchbiblebook,
                      itemBuilder: (context, item, isSelected) {
                        return Container(
                          height: 50,
                          child: ListTile(
                            isThreeLine: false,
                            selected: isSelected,
                            trailing: isSelected
                                ? Icon(Icons.check)
                                : Container(
                                    height: 0,
                                    width: 0,
                                  ),
                            title: Text(
                              item,
                              style: TextStyles.subhead(context)
                                  .copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                        );
                      },
                      selectedValue: bibleModel.selectedBook,
                      items: bibleModel.bibleBooks,
                      onChange: (String selected) {
                        controller!.jumpToPage(0);
                        bibleModel.setCurrentSelectedBibleBook(selected);
                        setState(() {
                          bibleLoader = bibleModel.showCurrentBibleData(1);
                        });
                      },
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.format_list_numbered),
                  title: Text(
                    t.gotosearch,
                    style: TextStyles.subhead(context)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    t.chapter + " " + bibleModel.selectedChapter.toString(),
                    style: TextStyles.subhead(context).copyWith(fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    SelectDialog.showModal<int>(
                      context,
                      searchBoxDecoration: InputDecoration(labelText: t.search),
                      label: t.gotosearch,
                      itemBuilder: (context, item, isSelected) {
                        return Container(
                          height: 50,
                          child: ListTile(
                            isThreeLine: false,
                            selected: isSelected,
                            trailing: isSelected
                                ? Icon(Icons.check)
                                : Container(
                                    height: 0,
                                    width: 0,
                                  ),
                            title: Text(
                              t.chapter + " " + item.toString(),
                              style: TextStyles.subhead(context)
                                  .copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                        );
                      },
                      selectedValue: bibleModel.selectedChapter,
                      items: List.generate(
                          bibleModel.selectedBookLength, (index) => index + 1),
                      onChange: (int selected) {
                        controller!.jumpToPage(selected - 1);
                        setState(() {
                          bibleLoader =
                              bibleModel.showCurrentBibleData(selected);
                        });
                        bibleModel.setCurrentSelectedBibleChapter(selected);
                      },
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.pin_outlined),
                  title: Text(
                    'Select verse',
                    style: TextStyles.subhead(context)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    t.chapter + ' ' + bibleModel.selectedChapter.toString(),
                    style: TextStyles.subhead(context).copyWith(fontSize: 14),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final verses =
                        await Provider.of<BibleModel>(context, listen: false)
                            .showCurrentBibleData(bibleModel.selectedChapter);
                    if (!mounted || verses.isEmpty) return;
                    SelectDialog.showModal<int>(
                      context,
                      searchBoxDecoration: InputDecoration(labelText: t.search),
                      label: 'Select verse',
                      itemBuilder: (context, item, isSelected) {
                        return Container(
                          height: 50,
                          child: ListTile(
                            isThreeLine: false,
                            selected: isSelected,
                            trailing: isSelected
                                ? Icon(Icons.check)
                                : Container(height: 0, width: 0),
                            title: Text(
                              'Verse ' + item.toString(),
                              style: TextStyles.subhead(context)
                                  .copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                        );
                      },
                      items: verses.map((verse) => verse.verse ?? 0).toList(),
                      onChange: (int selected) {
                        final chapter = bibleModel.selectedChapter;
                        if (controller != null && controller!.hasClients) {
                          controller!.jumpToPage(chapter - 1);
                        }
                        setState(() {
                          bibleLoader =
                              bibleModel.showCurrentBibleData(chapter);
                        });
                        bibleModel.setCurrentSelectedBibleBookChapterAndVerse(
                          bibleModel.selectedBook,
                          chapter,
                          selected,
                        );
                      },
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.format_size),
                  title: Text(
                    t.changefontsize,
                    style: TextStyles.subhead(context)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    t.font + " - " + bibleModel.selectedFontSize.toString(),
                    style: TextStyles.subhead(context).copyWith(fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();

                    SelectDialog.showModal<int>(
                      context,
                      //searchBoxDecoration: InputDecoration(labelText: "search"),
                      label: t.changefontsize,
                      showSearchBox: false,
                      itemBuilder: (context, item, isSelected) {
                        return Container(
                          height: 50,
                          child: ListTile(
                            isThreeLine: false,
                            selected: isSelected,
                            trailing: isSelected
                                ? Icon(Icons.check)
                                : Container(
                                    height: 0,
                                    width: 0,
                                  ),
                            title: Text(
                              t.font + " - " + item.toString(),
                              style: TextStyles.subhead(context)
                                  .copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                        );
                      },
                      selectedValue: bibleModel.selectedFontSize,
                      items: bibleModel.bibleFontSizes,
                      onChange: (int selected) {
                        bibleModel.setCurrentSelectedFontSize(selected);
                      },
                    );
                  },
                ),
                /* ListTile(
                  leading: Icon(Icons.keyboard_voice),
                  title: Text(
                    t.readchapter,
                    style: TextStyles.subhead(context)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    bibleModel.readBibleChapter(currentBibleList);
                  },
                ),*/
                ListTile(
                  leading: Icon(Icons.highlight),
                  title: Text(
                    t.showhighlightedverse,
                    style: TextStyles.subhead(context)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context)
                        .pushNamed(ColoredHighightedVerses.routeName);
                  },
                ),
              ],
            ),
          );
        });
  }

  void showBibleVersionsMenuSheet(context, BibleModel? bibleModel) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            child: ListView.separated(
              separatorBuilder: (BuildContext context, int index) => Divider(),
              itemCount: bibleModel!.downloadedBibleList.length + 1,
              itemBuilder: (BuildContext ctxt, int index) {
                if (index == bibleModel.downloadedBibleList.length) {
                  return Container(
                    width: 180,
                    height: 40,
                    child: ElevatedButton(
                      child: Text(t.downloadmoreversions,
                          style: TextStyle(color: Colors.white)),
                      style: TextButton.styleFrom(
                        backgroundColor: MyColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context)
                            .pushNamed(BibleVersionsScreen.routeName);
                      },
                    ),
                  );
                }
                Versions versions = bibleModel.downloadedBibleList[index];
                return ListTile(
                  title: Text(versions.name!),
                  onTap: () {
                    Navigator.of(context).pop();
                    bibleModel.setCurrentSelectedBibleVersion(versions.code!);
                    bibleLoader =
                        Provider.of<BibleModel>(context, listen: false)
                            .showCurrentBibleData(
                                Provider.of<BibleModel>(context, listen: false)
                                    .selectedChapter);
                  },
                  trailing: bibleModel.selectedVersion == versions.code
                      ? Icon(
                          Icons.check,
                          color: MyColors.primary,
                        )
                      : Container(
                          height: 0,
                          width: 0,
                        ),
                );
              },
            ),
          );
        });
  }
}

class _BiblePageContent extends StatefulWidget {
  final Future<List<Bible>>? bibleLoader;
  final BibleModel bibleModel;

  const _BiblePageContent({
    Key? key,
    required this.bibleLoader,
    required this.bibleModel,
  }) : super(key: key);

  @override
  __BiblePageContentState createState() => __BiblePageContentState();
}

class __BiblePageContentState extends State<_BiblePageContent> {
  late ScrollController _scrollController;
  final Map<int, GlobalKey> _verseKeys = {};
  int? _lastScrolledBookHash;
  int? _lastScrolledChapter;
  int? _lastScrolledVerse;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _BiblePageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bibleLoader != widget.bibleLoader) {
      _lastScrolledBookHash = null;
      _lastScrolledChapter = null;
      _lastScrolledVerse = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Bible>>(
      future: widget.bibleLoader,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        } else {
          final currentBibleList = snapshot.data ?? [];

          final selectedBookHash = widget.bibleModel.selectedBook.hashCode;
          final selectedChapter = widget.bibleModel.selectedChapter;
          final selectedVerse = widget.bibleModel.selectedVerse;
          final shouldScrollToVerse = selectedVerse > 1 &&
              (_lastScrolledBookHash != selectedBookHash ||
                  _lastScrolledChapter != selectedChapter ||
                  _lastScrolledVerse != selectedVerse);

          if (shouldScrollToVerse) {
            _lastScrolledBookHash = selectedBookHash;
            _lastScrolledChapter = selectedChapter;
            _lastScrolledVerse = selectedVerse;
            final int targetVerse = widget.bibleModel.selectedVerse;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final keyContext = _verseKeys[targetVerse]?.currentContext;
              if (keyContext != null) {
                Scrollable.ensureVisible(
                  keyContext,
                  alignment: 0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }

          return SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                for (int index = 0; index < currentBibleList.length; index++)
                  Column(
                    children: [
                      KeyedSubtree(
                        key: _verseKeys.putIfAbsent(
                          currentBibleList[index].verse ?? index,
                          () => GlobalKey(),
                        ),
                        child: BibleVersesTile(
                          object: currentBibleList[index],
                          showCompare:
                              widget.bibleModel.downloadedBibleList.length > 1,
                        ),
                      ),
                      if (index < currentBibleList.length - 1) Divider(),
                    ],
                  ),
              ],
            ),
          );
        }
      },
    );
  }
}
