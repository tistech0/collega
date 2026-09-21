import 'dart:io';

import 'package:background_downloader/background_downloader.dart' show BaseDirectory;
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/upload/background_part_transport.dart';
import 'package:collega_app/core/upload/part_transport.dart';
import 'package:collega_app/env.dart';

void main() {
  test('buildTask : PUT binaire vers /parts/{n}, group college-import, metaData uploadId|n', () {
    final task = BackgroundPartTransport.buildTask(
      PartUpload(uploadId: 'u1', partIndex: 4, file: File('/tmp/parts_u1/part_4')),
    );
    expect(task.url, '$backendBaseUrl/v1/colleges/import/u1/parts/4');
    expect(task.httpRequestMethod, 'PUT');
    expect(task.post, 'binary');
    expect(task.group, 'college-import');
    expect(task.metaData, 'u1|4');
    expect(task.retries, 3);
    expect(task.headers['Content-Type'], 'application/octet-stream');
    expect(task.baseDirectory, BaseDirectory.root);
    expect(task.directory, 'tmp/parts_u1'); // le package retire le / initial (root = /)
    expect(task.filename, 'part_4');
  });

  test('parseMetaData : uploadId|n', () {
    expect(BackgroundPartTransport.parseMetaData('abc-def|12'), ('abc-def', 12));
  });
}
