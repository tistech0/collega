import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/data/auth_repository.dart';
import 'package:collega_app/features/auth/data/revenuecat_service.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/auth/paywall_providers.dart';
import 'package:collega_app/features/auth/presentation/paywall_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeRevenueCatService extends RevenueCatService {
  bool subscriptionManagementOpened = false;

  @override
  Future<Package?> getMonthlyOffering() async => null;

  @override
  Future<PurchaseResult> purchaseMonthlySubscription(Package package) {
    throw UnimplementedError('not used in widget tests');
  }

  @override
  Future<CustomerInfo> restorePurchases() {
    throw UnimplementedError('not used in widget tests');
  }

  @override
  Future<void> openSubscriptionManagement() async {
    subscriptionManagementOpened = true;
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository()
      : super(dio: Dio(), storage: const FlutterSecureStorage());

  @override
  Future<AuthState> loadStoredUser() async => const AuthState();

  @override
  Future<AuthState> login(String email, String password) async => const AuthState();

  @override
  Future<AuthState> register(String email, String password) async => const AuthState();

  static int logouts = 0;

  @override
  Future<void> logout() async => logouts++;

  @override
  Future<AuthState> refreshFromMe() async => const AuthState();
}

class _StaticPaywallNotifier extends PaywallNotifier {
  _StaticPaywallNotifier(this._state);
  final PaywallState _state;

  @override
  Future<PaywallState> build() async => _state;
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Widget _buildTestWidget({
  _FakeRevenueCatService? rcService,
  PaywallState initialPaywallState = const PaywallState(),
}) {
  final fakeRc = rcService ?? _FakeRevenueCatService();

  final router = GoRouter(
    initialLocation: '/paywall',
    routes: [
      GoRoute(path: '/paywall', builder: (_, __) => const PaywallScreen()),
      GoRoute(path: '/demo', builder: (_, __) => const Scaffold(body: Text('Démo'))),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('Accueil'))),
    ],
  );

  return ProviderScope(
    overrides: [
      revenueCatServiceProvider.overrideWithValue(fakeRc),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      paywallProvider.overrideWith(
        () => _StaticPaywallNotifier(initialPaywallState),
      ),
    ],
    child: ShadApp.router(
      theme: buildShadTheme(),
      routerConfig: router,
    ),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('PaywallScreen', () {
    testWidgets("affiche S'abonner et « Se déconnecter » (plus de « Retour à la démo » sans issue)", (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text("S'abonner"), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
      expect(find.text('Retour à la démo'), findsNothing);
    });

    testWidgets('affiche le bouton Gérer mon abonnement', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Gérer mon abonnement'), findsOneWidget);
    });

    testWidgets('affiche le prix de fallback si aucun package RevenueCat', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        initialPaywallState: const PaywallState(package: null),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('9€'), findsOneWidget);
    });

    testWidgets('masque le bouton S\'abonner et affiche un indicateur pendant isLoading', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        initialPaywallState: const PaywallState(isLoading: true),
      ));
      await tester.pump();

      expect(find.text("S'abonner"), findsNothing);
      expect(find.byType(ShadProgress), findsOneWidget);

      // Dispose de l'arbre pour libérer les timers d'animation de ShadProgress
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
    });

    testWidgets('« Se déconnecter » déconnecte (un compte sans accès n’est jamais bloqué)', (tester) async {
      _FakeAuthRepository.logouts = 0;
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(_FakeAuthRepository.logouts, 1);
    });
  });
}
