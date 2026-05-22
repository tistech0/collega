import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/notifications/notifications_service.dart';
import 'package:collega_app/core/router/app_router.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/profile/data/revision_prefs_repository.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/presentation/profile_screen.dart';
import 'package:collega_app/features/profile/profile_providers.dart';

final _testUser = AuthUser(
  id: 'user-1',
  email: 'test@example.com',
  isBeta: false,
  isSubscribed: true,
  firstName: 'Marie',
  yearGroup: '4e année',
  faculty: 'Paris 6',
  monthlyReloads: 2,
  monthlyMax: 3,
);

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._authState, {this.deleteError});
  final AuthState _authState;
  // Si non-null, `deleteAccount` retourne ce message → simulé chemin d'erreur
  // (Story 7.3 T10 — toast destructive + session intacte).
  final String? deleteError;

  @override
  Future<AuthState> build() async => _authState;

  @override
  Future<void> logout() async {
    state = const AsyncData(AuthState());
  }

  @override
  Future<String?> updateProfile({
    String? firstName,
    String? yearGroup,
    String? faculty,
  }) async => null;

  @override
  Future<String?> deleteAccount() async => deleteError;
}

class _FakeNotificationsService extends NotificationsService {
  _FakeNotificationsService()
      : super(
          dio: Dio(),
          router: GoRouter(routes: [
            GoRoute(path: '/', builder: (_, __) => const SizedBox()),
          ]),
        );

  @override
  Future<void> setReminder(int hourUtc) async {}

  @override
  Future<void> clearReminder() async {}

  @override
  Future<void> requestPermissionsAndRegister() async {}
}

class _FakeRevisionPrefsNotifier extends RevisionPrefsNotifier {
  @override
  Future<RevisionPrefs> build() async => const RevisionPrefs();

  @override
  Future<void> save(RevisionPrefs prefs) async {}
}

class _FakeRevisionPrefsRepository extends RevisionPrefsRepository {
  _FakeRevisionPrefsRepository() : super(storage: const FlutterSecureStorage());

  @override
  Future<RevisionPrefs> load() async => const RevisionPrefs();

  @override
  Future<void> save(RevisionPrefs prefs) async {}
}

Widget _buildScreen({AuthState? authState, String? deleteError}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _FakeAuthNotifier(
            authState ?? AuthState(user: _testUser),
            deleteError: deleteError,
          )),
      notificationsServiceProvider.overrideWith(
        (ref) => _FakeNotificationsService(),
      ),
      revisionPrefsProvider.overrideWith(_FakeRevisionPrefsNotifier.new),
      revisionPrefsRepositoryProvider.overrideWithValue(
        _FakeRevisionPrefsRepository(),
      ),
      routerProvider.overrideWithValue(GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      ])),
    ],
    child: ShadApp(
      theme: buildShadTheme(),
      home: const ProfileScreen(),
    ),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.revenuecat.purchases_flutter'),
      (call) async => null,
    );
  });

  group('ProfileScreen', () {
    testWidgets("affiche l'email de l'utilisateur", (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('affiche badge Actif si abonné', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Actif'), findsOneWidget);
    });

    testWidgets('affiche badge Inactif si non abonné', (tester) async {
      final notSubscribedUser = AuthUser(
        id: 'user-2',
        email: 'free@example.com',
        isBeta: false,
        isSubscribed: false,
      );
      await tester.pumpWidget(
        _buildScreen(authState: AuthState(user: notSubscribedUser)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inactif'), findsOneWidget);
    });

    testWidgets('affiche le toggle Rappel quotidien', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Rappel quotidien', skipOffstage: false), findsOneWidget);
    });

    testWidgets('affiche le bouton Se déconnecter', (tester) async {
      // Story 7.4 T2 : viewport élargi pour que ListView construise _AppCard
      // (les ajouts dans _RevisionPrefsCard rallongent la liste).
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Se déconnecter', skipOffstage: false), findsOneWidget);
    });

    testWidgets('_IdentityCard affiche le prénom', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Marie'), findsOneWidget);
    });

    testWidgets('_IdentityCard passe en mode édition sur tap du bouton Modifier',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('_SubscriptionCard affiche la barre de quota', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('_RevisionPrefsCard affiche les chips A/B/C', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('_AppCard affiche les liens CGU et politique', (tester) async {
      // Story 7.4 T2 : viewport élargi (cf. test "Se déconnecter").
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.text("Conditions générales d'utilisation", skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Politique de confidentialité', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('affiche le bouton Supprimer mon compte', (tester) async {
      // Story 7.4 T2 : viewport élargi (cf. test "Se déconnecter").
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('Supprimer mon compte', skipOffstage: false), findsOneWidget);
    });

    testWidgets('dialog de confirmation au tap sur Supprimer mon compte', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      final btn = find.text('Supprimer mon compte', skipOffstage: false);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.text('Supprimer mon compte ?'), findsOneWidget);
      expect(find.textContaining('Cette action est irréversible', skipOffstage: false), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Supprimer définitivement'), findsOneWidget);
    });

    testWidgets('Annuler ferme le dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      final btn = find.text('Supprimer mon compte', skipOffstage: false);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer mon compte ?'), findsNothing);
    });

    testWidgets(
        'chemin erreur DELETE → toast destructive, session intacte (Story 7.3 T10)',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_buildScreen(deleteError: 'Erreur réseau'));
      await tester.pumpAndSettle();
      final btn = find.text('Supprimer mon compte', skipOffstage: false);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();

      // Toast destructive affiché
      expect(find.text('Erreur'), findsOneWidget);
      expect(find.text('Erreur réseau'), findsOneWidget);
      // Toast succès NON affiché — session intacte
      expect(find.text('Ton compte a été supprimé'), findsNothing);
    });

    testWidgets('affiche message abonnement si isSubscribed', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_buildScreen(authState: AuthState(user: _testUser)));
      await tester.pumpAndSettle();
      final btn = find.text('Supprimer mon compte', skipOffstage: false);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.textContaining('Réglages iOS', skipOffstage: false), findsOneWidget);
    });
  });
}
