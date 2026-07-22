import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/Userdata.dart';
import '../../utils/ApiUrl.dart';

class PrayerSessionQrFileService {
  Future<File> _download(Userdata user, String sessionId) async {
    final response = await Dio().get<List<int>>(
      ApiUrl.prayerSessionAttendanceSessionQr(sessionId),
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Accept': 'image/svg+xml',
          'X-Requested-With': 'XMLHttpRequest',
          if ((user.apiToken ?? '').trim().isNotEmpty)
            'Authorization': 'Bearer ${user.apiToken}',
        },
      ),
    );
    if (response.statusCode != 200 || response.data == null) {
      throw Exception('The prayer session QR could not be downloaded.');
    }
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/goshen-prayer-$sessionId.svg');
    await file.writeAsBytes(response.data!, flush: true);
    return file;
  }

  Future<void> share(Userdata user, String sessionId) async {
    final file = await _download(user, sessionId);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/svg+xml')],
      text: 'Goshen prayer session QR',
    );
  }

  Future<File> save(Userdata user, String sessionId) async {
    final downloaded = await _download(user, sessionId);
    final externalDirectory = await getExternalStorageDirectory();
    final directory =
        externalDirectory ?? await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/goshen-prayer-$sessionId.svg');
    return downloaded.copy(file.path);
  }
}
