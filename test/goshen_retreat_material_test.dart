import 'package:churchapp_flutter/models/GoshenRetreat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a published PDF retreat material', () {
    final material = GoshenRetreatMaterial.fromJson({
      'id': 12,
      'label': 'Retreat handbook',
      'file_name': 'handbook.pdf',
      'mime_type': 'application/pdf',
      'file_size': 1536,
      'is_published': true,
    });

    expect(material.id, 12);
    expect(material.isPdf, isTrue);
    expect(material.fileTypeLabel, 'PDF');
    expect(material.sizeLabel, '1.5 KB');
    expect(material.isPublished, isTrue);
  });
}
