import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/search/domain/search_result.dart';
import 'package:collega_app/features/search/widgets/search_result_tile.dart';

SearchResult _makeResult({
  String? itemId,
  int itemNumber = 232,
  String rang = 'A',
  String? chapterTitle = 'Insuffisance Cardiaque',
  String collegeId = 'college-uuid',
  int collegeRefId = 1,
  String excerpt = 'Élévation du <mark>BNP</mark> en cas d\'insuffisance.',
}) {
  return SearchResult(
    itemId: itemId ?? 'item-uuid',
    itemNumber: itemNumber,
    rang: rang,
    chapterTitle: chapterTitle,
    collegeId: collegeId,
    collegeRefId: collegeRefId,
    excerpt: excerpt,
  );
}

Widget _wrap(Widget child) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
    GoRoute(
        path: '/drill',
        builder: (_, __) => const Scaffold(body: Text('Drill'))),
    GoRoute(
        path: '/colleges/:ref_id/items/:item_id',
        builder: (_, __) => const Scaffold(body: Text('ItemDetail'))),
    GoRoute(
        path: '/search',
        builder: (_, __) => const Scaffold(body: Text('Search'))),
  ]);
  return ProviderScope(
    child: ShadApp.router(
      theme: buildShadTheme(),
      routerConfig: router,
    ),
  );
}

void main() {
  group('SearchResult.fromJson', () {
    test('parse correctement tous les champs', () {
      final json = {
        'item_id': 'abc-123',
        'item_number': 232,
        'rang': 'A',
        'chapter_title': 'Insuffisance Cardiaque',
        'college_id': 'col-uuid',
        'college_ref_id': 1,
        'excerpt': '<mark>BNP</mark> élevé',
      };
      final result = SearchResult.fromJson(json);
      expect(result.itemId, 'abc-123');
      expect(result.itemNumber, 232);
      expect(result.rang, 'A');
      expect(result.chapterTitle, 'Insuffisance Cardiaque');
      expect(result.collegeId, 'col-uuid');
      expect(result.collegeRefId, 1);
      expect(result.excerpt, '<mark>BNP</mark> élevé');
    });

    test('chapter_title peut être null', () {
      final json = {
        'item_id': 'abc',
        'item_number': 10,
        'rang': 'B',
        'chapter_title': null,
        'college_id': 'c',
        'college_ref_id': 2,
        'excerpt': 'texte',
      };
      final result = SearchResult.fromJson(json);
      expect(result.chapterTitle, isNull);
    });
  });

  group('_HighlightedExcerpt', () {
    testWidgets('terme entre <mark> a fond vert B7F2C8', (tester) async {
      await tester.pumpWidget(_wrap(
        SearchResultTile(result: _makeResult()),
      ));
      await tester.pump(Duration.zero);

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      bool foundHighlight = false;
      for (final rt in richTexts) {
        rt.text.visitChildren((span) {
          if (span is TextSpan &&
              span.style?.backgroundColor == const Color(0xFFB7F2C8)) {
            foundHighlight = true;
          }
          return true;
        });
      }
      expect(foundHighlight, isTrue);
    });
  });

  group('SearchResultTile', () {
    testWidgets('Rang A → CTA "Réviser l\'item" visible', (tester) async {
      await tester.pumpWidget(_wrap(SearchResultTile(result: _makeResult(rang: 'A'))));
      await tester.pump(Duration.zero);
      expect(find.text("Réviser l'item"), findsOneWidget);
    });

    testWidgets('Rang B → CTA absent', (tester) async {
      await tester.pumpWidget(_wrap(SearchResultTile(result: _makeResult(rang: 'B'))));
      await tester.pump(Duration.zero);
      expect(find.text("Réviser l'item"), findsNothing);
    });

    testWidgets('Rang C → CTA absent', (tester) async {
      await tester.pumpWidget(_wrap(SearchResultTile(result: _makeResult(rang: 'C'))));
      await tester.pump(Duration.zero);
      expect(find.text("Réviser l'item"), findsNothing);
    });

    testWidgets('Rang A — CTA "Réviser l\'item" navigue vers DrillScreen', (tester) async {
      await tester.pumpWidget(_wrap(SearchResultTile(result: _makeResult(rang: 'A', itemNumber: 232, collegeRefId: 1))));
      await tester.pump(Duration.zero);
      expect(find.text("Réviser l'item"), findsOneWidget);
      await tester.tap(find.text("Réviser l'item"));
      await tester.pumpAndSettle();
      expect(find.text('Drill'), findsOneWidget);
    });

    testWidgets('Rang B — tap ouvre ItemDetailScreen', (tester) async {
      await tester.pumpWidget(_wrap(SearchResultTile(result: _makeResult(rang: 'B'))));
      await tester.pump(Duration.zero);
      expect(find.text("Réviser l'item"), findsNothing);
      await tester.tap(find.byType(SearchResultTile));
      await tester.pumpAndSettle();
      expect(find.text('ItemDetail'), findsOneWidget);
    });

    testWidgets('Rang C — tap ouvre ItemDetailScreen', (tester) async {
      await tester.pumpWidget(_wrap(SearchResultTile(result: _makeResult(rang: 'C'))));
      await tester.pump(Duration.zero);
      await tester.tap(find.byType(SearchResultTile));
      await tester.pumpAndSettle();
      expect(find.text('ItemDetail'), findsOneWidget);
    });

    testWidgets('affiche provenance "Item N · Nom Collège"', (tester) async {
      await tester.pumpWidget(_wrap(
        SearchResultTile(
          result: _makeResult(itemNumber: 232, collegeRefId: 1),
        ),
      ));
      await tester.pump(Duration.zero);
      // collegeRefId=1 → Cardiologie et maladies vasculaires
      expect(
        find.textContaining('Item 232'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Cardiologie et maladies vasculaires'),
        findsOneWidget,
      );
    });
  });
}
