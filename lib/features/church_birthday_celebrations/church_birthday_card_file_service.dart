import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ChurchBirthdayCardFileService {
  Future<File> save(String celebrationId, Uint8List bytes) async {
    final external = await getExternalStorageDirectory();
    final directory = external ?? await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/birthday-card-$celebrationId.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> share(String celebrationId, Uint8List bytes, String name) async {
    final file = await save(celebrationId, bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: 'Celebrating $name with our church family.',
      subject: 'Happy birthday, $name',
    );
  }
}
