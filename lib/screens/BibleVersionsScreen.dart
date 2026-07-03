import 'package:churchapp_flutter/utils/Alerts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/Bible.dart';
import '../database/SQLiteDbProvider.dart';
import '../providers/BibleModel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';
import '../models/Versions.dart';
import '../utils/img.dart';
import 'NoitemScreen.dart';
import '../i18n/strings.g.dart';
import '../utils/my_colors.dart';

class BibleVersionsScreen extends StatelessWidget {
  static const routeName = "/bibleversions";
  const BibleVersionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          t.downloadbible,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: BibleVersionsScreenPageBody(),
      ),
    );
  }
}

class BibleVersionsScreenPageBody extends StatefulWidget {
  const BibleVersionsScreenPageBody({Key? key}) : super(key: key);

  @override
  _BibleVersionsScreenBodyState createState() =>
      _BibleVersionsScreenBodyState();
}

class _BibleVersionsScreenBodyState extends State<BibleVersionsScreenPageBody> {
  bool isLoading = true;
  bool isError = false;
  List<Versions>? items = [];

  Future<void> loadItems() async {
    setState(() {
      isLoading = true;
    });
    try {
      final dio = Dio();
      final response = await dio.get(ApiUrl.GET_BIBLE);

      if (response.statusCode == 200) {
        dynamic res = decodeApiResponse(response.data);
        print(res);
        List<Versions>? _items = parseVersions(res);
        setState(() {
          isLoading = false;
          items = _items;
        });
      } else {
        print(response);
        setState(() {
          isLoading = false;
          isError = true;
        });
      }
    } catch (exception) {
      print(exception);
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  static List<Versions>? parseVersions(dynamic res) {
    final parsed = res["versions"].cast<Map<String, dynamic>>();
    return parsed.map<Versions>((json) => Versions.fromJson(json)).toList();
  }

  @override
  void initState() {
    Future.delayed(const Duration(milliseconds: 0), () {
      loadItems();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CupertinoActivityIndicator(
          radius: 20,
        ),
      );
    } else if (isError) {
      return NoitemScreen(
        title: t.oops,
        message: t.dataloaderror,
        onClick: () {
          loadItems();
        },
      );
    } else {
      return ListView.builder(
        itemCount: items!.length,
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.all(12),
        itemBuilder: (BuildContext context, int index) {
          return ItemTile(
            index: index,
            versions: items![index],
          );
        },
      );
    }
  }
}

class ItemTile extends StatefulWidget {
  final Versions versions;
  final int index;

  const ItemTile({
    Key? key,
    required this.index,
    required this.versions,
  }) : super(key: key);

  @override
  _ItemTileState createState() => _ItemTileState();
}

class _ItemTileState extends State<ItemTile> {
  int state =
      0; // pending download, 1 downloading, 2 downloaded, 3 error, 4 processing
  var downloadfilepath = "";
  String progress = '0';
  String msg = " 0 of 100";

  Future<void> downloadFile() async {
    if (!mounted) return;
    setState(() {
      state = 1;
    });
    Alerts.showToast(context, t.bibledownloadinfo);

    downloadfilepath = await getFilePath();
    Dio dio = Dio();
    try {
      print(
          'Downloading Bible ${widget.versions.name} from ${widget.versions.source}');
      await dio.download(
        widget.versions.source!,
        downloadfilepath,
        onReceiveProgress: (rcv, total) {
          if (!mounted) return;
          setState(() {
            progress = total > 0
                ? ((rcv / total) * 100).clamp(0, 100).toStringAsFixed(0)
                : '0';
            msg = ' $progress of 100';
          });
        },
        deleteOnError: true,
      );
      if (!mounted) return;
      setState(() {
        progress = '100';
        msg = ' 100 of 100';
        state = 4;
      });
      savetodatabase();
    } catch (e) {
      print('Bible download failed: $e');
      if (!mounted) return;
      Alerts.showToast(
        context,
        t.failedtodownload +
            widget.versions.name! +
            ", " +
            t.pleaseclicktoretry,
      );
      setState(() {
        state = 3;
      });
    }
  }

  Future<String> getFilePath() async {
    String path = '';
    var uniqueFileName = widget.versions.code;
    Directory dir = await getApplicationDocumentsDirectory();
    path = '${dir.path}/$uniqueFileName.json';
    return path;
  }

  savetodatabase() {
    String jobsString = "";
    final file = File(downloadfilepath);
    Stream<List<int>> inputStream = file.openRead();
    inputStream.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (String line) async {
      jobsString += line;
    }, onDone: () async {
      debugPrint('File is now closed.');
      List<dynamic> biblejson = await jsonDecode(jobsString);
      List<Bible> bibleList = parseBible(biblejson)!;
      print("downloaded bible size = " + bibleList.length.toString());
      await SQLiteDbProvider.db.insertBatchBible(bibleList);
      await SQLiteDbProvider.db.insertBibleVersion(widget.versions);
      Provider.of<BibleModel>(context, listen: false).getDownloadedBibleList();
      setState(() {
        state = 2;
      });
    }, onError: (e) {
      print(e.toString());
    });
  }

  List<Bible>? parseBible(dynamic res) {
    final parsed = res.cast<Map<String, dynamic>>();
    return parsed
        .map<Bible>((json) => Bible.fromJson(json, widget.versions.code))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 0), () {
      if (Provider.of<BibleModel>(context, listen: false)
          .isBibleVersionDownloaded(widget.versions)) {
        setState(() {
          state = 2;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Define high-end color themes
    final isDownloaded = state == 2;
    final isDownloading = state == 1 || state == 4;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDownloaded
              ? MyColors.primary.withValues(alpha: 0.3)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05)),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colorful Holy Bible icon with glowing shadow
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 52,
                      width: 52,
                      child: Image.asset(
                        Img.get('bible_data.PNG'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Version details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.versions.name!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (isDownloaded)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 12, color: Colors.green.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Active",
                                    style: TextStyle(
                                      color: Colors.green.shade600,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.versions.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Download progress bar
            if (isDownloading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: double.parse(progress) / 100.0,
                  backgroundColor:
                      isDark ? Colors.white12 : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(MyColors.primary),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    state == 4
                        ? "Installing version..."
                        : "Downloading data...",
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54),
                  ),
                  Text(
                    "$progress%",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: MyColors.primary),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (state == 0) // Download Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    onPressed: downloadFile,
                    icon: const Icon(Icons.cloud_download,
                        size: 16, color: Colors.white),
                    label: Text(
                      t.download,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                if (state == 1) // Downloading state disabled
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    onPressed: null,
                    icon: const CupertinoActivityIndicator(radius: 8),
                    label: const Text(
                      "Downloading...",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                if (state == 2) // Already Installed Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.green.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    onPressed: null, // already installed
                    icon:
                        const Icon(Icons.check, size: 16, color: Colors.green),
                    label: Text(
                      t.downloaded,
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                if (state == 3) // Retry Download Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    onPressed: downloadFile,
                    icon: const Icon(Icons.refresh,
                        size: 16, color: Colors.white),
                    label: Text(
                      t.retry,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                if (state == 4) // Installing processing state
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    onPressed: null,
                    icon: const CupertinoActivityIndicator(radius: 8),
                    label: const Text(
                      "Installing...",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
