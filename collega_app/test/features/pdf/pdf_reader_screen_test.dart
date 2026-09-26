import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/pdf/data/local_pdf_store.dart';
import 'package:collega_app/features/pdf/data/pdf_downloader.dart';
import 'package:collega_app/features/pdf/pdf_providers.dart';
import 'package:collega_app/features/pdf/presentation/pdf_document_view.dart';
import 'package:collega_app/features/pdf/presentation/pdf_reader_screen.dart';

class _Colleges extends CollegesNotifier {
  _Colleges(this.status);
  final UserCollegeStatus status;
  @override
  Future<List<CollegeListEntry>> build() async => [
        for (final c in kCollegeCatalog) CollegeListEntry(catalog: c, userStatus: c.refId == 26 ? status : null),
      ];
}

/// Store en mémoire : les E/S fichier réelles ne se terminent pas dans la zone
/// de temps simulé de testWidgets (le vrai store a ses tests unitaires).
class _MemStore extends LocalPdfStore {
  _MemStore() : super(Directory('/collega-test-pdfs'));
  final _versions = <String, List<String>>{};
  final _pages = <String, int>{};

  @override
  Future<File?> readable(String collegeId, String? serverVersion) async {
    final v = _versions[collegeId] ?? const [];
    if (serverVersion == null) return v.isEmpty ? null : fileFor(collegeId, v.last);
    return v.contains(serverVersion) ? fileFor(collegeId, serverVersion) : null;
  }

  @override
  Future<LocalPdfStatus> status(String collegeId, String? serverVersion) async {
    if (await readable(collegeId, serverVersion) != null) return LocalPdfStatus.upToDate;
    return (_versions[collegeId] ?? const []).isEmpty ? LocalPdfStatus.absent : LocalPdfStatus.outdated;
  }

  @override
  Future<void> keepCopy({required String collegeId, required String version, required File source}) async =>
      (_versions[collegeId] ??= []).add(version);

  @override
  Future<void> adopt({required String collegeId, required String version, required File downloaded}) async =>
      (_versions[collegeId] ??= []).add(version);

  @override
  Future<bool> verifyDownload(File f, {int? expectedSize}) async => true;

  @override
  Future<int?> lastPage(String collegeId) async => _pages[collegeId];

  @override
  Future<void> saveLastPage(String collegeId, int page) async => _pages[collegeId] = page;
}

class _FakeDownloader implements PdfDownloader {
  _FakeDownloader({this.fail = false});
  final bool fail;
  @override
  Future<File> download({
    required String collegeId,
    required String version,
    required Directory into,
    required void Function(double) onProgress,
  }) async {
    onProgress(0.5);
    if (fail) throw const PdfDownloadFailed('réseau');
    onProgress(1);
    return File('${into.path}/${collegeId}_$version.pdf.part');
  }
}

/// Faux lecteur : annonce la page et le « aller à » une seule fois, comme pdfrx.
class _FakeDoc extends StatefulWidget {
  const _FakeDoc({required this.label, required this.onShown});
  final String label;
  final VoidCallback onShown;

  @override
  State<_FakeDoc> createState() => _FakeDocState();
}

class _FakeDocState extends State<_FakeDoc> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onShown());
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

const _status = UserCollegeStatus(
  refId: 26,
  collegeId: 'c26',
  status: 'generation_complete',
  cardCountA: 1,
  cardCountB: 0,
  cardCountC: 0,
  pdfVersion: 'j1',
  pdfSize: 398458880,
);

const _item = ItemModel(
  id: 'i340',
  collegeId: 'c26',
  itemNumber: 340,
  rang: 'A',
  chapterTitle: 'Accident vasculaire cérébral',
  ocrConfidenceScore: 0.9,
  lowConfidence: false,
  cardCountA: 0,
  cardCountB: 0,
  cardCountC: 0,
  startPage: 111,
  endPage: 117,
);

void main() {
  late Directory tmp;
  late _MemStore store;
  late File pdfSource;
  late List<int> goTos;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdfreader');
    store = _MemStore();
    pdfSource = File('${tmp.path}/src.pdf')..writeAsStringSync('%PDF-1.7');
    goTos = [];
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Widget fakeBuilder({
    required String path,
    required int initialPage,
    required void Function(int page, int pageCount) onPage,
    required void Function(Future<void> Function(int page) goTo) onReady,
  }) {
    return _FakeDoc(
      label: 'PDF $path @ $initialPage',
      onShown: () {
        onReady((p) async => goTos.add(p));
        onPage(initialPage, 480);
      },
    );
  }

  Widget app(String location, {bool failDownload = false, UserCollegeStatus status = _status}) {
    final router = GoRouter(initialLocation: location, routes: [
      GoRoute(
        path: '/colleges/:ref_id/pdf',
        builder: (_, s) => PdfReaderScreen(
          refId: int.parse(s.pathParameters['ref_id']!),
          page: int.tryParse(s.uri.queryParameters['page'] ?? ''),
          itemId: s.uri.queryParameters['item'],
        ),
      ),
    ]);
    return ProviderScope(
      overrides: [
        collegesProvider.overrideWith(() => _Colleges(status)),
        localPdfStoreProvider.overrideWith((ref) async => store),
        itemInfoProvider.overrideWith((ref, id) async => _item),
        pdfDocumentBuilderProvider.overrideWithValue(fakeBuilder),
        pdfDownloaderProvider.overrideWithValue(_FakeDownloader(fail: failDownload)),
      ],
      child: CgTheme(
        data: CgThemeData.light,
        child: MaterialApp.router(theme: buildCgMaterialTheme(CgThemeData.light), routerConfig: router),
      ),
    );
  }

  testWidgets('copie à jour, depuis un item : s’ouvre p. 112, bandeau et « ↑ Début »', (tester) async {
    await store.keepCopy(collegeId: 'c26', version: 'j1', source: pdfSource);
    await tester.pumpWidget(app('/colleges/26/pdf?page=112&item=i340'));
    await tester.pumpAndSettle();
    expect(find.textContaining('@ 112'), findsOneWidget);
    expect(find.text('p. 112 / 480'), findsOneWidget);
    expect(find.text('Item 340 · p. 112–118'), findsOneWidget);
    await tester.tap(find.text('↑ Début'));
    expect(goTos, [112]);
  });

  testWidgets('depuis la vue collège : dernière page lue, sinon p. 1 ; pas de bandeau', (tester) async {
    await store.keepCopy(collegeId: 'c26', version: 'j1', source: pdfSource);
    await store.saveLastPage('c26', 57);
    await tester.pumpWidget(app('/colleges/26/pdf'));
    await tester.pumpAndSettle();
    expect(find.textContaining('@ 57'), findsOneWidget);
    expect(find.textContaining('↑ Début'), findsNothing);
  });

  testWidgets('PDF absent : taille, conseil Wi-Fi, téléchargement puis lecture', (tester) async {
    await tester.pumpWidget(app('/colleges/26/pdf?page=112&item=i340'));
    await tester.pumpAndSettle();
    expect(find.text('Ton PDF n’est pas sur ce téléphone'), findsOneWidget);
    expect(find.text('Télécharger (380 Mo)'), findsOneWidget);
    expect(find.textContaining('Wi-Fi'), findsOneWidget);
    await tester.tap(find.text('Télécharger (380 Mo)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('@ 112'), findsOneWidget);
  });

  testWidgets('copie périmée : « Une nouvelle version de ton PDF est disponible »', (tester) async {
    await store.keepCopy(collegeId: 'c26', version: 'j0', source: pdfSource);
    await tester.pumpWidget(app('/colleges/26/pdf'));
    await tester.pumpAndSettle();
    expect(find.text('Une nouvelle version de ton PDF est disponible'), findsOneWidget);
  });

  testWidgets('téléchargement échoué : message et « Réessayer »', (tester) async {
    // pdfDownloaderProvider surchargé avec _FakeDownloader(fail: true)
    await tester.pumpWidget(app('/colleges/26/pdf', failDownload: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Télécharger (380 Mo)'));
    await tester.pumpAndSettle();
    expect(find.text('Le téléchargement n’a pas abouti'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('backend sans version de PDF et rien sur le téléphone : « indisponible », aucun bouton mort',
      (tester) async {
    const legacy = UserCollegeStatus(
      refId: 26,
      collegeId: 'c26',
      status: 'generation_complete',
      cardCountA: 1,
      cardCountB: 0,
      cardCountC: 0,
    );
    await tester.pumpWidget(app('/colleges/26/pdf', status: legacy));
    await tester.pumpAndSettle();
    expect(find.text('Ton PDF n’est pas disponible pour l’instant'), findsOneWidget);
    expect(find.textContaining('Télécharger'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backend sans version de PDF mais copie gardée à l’import : lisible', (tester) async {
    const legacy = UserCollegeStatus(
      refId: 26,
      collegeId: 'c26',
      status: 'generation_complete',
      cardCountA: 1,
      cardCountB: 0,
      cardCountC: 0,
    );
    await store.keepCopy(collegeId: 'c26', version: 'j1', source: pdfSource);
    await tester.pumpWidget(app('/colleges/26/pdf?page=3', status: legacy));
    await tester.pumpAndSettle();
    expect(find.textContaining('@ 3'), findsOneWidget);
  });
}
