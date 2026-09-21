import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/upload/part_splitter.dart';

void main() {
  test('split découpe en N morceaux, le dernier plus court', () async {
    final dir = await Directory.systemTemp.createTemp('split');
    addTearDown(() => dir.delete(recursive: true));
    final src = File('${dir.path}/src.bin')..writeAsBytesSync(List.generate(25, (i) => i));

    final parts = await PartSplitter.split(src, 10, Directory('${dir.path}/parts'));

    expect(parts.map((f) => f.lengthSync()), [10, 10, 5]);
    expect(parts[2].readAsBytesSync(), [20, 21, 22, 23, 24]);
  });

  test('split avec only= ne produit que les morceaux demandés', () async {
    final dir = await Directory.systemTemp.createTemp('split');
    addTearDown(() => dir.delete(recursive: true));
    final src = File('${dir.path}/src.bin')..writeAsBytesSync(List.filled(25, 1));

    final parts = await PartSplitter.split(src, 10, Directory('${dir.path}/parts'), only: {2});

    expect(parts.map((f) => f.path.split('/').last), ['part_2']);
  });
}
