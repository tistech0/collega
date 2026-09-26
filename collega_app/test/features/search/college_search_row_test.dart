// collega_app/test/features/search/college_search_row_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/search/presentation/college_search_row.dart';

final _neuro = collegeCatalogEntry(26)!;

CollegeListEntry _entry({String? status, int cards = 0}) => CollegeListEntry(
      catalog: _neuro,
      userStatus: status == null
          ? null
          : UserCollegeStatus(refId: 26, collegeId: 'c26', status: status, cardCountA: cards, cardCountB: 0, cardCountC: 0),
    );

Widget _host(Widget row) => CgTheme(
      data: CgThemeData.light,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(data: const MediaQueryData(size: Size(393, 852)), child: Center(child: row)),
      ),
    );

void main() {
  testWidgets('importé et prêt : « éditeur · N fiches », toucher ouvre', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_host(CollegeSearchRow(
      entry: _entry(status: 'generation_complete', cards: 412),
      onOpen: () => opened++,
      onImport: () => fail('pas d’import'),
    )));
    expect(find.text('Neurologie'), findsOneWidget);
    expect(find.text('CEN · 412 fiches'), findsOneWidget);
    expect(find.text('Importer'), findsNothing);
    await tester.tap(find.text('Neurologie'));
    expect(opened, 1);
  });

  testWidgets('importé, 1 fiche : singulier', (tester) async {
    await tester.pumpWidget(_host(CollegeSearchRow(
      entry: _entry(status: 'generation_complete', cards: 1),
      onOpen: () {},
      onImport: () {},
    )));
    expect(find.text('CEN · 1 fiche'), findsOneWidget);
  });

  testWidgets('import échoué ou en cours : sous-titre dédié', (tester) async {
    await tester.pumpWidget(_host(CollegeSearchRow(entry: _entry(status: 'failed'), onOpen: () {}, onImport: () {})));
    expect(find.text('CEN · l’import n’a pas abouti'), findsOneWidget);
    await tester.pumpWidget(_host(CollegeSearchRow(entry: _entry(status: 'processing'), onOpen: () {}, onImport: () {})));
    expect(find.text('CEN · import en cours'), findsOneWidget);
  });

  testWidgets('non importé : « pas encore importé » + « Importer »', (tester) async {
    var imported = 0;
    await tester.pumpWidget(_host(CollegeSearchRow(
      entry: _entry(),
      onOpen: () => fail('pas d’ouverture'),
      onImport: () => imported++,
    )));
    expect(find.text('CEN · pas encore importé'), findsOneWidget);
    await tester.tap(find.text('Importer'));
    expect(imported, 1);
  });

  testWidgets('en cours d’envoi : progression, toucher mène à l’import, jamais « Importer »', (tester) async {
    var imported = 0;
    await tester.pumpWidget(_host(CollegeSearchRow(
      entry: _entry(),
      uploading: true,
      progress: 0.42,
      onOpen: () => fail('pas d’ouverture'),
      onImport: () => imported++,
    )));
    expect(find.text('CEN · envoi du PDF : 42 %'), findsOneWidget);
    expect(find.text('Importer'), findsNothing);
    await tester.tap(find.text('Neurologie'));
    expect(imported, 1);
  });
}
