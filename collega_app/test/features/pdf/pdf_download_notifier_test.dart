import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/pdf/data/local_pdf_store.dart';
import 'package:collega_app/features/pdf/data/pdf_downloader.dart';
import 'package:collega_app/features/pdf/pdf_providers.dart';

class _FakeDownloader implements PdfDownloader {
  _FakeDownloader({this.fail = false, this.content = '%PDF-1.7'});
  final bool fail;
  final String content;
  @override
  Future<File> download({
    required String collegeId,
    required String version,
    required Directory into,
    required void Function(double) onProgress,
  }) async {
    onProgress(0.5);
    if (fail) throw const PdfDownloadFailed('réseau');
    await into.create(recursive: true);
    onProgress(1);
    return File('${into.path}/${collegeId}_$version.pdf.part')..writeAsStringSync(content);
  }
}

void main() {
  late Directory tmp;
  late LocalPdfStore store;

  ProviderContainer make(PdfDownloader downloader) {
    final c = ProviderContainer(overrides: [
      localPdfStoreProvider.overrideWith((ref) async => store),
      pdfDownloaderProvider.overrideWithValue(downloader),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdfdl');
    store = LocalPdfStore(Directory('${tmp.path}/pdfs'));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('téléchargement réussi : progression puis copie à jour', () async {
    final c = make(_FakeDownloader());
    final seen = <PdfDownloadState>[];
    c.listen(pdfDownloadProvider('c26'), (_, s) => seen.add(s), fireImmediately: true);

    await c.read(pdfDownloadProvider('c26').notifier).start('j1');

    expect(seen.whereType<PdfDownloading>().map((s) => s.progress), contains(0.5));
    expect(c.read(pdfDownloadProvider('c26')), isA<PdfDownloadDone>());
    expect(await store.status('c26', 'j1'), LocalPdfStatus.upToDate);
  });

  test('échec : état failed, aucune copie prise pour valide', () async {
    final c = make(_FakeDownloader(fail: true));
    await c.read(pdfDownloadProvider('c26').notifier).start('j1');
    expect(c.read(pdfDownloadProvider('c26')), isA<PdfDownloadFailedState>());
    expect(await store.status('c26', 'j1'), LocalPdfStatus.absent);
  });

  test('revue finale 1 : le statut local est relu après le téléchargement (écran quitté)', () async {
    final c = make(_FakeDownloader());
    const key = (collegeId: 'c26', version: 'j1');
    c.listen(collegePdfStatusProvider(key), (_, __) {});
    expect(await c.read(collegePdfStatusProvider(key).future), LocalPdfStatus.absent);
    await c.read(pdfDownloadProvider('c26').notifier).start('j1');
    expect(await c.read(collegePdfStatusProvider(key).future), LocalPdfStatus.upToDate);
  });

  test('revue finale 2 : une réponse qui n’est pas un PDF n’est jamais gardée', () async {
    final c = make(_FakeDownloader(content: '<html>Cloudflare Access</html>'));
    await c.read(pdfDownloadProvider('c26').notifier).start('j1');
    expect(c.read(pdfDownloadProvider('c26')), isA<PdfDownloadFailedState>());
    expect(await store.status('c26', 'j1'), LocalPdfStatus.absent);
    expect(store.root.listSync().whereType<File>(), isEmpty);
  });

  test('revue finale 2 : taille différente de celle annoncée → échec, rien de gardé', () async {
    final c = make(_FakeDownloader());
    await c.read(pdfDownloadProvider('c26').notifier).start('j1', expectedSize: 999999);
    expect(c.read(pdfDownloadProvider('c26')), isA<PdfDownloadFailedState>());
    expect(await store.status('c26', 'j1'), LocalPdfStatus.absent);
  });

  test('revue finale 2 : taille annoncée exacte → gardé', () async {
    final c = make(_FakeDownloader());
    await c.read(pdfDownloadProvider('c26').notifier).start('j1', expectedSize: '%PDF-1.7'.length);
    expect(await store.status('c26', 'j1'), LocalPdfStatus.upToDate);
  });

  test('deux appuis : un seul téléchargement', () async {
    var calls = 0;
    final c = make(_CountingDownloader(() => calls++));
    final n = c.read(pdfDownloadProvider('c26').notifier);
    await Future.wait([n.start('j1'), n.start('j1')]);
    expect(calls, 1);
  });
}

class _CountingDownloader extends _FakeDownloader {
  _CountingDownloader(this.onCall);
  final void Function() onCall;
  @override
  Future<File> download({
    required String collegeId,
    required String version,
    required Directory into,
    required void Function(double) onProgress,
  }) {
    onCall();
    return super.download(collegeId: collegeId, version: version, into: into, onProgress: onProgress);
  }
}
