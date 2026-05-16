import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/notifications/notifications_service.dart';
import 'package:collega_app/core/router/app_router.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/profile/presentation/profile_screen.dart';

const _testUser = AuthUser(
  id: 'user-1',
  email: 'test@example.com',
  isBeta: false,
  isSubscribed: true,
);

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._authState);
  final AuthState _authState;

  @override
  Future<AuthState> build() async => _authState;

  @override
  Future<void> logout() async {
    state = const AsyncData(AuthState());
  }
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

Widget _buildScreen({AuthState? authState}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _FakeAuthNotifier(
            authState ?? const AuthState(user: _testUser),
          )),
      notificationsServiceProvider.overrideWith(
        (ref) => _FakeNotificationsService(),
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
      const notSubscribedUser = AuthUser(
        id: 'user-2',
        email: 'free@example.com',
        isBeta: false,
        isSubscribed: false,
      );
      await tester.pumpWidget(
        _buildScreen(authState: const AuthState(user: notSubscribedUser)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inactif'), findsOneWidget);
    });

    testWidgets('affiche le toggle Rappel quotidien', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Rappel quotidien'), findsOneWidget);
    });

    testWidgets('affiche le bouton Se déconnecter', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Se déconnecter'), findsOneWidget);
    });
  });
}
