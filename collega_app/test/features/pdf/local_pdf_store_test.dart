import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/pdf/data/backup_excluder.dart';
import 'package:collega_app/features/pdf/data/local_pdf_store.dart';

class _RecordingExcluder implements BackupExcluder {
  final paths = <String>[];
  @override
  Future<void> exclude(String path) async => paths.add(path);
}

void main() {
  late Directory tmp;
  late _RecordingExcluder excluder;
  late LocalPdfStore store;

  Future<File> source(String name, [String content = '%PDF-1.7']) async =>
      File('${tmp.path}/$name')..writeAsStringSync(content);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdfstore');
    excluder = _RecordingExcluder();
    store = LocalPdfStore(Directory('${tmp.path}/pdfs'), excluder: excluder);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('rien sur le téléphone : absent', () async {
    expect(await store.status('c1', 'j1'), LocalPdfStatus.absent);
    expect(await store.readable('c1', 'j1'), isNull);
  });

  test('copie gardée à l’import : à jour, exclue de la sauvegarde, source intacte', () async {
    final src = await source('picked.pdf');
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: src);
    expect(await store.status('c1', 'j1'), LocalPdfStatus.upToDate);
    expect((await store.readable('c1', 'j1'))!.path, store.fileFor('c1', 'j1').path);
    expect(excluder.paths, [store.fileFor('c1', 'j1').path]);
    expect(src.existsSync(), isTrue);
  });

  test('le serveur a une autre version : périmé, l’ancienne copie reste lisible', () async {
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: await source('a.pdf'));
    expect(await store.status('c1', 'j2'), LocalPdfStatus.outdated);
  });

  test('réimport non publié : la nouvelle copie est gardée, l’ancienne reste en service', () async {
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: await source('a.pdf'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await store.keepCopy(collegeId: 'c1', version: 'j2', source: await source('b.pdf'));
    // Le serveur publie encore j1.
    expect(await store.status('c1', 'j1'), LocalPdfStatus.upToDate);
    expect(store.fileFor('c1', 'j2').existsSync(), isTrue);
    // Publication de j2 : j1 (plus ancienne) part.
    expect(await store.status('c1', 'j2'), LocalPdfStatus.upToDate);
    expect(store.fileFor('c1', 'j1').existsSync(), isFalse);
  });

  test('pas de version serveur (hors ligne) : la copie la plus récente est lue', () async {
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: await source('a.pdf'));
    expect(await store.status('c1', null), LocalPdfStatus.upToDate);
  });

  test('adopt : le téléchargement complet devient la copie', () async {
    final part = await source('c1_j3.pdf.part');
    await store.adopt(collegeId: 'c1', version: 'j3', downloaded: part);
    expect(await store.status('c1', 'j3'), LocalPdfStatus.upToDate);
    expect(part.existsSync(), isFalse);
  });

  test('deleteExcept et clear, dernière page lue', () async {
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: await source('a.pdf'));
    await store.keepCopy(collegeId: 'c2', version: 'j9', source: await source('b.pdf'));
    await store.saveLastPage('c2', 42);
    expect(await store.lastPage('c2'), 42);
    await store.deleteExcept({'c1'});
    expect(await store.status('c2', 'j9'), LocalPdfStatus.absent);
    expect(await store.lastPage('c2'), isNull);
    await store.clear();
    expect(await store.status('c1', 'j1'), LocalPdfStatus.absent);
  });

  test(
      'réimport d’un PDF à date de modification ancienne : la nouvelle copie n’est pas prise pour une version dépassée',
      () async {
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: await source('a.pdf'));
    final old = await source('b.pdf');
    old.setLastModifiedSync(DateTime(2020));
    await store.keepCopy(collegeId: 'c1', version: 'j2', source: old);
    // Le serveur publie encore j1 : j2 (réimport en cours) doit survivre.
    expect(await store.status('c1', 'j1'), LocalPdfStatus.upToDate);
    expect(store.fileFor('c1', 'j2').existsSync(), isTrue);
  });

  test('revue finale 3 : purgeLeftovers supprime les .part et .tmp, garde copies et pages', () async {
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: await source('a.pdf'));
    await store.saveLastPage('c1', 3);
    File('${store.root.path}/c1_j2.pdf.part').writeAsStringSync('x');
    File('${store.root.path}/c1_j3.pdf.tmp').writeAsStringSync('x');
    await store.purgeLeftovers();
    final names = store.root.listSync().map((e) => e.path.split('/').last).toSet();
    expect(names, {'c1_j1.pdf', 'c1.page'});
  });

  test('revue finale 4 : réimport jamais publié (échoué) → sa copie part, la version servie reste', () async {
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: await source('a.pdf'));
    await store.keepCopy(collegeId: 'c1', version: 'j2', source: await source('b.pdf'));
    await store.keepOnlyServed({'c1': 'j1'});
    expect(store.fileFor('c1', 'j1').existsSync(), isTrue);
    expect(store.fileFor('c1', 'j2').existsSync(), isFalse);
  });

  test('revue finale 4 : premier import échoué (aucune version servie) → plus rien', () async {
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: await source('a.pdf'));
    await store.keepOnlyServed({'c1': null});
    expect(await store.status('c1', null), LocalPdfStatus.absent);
  });

  test('revue finale 4 : collège absent de la carte → copies intactes (import en cours)', () async {
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: await source('a.pdf'));
    await store.keepCopy(collegeId: 'c1', version: 'j2', source: await source('b.pdf'));
    await store.keepOnlyServed({});
    expect(store.fileFor('c1', 'j2').existsSync(), isTrue);
  });
}
