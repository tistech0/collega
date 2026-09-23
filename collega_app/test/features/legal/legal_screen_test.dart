import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/legal/presentation/legal_screen.dart';

import '../../support/cg_golden.dart';

/// Documents lus depuis le disque, servis sans E/S asynchrone (temps de test simulé).
class _MemoryBundle extends CachingAssetBundle {
  _MemoryBundle({this.failFirst = false});

  final bool failFirst;
  int calls = 0;

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    calls++;
    if (failFirst && calls == 1) return Future.error(FlutterError('asset introuvable'));
    return SynchronousFuture(File(key).readAsStringSync());
  }
}

Widget _app(LegalDocument doc, {AssetBundle? bundle, List<String>? visited, double textScale = 1}) {
  final router = GoRouter(initialLocation: '/profile', routes: [
    GoRoute(path: '/profile', builder: (_, __) {
      visited?.add('/profile');
      return Builder(builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (visited != null && visited.length == 1) context.push('/legal');
        });
        return const SizedBox();
      });
    }),
    GoRoute(path: '/legal', builder: (_, __) => LegalScreen(document: doc)),
  ]);
  final app = CgTheme(
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
  );
  return DefaultAssetBundle(bundle: bundle ?? _MemoryBundle(), child: app);
}

void _phone(WidgetTester tester, {double width = 393, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _openFromProfile(WidgetTester tester, LegalDocument doc, {AssetBundle? bundle, double textScale = 1}) async {
  final visited = <String>[];
  await tester.pumpWidget(_app(doc, bundle: bundle, visited: visited, textScale: textScale));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadCgFonts);

  testWidgets('CGU : titre de page, texte Markdown aux styles Collega, sans le titre répété', (tester) async {
    _phone(tester);
    await _openFromProfile(tester, LegalDocument.cgu);
    expect(find.text('Conditions d’utilisation'), findsWidgets);
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('Objet du service'), findsOneWidget);
    expect(find.text('Conditions Générales d\'Utilisation'), findsNothing);
  });

  testWidgets('le produit s’appelle Collega (plus « AppMédecine »)', (tester) async {
    for (final doc in LegalDocument.values) {
      final text = File(doc.assetPath).readAsStringSync();
      expect(text, isNot(contains('AppMédecine')), reason: doc.assetPath);
      expect(text, contains('Collega'), reason: doc.assetPath);
    }
  });

  testWidgets('« ‹ Retour » revient à l’écran précédent', (tester) async {
    _phone(tester);
    await _openFromProfile(tester, LegalDocument.privacy);
    expect(find.byType(LegalScreen), findsOneWidget);
    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsNothing);
  });

  testWidgets('document illisible : état d’erreur + « Réessayer » (jamais l’erreur brute)', (tester) async {
    _phone(tester);
    final bundle = _MemoryBundle(failFirst: true);
    await _openFromProfile(tester, LegalDocument.cgu, bundle: bundle);
    expect(find.text('Le document n’a pas pu s’ouvrir'), findsOneWidget);
    expect(find.textContaining('introuvable'), findsNothing);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement (tableau compris)', (tester) async {
    _phone(tester, width: 375, height: 812);
    await _openFromProfile(tester, LegalDocument.privacy, textScale: 1.6);
    expect(tester.takeException(), isNull);
  });

  test('aucun widget Material ni shadcn', () {
    final src = File('lib/features/legal/presentation/legal_screen.dart').readAsStringSync();
    expect(src, isNot(contains('material.dart')));
    expect(src, isNot(contains('shadcn_ui')));
  });

  group('goldens', () {
    for (final width in cgGoldenWidths) {
      for (final scale in cgGoldenScales) {
        final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
        testWidgets('golden legal_cgu_$tag', (tester) async {
          _phone(tester, width: width);
          await _openFromProfile(tester, LegalDocument.cgu, textScale: scale);
          await expectLater(find.byType(CgGoldenFrame), matchesGoldenFile('goldens/legal_cgu_$tag.png'));
        });
      }
    }
  });
}
