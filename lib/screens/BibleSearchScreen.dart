import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/BibleModel.dart';
import '../utils/StringsUtils.dart';
import '../i18n/strings.g.dart';
import '../models/Bible.dart';
import '../widgets/BibleVersesTileSearch.dart';
import '../models/Versions.dart';
import '../utils/my_colors.dart';
import '../database/SQLiteDbProvider.dart';
import '../widgets/AiBibleSheet.dart';

enum BookFilter { all, oldTestament, newTestament }

class BibleSearchScreen extends StatefulWidget {
  static const routeName = "/biblesearchscreen";
  const BibleSearchScreen({Key? key}) : super(key: key);

  @override
  BibleSearchScreenRouteState createState() => BibleSearchScreenRouteState();
}

class BibleSearchScreenRouteState extends State<BibleSearchScreen> {
  final TextEditingController inputController = TextEditingController();
  Future<List<Bible>>? bibleSearch;
  String query = "";
  String? version = "";
  int limit = 40;

  BookFilter _filter = BookFilter.all;
  bool _isAlphabetical = false;
  bool _isSearchingKeywords = false;
  bool _isLoadingSearch = false;

  @override
  void initState() {
    version = Provider.of<BibleModel>(context, listen: false).selectedVersion;
    super.initState();
  }

  BoxDecoration glassDecoration(BuildContext context, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: color ??
          (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03)),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08),
        width: 1.0,
      ),
    );
  }

  void _onSearchSubmitted(String term) {
    if (term.trim().isEmpty) {
      setState(() {
        query = "";
        _isSearchingKeywords = false;
        bibleSearch = null;
      });
      return;
    }
    setState(() {
      query = term;
      _isSearchingKeywords = true;
      _isLoadingSearch = true;
    });

    final bibleModel = Provider.of<BibleModel>(context, listen: false);
    bibleSearch = bibleModel
        .searchBible(
            term,
            version,
            "", // all books
            _filter == BookFilter.oldTestament,
            _filter == BookFilter.newTestament,
            limit)
        .then((results) {
      setState(() {
        _isLoadingSearch = false;
      });
      return results;
    }).catchError((err) {
      setState(() {
        _isLoadingSearch = false;
      });
      throw err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bibleModel = Provider.of<BibleModel>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          "Bible Dashboard",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {
              final searchText = inputController.text.trim();
              if (searchText.isNotEmpty) {
                AiBibleSearchSheet.show(context, searchText);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Enter a topic or question to search with AI'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            tooltip: "Ask AI",
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showSearchFilterOptions(context, bibleModel),
            tooltip: "Adjust Limit",
          ),
        ],
      ),
      body: Column(
        children: [
          // Header / Search Bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              decoration: glassDecoration(context),
              child: TextField(
                controller: inputController,
                textInputAction: TextInputAction.search,
                onSubmitted: _onSearchSubmitted,
                onChanged: (val) {
                  setState(() {
                    query = val;
                    if (val.trim().isEmpty) {
                      _isSearchingKeywords = false;
                      bibleSearch = null;
                    }
                  });
                },
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "Search keywords or filter books...",
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45),
                  prefixIcon: Icon(Icons.search,
                      color: isDark ? Colors.white54 : Colors.black45),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            inputController.clear();
                            setState(() {
                              query = "";
                              _isSearchingKeywords = false;
                              bibleSearch = null;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // Filters Row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Version Chip
                  ActionChip(
                    backgroundColor: MyColors.primary.withValues(alpha: 0.1),
                    side: BorderSide(
                        color: MyColors.primary.withValues(alpha: 0.3)),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.library_books,
                            size: 14, color: MyColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          version ?? "Version",
                          style: TextStyle(
                              color: MyColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ],
                    ),
                    onPressed: () =>
                        _showBibleVersionsMenuSheet(context, bibleModel),
                  ),
                  const SizedBox(width: 8),

                  // Testament Chip: All
                  ChoiceChip(
                    label: const Text("All Books"),
                    selected: _filter == BookFilter.all,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _filter = BookFilter.all;
                          if (_isSearchingKeywords) _onSearchSubmitted(query);
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),

                  // Testament Chip: Old Testament
                  ChoiceChip(
                    label: const Text("Old Testament"),
                    selected: _filter == BookFilter.oldTestament,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _filter = BookFilter.oldTestament;
                          if (_isSearchingKeywords) _onSearchSubmitted(query);
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),

                  // Testament Chip: New Testament
                  ChoiceChip(
                    label: const Text("New Testament"),
                    selected: _filter == BookFilter.newTestament,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _filter = BookFilter.newTestament;
                          if (_isSearchingKeywords) _onSearchSubmitted(query);
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),

                  // Sort Order Toggle Chip
                  ActionChip(
                    avatar: Icon(
                      _isAlphabetical ? Icons.sort_by_alpha : Icons.list,
                      size: 14,
                    ),
                    label: Text(_isAlphabetical ? "A-Z Order" : "Canonical"),
                    onPressed: () {
                      setState(() {
                        _isAlphabetical = !_isAlphabetical;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Content Area
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isSearchingKeywords
                  ? buildKeywordSearchResults(context)
                  : buildBookGrid(context, bibleModel),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildKeywordSearchResults(BuildContext context) {
    if (_isLoadingSearch) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 16),
      );
    }

    return FutureBuilder<List<Bible>>(
      future: bibleSearch,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return buildEmptyState(context, Icons.error_outline, "Error Occurred",
              "An error occurred while searching. Please try again.");
        } else if (snapshot.hasData) {
          final results = snapshot.data!;
          if (results.isEmpty) {
            return buildEmptyState(context, Icons.search_off, t.nosearchresult,
                t.nosearchresulthint);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: results.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: glassDecoration(context),
                child: BibleVersesTileSearch(
                  object: results[index],
                  query: query,
                ),
              );
            },
          );
        } else {
          return const Center(child: CupertinoActivityIndicator());
        }
      },
    );
  }

  Widget buildEmptyState(
      BuildContext context, IconData icon, String title, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBookGrid(BuildContext context, BibleModel bibleModel) {
    final rawBooks = bibleModel.bibleBooks;
    List<String> filteredBooks = [];

    for (var b in rawBooks) {
      if (_filter == BookFilter.oldTestament &&
          !StringsUtils.oldtestaments.contains(b)) continue;
      if (_filter == BookFilter.newTestament &&
          !StringsUtils.newtestaments.contains(b)) continue;
      // Also filter book name by query typing if user is not doing full keyword search
      if (query.isNotEmpty && !b.toLowerCase().contains(query.toLowerCase()))
        continue;
      filteredBooks.add(b);
    }

    if (_isAlphabetical) {
      filteredBooks.sort((a, b) => a.compareTo(b));
    } else {
      filteredBooks
          .sort((a, b) => rawBooks.indexOf(a).compareTo(rawBooks.indexOf(b)));
    }

    if (filteredBooks.isEmpty) {
      return buildEmptyState(context, Icons.menu_book, "No Books Found",
          "Try clearing your text filters or selecting a different testament.");
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        final bookName = filteredBooks[index];
        final bookIndex = rawBooks.indexOf(bookName);
        final chapterCount = StringsUtils.bibleBooksTotalChapters[bookIndex];
        final isOldTestament = StringsUtils.oldtestaments.contains(bookName);

        return GestureDetector(
          onTap: () => _showNavigationSheet(context, bookName, bibleModel),
          child: Container(
            decoration: glassDecoration(context),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isOldTestament
                          ? [Colors.amber.shade700, Colors.orange.shade800]
                          : [Colors.indigo.shade600, Colors.purple.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_stories,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  bookName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$chapterCount chs",
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNavigationSheet(
      BuildContext context, String bookName, BibleModel bibleModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Declare local state outside the StatefulBuilder's builder function!
        int? selectedChapter;
        List<int> verses = [];
        bool loadingVerses = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bookIndex = bibleModel.bibleBooks.indexOf(bookName);
            final chapterCount =
                StringsUtils.bibleBooksTotalChapters[bookIndex];

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Pull handle
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            if (selectedChapter != null)
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () {
                                  setSheetState(() {
                                    selectedChapter = null;
                                    verses = [];
                                  });
                                },
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedChapter == null
                                        ? bookName
                                        : "$bookName Chapter $selectedChapter",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    selectedChapter == null
                                        ? "Select Chapter"
                                        : "Select Verse",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: selectedChapter == null
                            // Chapters Grid
                            ? GridView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.all(20),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                                itemCount: chapterCount,
                                itemBuilder: (context, index) {
                                  final chapterNum = index + 1;
                                  return InkWell(
                                    onTap: () async {
                                      setSheetState(() {
                                        loadingVerses = true;
                                        selectedChapter = chapterNum;
                                      });
                                      try {
                                        final bibleList = await SQLiteDbProvider
                                            .db
                                            .getAllBible(
                                                bibleModel.selectedVersion,
                                                bookName,
                                                chapterNum);
                                        setSheetState(() {
                                          verses = List.generate(
                                              bibleList.length,
                                              (idx) => idx + 1);
                                          loadingVerses = false;
                                        });
                                      } catch (e) {
                                        setSheetState(() {
                                          loadingVerses = false;
                                        });
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      decoration: glassDecoration(context),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "$chapterNum",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            // Verses Grid
                            : loadingVerses
                                ? const Center(
                                    child: CupertinoActivityIndicator())
                                : verses.isEmpty
                                    ? Center(
                                        child: Text(
                                          "No verses found for this chapter",
                                          style: TextStyle(
                                              color: Colors.grey.shade500),
                                        ),
                                      )
                                    : GridView.builder(
                                        controller: scrollController,
                                        padding: const EdgeInsets.all(20),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 5,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                        ),
                                        itemCount: verses.length,
                                        itemBuilder: (context, index) {
                                          final verseNum = index + 1;
                                          return InkWell(
                                            onTap: () {
                                              bibleModel
                                                  .setCurrentSelectedBibleBookChapterAndVerse(
                                                      bookName,
                                                      selectedChapter!,
                                                      verseNum);

                                              // Pop the bottom sheet and then search screen
                                              Navigator.pop(context);
                                              Navigator.pop(context);
                                            },
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Container(
                                              decoration: glassDecoration(
                                                  context,
                                                  color: MyColors.primary
                                                      .withValues(alpha: 0.08)),
                                              alignment: Alignment.center,
                                              child: Text(
                                                "$verseNum",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: MyColors.primary,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showSearchFilterOptions(BuildContext context, BibleModel bibleModel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPanelState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Search Limit",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Maximum search results to display: $limit",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: limit.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 9,
                    label: "$limit",
                    onChanged: (val) {
                      setPanelState(() {
                        limit = val.floor();
                      });
                      setState(() {
                        limit = val.floor();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MyColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        if (query.isNotEmpty) {
                          _onSearchSubmitted(query);
                        }
                      },
                      child: const Text("Apply",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBibleVersionsMenuSheet(
      BuildContext context, BibleModel bibleModel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (BuildContext bc) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Text(
                  "Select Bible Version",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(height: 1),
                  itemCount: bibleModel.downloadedBibleList.length,
                  itemBuilder: (BuildContext ctxt, int index) {
                    Versions versions = bibleModel.downloadedBibleList[index];
                    final isSelected = version == versions.code;
                    return ListTile(
                      title: Text(
                        versions.name!,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? MyColors.primary : null,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          version = versions.code;
                          if (_isSearchingKeywords) _onSearchSubmitted(query);
                        });
                        Navigator.of(context).pop();
                      },
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: MyColors.primary)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
