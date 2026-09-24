import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/data/auth_repository.dart';
import 'package:collega_app/features/auth/data/revenuecat_service.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/auth/paywall_providers.dart';
import 'package:collega_app/features/auth/presentation/paywall_screen.dart';

import '../../support/cg_golden.dart';

class _RevenueCat extends RevenueCatService {
  static Object? purchaseError;
  static Object? restoreError;
  static int purchases = 0;

  @override
  Future<Package?> getMonthlyOffering() async => null;

  @override
  Future<PurchaseResult> purchaseMonthlySubscription(Package package) async {
    purchases++;
    throw purchaseError ?? StateError('pas de résultat en test');
  }

  @override
  Future<CustomerInfo> restorePurchases() async => throw restoreError ?? StateError('pas de résultat en test');
}

class _AuthRepository extends AuthRepository {
  _AuthRepository() : super(dio: Dio(), storage: const FlutterSecureStorage());

  static int logouts = 0;

  @override
  Future<AuthState> loadStoredUser() async =>
      const AuthState(user: AuthUser(id: 'u', email: 'a@b.fr', isBeta: false, isSubscribed: false));

  @override
  Future<void> logout() async => logouts++;

  @override
  Future<AuthState> refreshSubscriptionStatus() async => loadStoredUser();
}

class _Paywall extends PaywallNotifier {
  static PaywallState initial = const PaywallState();

  @override
  Future<PaywallState> build() async => initial;
}

/// Offre du Store : seul le prix affiché est lu par l'écran.
class _Package extends Fake implements Package {
  @override
  StoreProduct get storeProduct => _Product();
}

class _Product extends Fake implements StoreProduct {
  @override
  String get priceString => '9,99 €';
}

Widget _app({List<String>? visited, double textScale = 1}) {
  final router = GoRouter(initialLocation: '/paywall', routes: [
    GoRoute(path: '/paywall', builder: (_, __) => const PaywallScreen()),
    for (final p in ['/legal/cgu', '/legal/privacy'])
      GoRoute(path: p, builder: (_, __) {
        visited?.add(p);
        return const SizedBox();
      }),
  ]);
  return ProviderScope(
    overrides: [
      revenueCatServiceProvider.overrideWithValue(_RevenueCat()),
      authRepositoryProvider.overrideWithValue(_AuthRepository()),
      paywallProvider.overrideWith(_Paywall.new),
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

void _phone(WidgetTester tester, {double width = 393, double height = 1400}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(loadCgFonts);
  setUp(() {
    _Paywall.initial = PaywallState(package: _Package());
    _RevenueCat.purchaseError = null;
    _RevenueCat.restoreError = null;
    _RevenueCat.purchases = 0;
    _AuthRepository.logouts = 0;
  });

  testWidgets('marque, bénéfices, prix du Store, un seul primaire « S’abonner »', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(CgWordmark), findsOneWidget);
    expect(find.byType(CgLogo), findsOneWidget);
    expect(find.text('Collega Premium'), findsOneWidget);
    expect(find.byType(CgListRow), findsNWidgets(4));
    expect(find.text('9,99 €'), findsOneWidget);
    expect(find.text('par mois · sans engagement, résiliable dans Réglages'), findsOneWidget);
    final primaries = tester.widgetList<CgButton>(find.byType(CgButton)).where((b) => b.variant == CgButtonVariant.primary);
    expect(primaries.map((b) => b.label), ['S’abonner']);
    expect(find.text('Restaurer mes achats'), findsOneWidget);
    expect(find.text('Gérer mon abonnement'), findsNothing);
  });

  testWidgets('pas de prix inventé : offre indisponible → message + « Réessayer »', (tester) async {
    _phone(tester);
    _Paywall.initial = const PaywallState();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.textContaining('€'), findsNothing);
    expect(find.text('L’abonnement n’est pas disponible pour l’instant. Vérifie ta connexion et réessaie.'),
        findsOneWidget);
    final primaries = tester.widgetList<CgButton>(find.byType(CgButton)).where((b) => b.variant == CgButtonVariant.primary);
    expect(primaries.map((b) => b.label), ['Réessayer']);
  });

  testWidgets('achat annulé : rien n’est affiché', (tester) async {
    _phone(tester);
    _RevenueCat.purchaseError = PlatformException(code: '1');
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('S’abonner'));
    await tester.pumpAndSettle();
    expect(_RevenueCat.purchases, 1);
    expect(find.byKey(PaywallScreen.errorKey), findsNothing);
  });

  testWidgets('achat en échec : dit sur place, pas en toast', (tester) async {
    _phone(tester);
    _RevenueCat.purchaseError = PlatformException(code: '2');
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('S’abonner'));
    await tester.pumpAndSettle();
    expect(find.text('L’achat n’a pas abouti. Réessaie dans un instant.'), findsOneWidget);
  });

  testWidgets('restauration en échec : dit sur place', (tester) async {
    _phone(tester);
    _RevenueCat.restoreError = null;
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurer mes achats'));
    await tester.pumpAndSettle();
    expect(find.text('La restauration n’a pas abouti. Réessaie dans un instant.'), findsOneWidget);
  });

  testWidgets('« Se déconnecter » (jamais bloquée ici) et liens CGU / Confidentialité', (tester) async {
    _phone(tester);
    final visited = <String>[];
    await tester.pumpWidget(_app(visited: visited));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conditions d’utilisation'));
    await tester.pumpAndSettle();
    expect(visited, ['/legal/cgu']);
  });

  testWidgets('« Se déconnecter » déconnecte', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(_AuthRepository.logouts, 1);
  });

  testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement', (tester) async {
    _phone(tester, width: 375, height: 812);
    await tester.pumpWidget(_app(textScale: 1.6));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('aucun widget Material ni shadcn', () {
    final src = File('lib/features/auth/presentation/paywall_screen.dart').readAsStringSync();
    expect(src, isNot(contains('material.dart')));
    expect(src, isNot(contains('shadcn_ui')));
  });

  group('goldens', () {
    for (final width in cgGoldenWidths) {
      for (final scale in cgGoldenScales) {
        final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
        testWidgets('golden paywall_$tag', tags: const ['golden'], (tester) async {
          _phone(tester, width: width, height: 900);
          await tester.pumpWidget(_app(textScale: scale));
          await tester.pumpAndSettle();
          await expectLater(find.byType(CgGoldenFrame), matchesGoldenFile('goldens/paywall_$tag.png'));
        });
      }
    }
  });
}
