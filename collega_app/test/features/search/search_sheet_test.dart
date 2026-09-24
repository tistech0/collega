import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/presentation/college_detail_screen.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';
import 'package:collega_app/features/search/data/search_repository.dart';
import 'package:collega_app/features/search/domain/search_result.dart';
import 'package:collega_app/features/search/presentation/search_sheet.dart';
import 'package:collega_app/features/search/search_providers.dart';

import '../../support/cg_golden.dart';

const _ic = SearchResult(
  itemId: 'id-232', itemNumber: 232, rang: 'A', chapterTitle: 'Insuffisance cardiaque',
  collegeId: 'c3', collegeRefId: 3,
  excerpt: 'Élévation du <mark>BNP</mark> en cas d’insuffisance cardiaque décompensée.',
);
const _dyspnee = SearchResult(
  itemId: 'id-203', itemNumber: 203, rang: 'B', chapterTitle: null,
  collegeId: 'c34', collegeRefId: 34,
  excerpt: 'Radiographie thoracique, NFS, <mark>BNP</mark> (suspicion cardiopathie), ECG.',
);

class _Repo extends SearchRepository {
  _Repo() : super(Dio());
  List<SearchResult> results = const [_ic, _dyspnee];
  Object? error;
  @override
  Future<List<SearchResult>> search(String query) async {
    if (error != null) throw error!;
    return results;
  }
}

class _Recents implements SearchRecentsStore {
  List<String> saved = [];
  @override
  Future<List<String>> read() async => saved;
  @override
  Future<void> write(List<String> recents) async => saved = List.of(recents);
  @override
  Future<void> clearAll() async => saved = [];
}

class _Prefs extends RevisionPrefsNotifier {
  @override
  Future<RevisionPrefs> build() async => const RevisionPrefs();
}

class _Visit {
  final paths = <String>[];
  final extras = <Object?>[];
}

late _Repo _repo;
late _Recents _recents;

Widget _app({_Visit? visit, double textScale = 1, String initial = '/'}) {
  final router = GoRouter(initialLocation: initial, routes: [
    GoRoute(
      path: '/',
      builder: (context, __) => Center(
        child: GestureDetector(
          onTap: () => showSearchSheet(context),
          child: const Text('ouvrir'),
        ),
      ),
    ),
    GoRoute(
      path: '/today',
      builder: (context, __) => Center(
        child: GestureDetector(
          onTap: () => showSearchSheet(context, origin: CollegeDetailOrigin.today),
          child: const Text('ouvrir depuis Aujourd’hui'),
        ),
      ),
    ),
    for (final path in ['/colleges', '/colleges/:ref/items/:item', '/home/colleges/:ref/items/:item', '/drill'])
      GoRoute(path: path, builder: (_, s) {
        visit?.paths.add(s.uri.path);
        visit?.extras.add(s.extra);
        return const SizedBox();
      }),
  ]);
  return ProviderScope(
    overrides: [
      searchRepositoryProvider.overrideWithValue(_repo),
      searchRecentsStoreProvider.overrideWithValue(_recents),
      revisionPrefsProvider.overrideWith(_Prefs.new),
    ],
    child: CgTheme(
      data: CgThemeData.light,
      child: WidgetsApp.router(
        debugShowCheckedModeBanner: false,
        color: CgColors.light.accent,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: true),
          child: CgGoldenFrame(child: child!),
        ),
      ),
    ),
  );
}

void _phone(WidgetTester tester, {double width = 393, double height = 852}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(EditableText), text);
  await tester.pump(kSearchDebounce);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadCgFonts);
  setUp(() {
    _repo = _Repo();
    _recents = _Recents();
  });

  group('accueil de la recherche', () {
    testWidgets('clavier ouvert, récentes puis exemples', (tester) async {
      _phone(tester);
      _recents.saved = ['alcool', 'amoxicilline'];
      await tester.pumpWidget(_app());
      await _open(tester);
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);
      expect(find.text('Récentes'), findsOneWidget);
      expect(find.text('alcool'), findsOneWidget);
      expect(find.text('Cherche un item, un signe, une dose'), findsOneWidget);
      for (final e in ['BNP', 'Gardasil', 'dyspnée']) {
        expect(find.text(e), findsOneWidget);
      }
    });

    testWidgets('un exemple lance la recherche', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await _open(tester);
      await tester.tap(find.text('BNP'));
      await tester.pump(kSearchDebounce);
      await tester.pumpAndSettle();
      expect(find.text('2 résultats'), findsOneWidget);
    });

    testWidgets('« Effacer » vide les récentes', (tester) async {
      _phone(tester);
      _recents.saved = ['alcool'];
      await tester.pumpWidget(_app());
      await _open(tester);
      await tester.tap(find.text('Effacer'));
      await tester.pumpAndSettle();
      expect(find.text('Récentes'), findsNothing);
      expect(_recents.saved, isEmpty);
    });

    testWidgets('« Annuler » ferme ; rouverte, la sheet garde la dernière recherche', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await _open(tester);
      await _type(tester, 'BNP');
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsNothing);
      await _open(tester);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'BNP');
      expect(find.text('2 résultats'), findsOneWidget);
    });
  });

  group('résultats', () {
    testWidgets('« N résultats », titre d’item, item · collège, phrase avec le terme surligné', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await _open(tester);
      await _type(tester, 'BNP');
      expect(find.text('2 résultats'), findsOneWidget);
      expect(find.text('Insuffisance cardiaque'), findsOneWidget);
      expect(find.text('Item 232 · Cancérologie'), findsOneWidget);
      expect(find.text('Item 203'), findsOneWidget, reason: 'repli sans titre');
      expect(find.text('Pneumologie'), findsOneWidget, reason: 'sans titre : « Item 203 » non répété');
      final excerpt = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().startsWith('Élévation du BNP'),
      );
      expect(excerpt, findsOneWidget);
      final spans = <InlineSpan>[];
      tester.widget<RichText>(excerpt).text.visitChildren((s) {
        spans.add(s);
        return true;
      });
      final mark = spans.whereType<TextSpan>().firstWhere((s) => s.text == 'BNP');
      expect(mark.style?.backgroundColor, CgColors.light.accentSoft);
    });

    testWidgets('toucher un résultat ferme la sheet et ouvre l’item (retour « Recherche »), récente ajoutée', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(visit: visit));
      await _open(tester);
      await _type(tester, 'BNP');
      await tester.tap(find.text('Insuffisance cardiaque'));
      await tester.pumpAndSettle();
      expect(visit.paths, ['/colleges/3/items/id-232']);
      expect(visit.extras, ['search']);
      expect(find.byType(EditableText), findsNothing);
      expect(_recents.saved, ['BNP']);
    });

    testWidgets('ouverte depuis Aujourd’hui : l’item s’ouvre sous Aujourd’hui (onglet gardé)', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(visit: visit, initial: '/today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ouvrir depuis Aujourd’hui'));
      await tester.pumpAndSettle();
      await _type(tester, 'BNP');
      await tester.tap(find.text('Insuffisance cardiaque'));
      await tester.pumpAndSettle();
      expect(visit.paths, ['/home/colleges/3/items/id-232']);
    });

    testWidgets('extrait long : le terme reste visible (fenêtre autour du terme)', (tester) async {
      _phone(tester);
      _repo.results = [
        SearchResult(
          itemId: 'x', itemNumber: 1, rang: 'A', chapterTitle: 'Titre', collegeId: 'c3', collegeRefId: 3,
          excerpt: '${List.filled(30, 'contexte').join(' ')} puis le <mark>BNP</mark> à la fin.',
        ),
      ];
      await tester.pumpWidget(_app());
      await _open(tester);
      await _type(tester, 'BNP');
      final text = tester
          .widget<RichText>(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('BNP')))
          .text
          .toPlainText();
      expect(text, startsWith('…'));
      expect(text.indexOf('BNP'), lessThan(70));
    });

    testWidgets('« Rechercher » au clavier : résultats sans attendre, récente enregistrée', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await _open(tester);
      await tester.enterText(find.byType(EditableText), 'BNP');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('2 résultats'), findsOneWidget);
      expect(_recents.saved, ['BNP']);
    });

    testWidgets('« Réviser » : action secondaire, lance le drill de l’item', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(visit: visit));
      await _open(tester);
      await _type(tester, 'BNP');
      await tester.tap(find.text('Réviser').first);
      await tester.pumpAndSettle();
      expect(visit.paths, ['/drill']);
      final launch = visit.extras.single! as DrillLaunch;
      expect(launch.params.itemId, 'id-232');
      expect(launch.params.fromSearch, isTrue);
      expect(launch.params.itemName, 'Insuffisance cardiaque');
    });
  });

  group('états', () {
    testWidgets('aucun résultat', (tester) async {
      _phone(tester);
      _repo.results = const [];
      await tester.pumpWidget(_app());
      await _open(tester);
      await _type(tester, 'xyz');
      expect(find.text('Aucun résultat pour « xyz »'), findsOneWidget);
    });

    testWidgets('hors-ligne : état dans la sheet + Bibliothèque', (tester) async {
      _phone(tester);
      final visit = _Visit();
      _repo.error = DioException(requestOptions: RequestOptions(path: '/s'), type: DioExceptionType.connectionError);
      await tester.pumpWidget(_app(visit: visit));
      await _open(tester);
      await _type(tester, 'BNP');
      expect(find.text('La recherche a besoin d’une connexion'), findsOneWidget);
      expect(find.text('Tes collèges restent disponibles.'), findsOneWidget);
      await tester.tap(find.text('Aller à la Bibliothèque'));
      await tester.pumpAndSettle();
      expect(visit.paths, ['/colleges']);
    });

    testWidgets('erreur serveur : Réessayer relance', (tester) async {
      _phone(tester);
      _repo.error = DioException(requestOptions: RequestOptions(path: '/s'), type: DioExceptionType.badResponse);
      await tester.pumpWidget(_app());
      await _open(tester);
      await _type(tester, 'BNP');
      expect(find.text('La recherche n’a pas abouti'), findsOneWidget);
      _repo.error = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('2 résultats'), findsOneWidget);
    });
  });

  group('accessibilité', () {
    testWidgets('le champ est lu « Rechercher »', (tester) async {
      _phone(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await _open(tester);
      expect(find.bySemanticsLabel(RegExp('^Rechercher')), findsWidgets);
      handle.dispose();
    });

    testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement', (tester) async {
      _phone(tester, width: 375, height: 812);
      _recents.saved = ['amoxicilline'];
      await tester.pumpWidget(_app(textScale: 1.6));
      await _open(tester);
      expect(tester.takeException(), isNull);
      await _type(tester, 'BNP');
      expect(tester.takeException(), isNull);
    });

    test('aucun widget Material ni shadcn', () {
      final src = File('lib/features/search/presentation/search_sheet.dart').readAsStringSync();
      expect(src, isNot(contains('material.dart')));
      expect(src, isNot(contains('shadcn_ui')));
    });
  });

  group('goldens', () {
    for (final (name, query) in [('home', null), ('results', 'BNP')]) {
      for (final width in cgGoldenWidths) {
        for (final scale in cgGoldenScales) {
          final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
          testWidgets('golden search_${name}_$tag', (tester) async {
            _phone(tester, width: width, height: 900);
            _recents.saved = ['alcool', 'amoxicilline'];
            await tester.pumpWidget(_app(textScale: scale));
            await _open(tester);
            if (query != null) await _type(tester, query);
            // Curseur clignotant : on retire le focus pour une image stable.
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pumpAndSettle();
            await expectLater(find.byType(CgGoldenFrame), matchesGoldenFile('goldens/search_${name}_$tag.png'));
          });
        }
      }
    }
  });
}
