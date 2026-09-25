import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/auth/presentation/auth_login_screen.dart';
import 'package:collega_app/features/auth/presentation/welcome_screen.dart';

import '../../support/cg_golden.dart';

class _Auth extends AuthNotifier {
  static LoginError? next;
  static final calls = <(String, String)>[];

  @override
  Future<AuthState> build() async => const AuthState();

  @override
  Future<void> login(String email, String password) async {
    calls.add((email, password));
    state = AsyncData(next == null
        ? const AuthState(user: AuthUser(id: 'u', email: 'a@b.fr', isBeta: true, isSubscribed: false))
        : AuthState(loginError: next, errorMessage: 'x'));
  }
}

Widget _app(String initial, {List<String>? visited, double textScale = 1, bool reduceMotion = true}) {
  final router = GoRouter(initialLocation: initial, routes: [
    GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
    GoRoute(path: '/auth/login', builder: (_, __) => const AuthLoginScreen()),
    for (final p in ['/demo', '/home'])
      GoRoute(path: p, builder: (_, __) {
        visited?.add(p);
        return const SizedBox();
      }),
  ]);
  return ProviderScope(
    overrides: [authProvider.overrideWith(_Auth.new)],
    child: CgTheme(
      data: CgThemeData.light,
      child: WidgetsApp.router(
        debugShowCheckedModeBanner: false,
        color: CgColors.light.accent,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
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

void main() {
  setUpAll(loadCgFonts);
  setUp(() {
    _Auth.next = null;
    _Auth.calls.clear();
  });

  group('écran de marque', () {
    testWidgets('wordmark, « Se connecter » (primaire), « Essayer la démo », beta privée', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app('/welcome', visited: visited));
      await tester.pumpAndSettle();
      expect(find.byType(CgWordmark), findsOneWidget);
      expect(find.byType(CgLogo), findsOneWidget);
      expect(find.text('Beta privée · accès sur invitation'), findsOneWidget);
      final primaries = tester.widgetList<CgButton>(find.byType(CgButton)).where((b) => b.variant == CgButtonVariant.primary);
      expect(primaries.map((b) => b.label), ['Se connecter']);
      await tester.tap(find.text('Essayer la démo'));
      await tester.pumpAndSettle();
      expect(visited, ['/demo']);
    });

    testWidgets('« Se connecter » ouvre la connexion', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app('/welcome'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthLoginScreen), findsOneWidget);
    });

    testWidgets('wordmark animé à l’apparition (et rien de figé en attente)', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app('/welcome', reduceMotion: false));
      await tester.pump(const Duration(milliseconds: 50));
      final early = tester.widget<Opacity>(
        find.ancestor(of: find.byType(CgWordmark), matching: find.byType(Opacity)).first,
      );
      expect(early.opacity, lessThan(1));
      await tester.pumpAndSettle();
      final end = tester.widget<Opacity>(
        find.ancestor(of: find.byType(CgWordmark), matching: find.byType(Opacity)).first,
      );
      expect(end.opacity, 1);
    });
  });

  group('connexion', () {
    Future<void> fill(WidgetTester tester, {String email = 'lea@fac.fr', String password = 'secret'}) async {
      final fields = find.byType(EditableText);
      await tester.enterText(fields.at(0), email);
      await tester.enterText(fields.at(1), password);
    }

    testWidgets('champs étiquetés dans un groupe d’autofill, pas d’inscription', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app('/auth/login'));
      await tester.pumpAndSettle();
      expect(find.byType(AutofillGroup), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.textContaining('Créer un compte'), findsNothing);
      expect(find.text('Beta privée · accès sur invitation'), findsOneWidget);
    });

    testWidgets('logo et wordmark sur la connexion', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app('/auth/login'));
      await tester.pumpAndSettle();
      expect(find.byType(CgWordmark), findsOneWidget);
      expect(find.byType(CgLogo), findsOneWidget);
    });

    testWidgets('email mal formé : dit sous le champ, sans appel', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app('/auth/login'));
      await tester.pumpAndSettle();
      await fill(tester, email: 'lea-fac.fr');
      await tester.tap(find.widgetWithText(CgButton, 'Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('Cet email n’est pas valide.'), findsOneWidget);
      expect(_Auth.calls, isEmpty);
    });

    testWidgets('champs vides : erreurs inline, pas d’appel', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app('/auth/login'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CgButton, 'Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('Saisis ton email.'), findsOneWidget);
      expect(find.text('Saisis ton mot de passe.'), findsOneWidget);
      expect(_Auth.calls, isEmpty);
    });

    for (final (error, message) in [
      (LoginError.invalidCredentials, 'Email ou mot de passe incorrect.'),
      (LoginError.network, 'Pas de connexion pour l’instant. Réessaie quand le réseau revient.'),
      (LoginError.tooManyAttempts, 'Trop d’essais. Réessaie dans une minute.'),
      (LoginError.other, 'La connexion n’a pas abouti. Réessaie dans un instant.'),
      (LoginError.invalidEmail, 'Cet email n’est pas valide.'),
    ]) {
      testWidgets('erreur ${error.name} : « $message » à l’écran, pas en toast', (tester) async {
        _phone(tester);
        _Auth.next = error;
        await tester.pumpWidget(_app('/auth/login'));
        await tester.pumpAndSettle();
        await fill(tester);
        await tester.tap(find.widgetWithText(CgButton, 'Se connecter'));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(_Auth.calls, [('lea@fac.fr', 'secret')]);
      });
    }

    testWidgets('email nettoyé ; succès → Aujourd’hui', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app('/auth/login', visited: visited));
      await tester.pumpAndSettle();
      await fill(tester, email: '  lea@fac.fr ');
      await tester.tap(find.widgetWithText(CgButton, 'Se connecter'));
      await tester.pumpAndSettle();
      expect(_Auth.calls.single.$1, 'lea@fac.fr');
      expect(visited, ['/home']);
    });

    testWidgets('« Mot de passe oublié ? » explique la beta', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app('/auth/login'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('invitée'), findsOneWidget);
    });

    testWidgets('« Essayer la démo » depuis la connexion', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app('/auth/login', visited: visited));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Essayer la démo'));
      await tester.pumpAndSettle();
      expect(visited, ['/demo']);
    });

    testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement (avec erreur)', (tester) async {
      _phone(tester, width: 375, height: 812);
      _Auth.next = LoginError.network;
      await tester.pumpWidget(_app('/auth/login', textScale: 1.6));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.tap(find.widgetWithText(CgButton, 'Se connecter'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  test('aucun widget Material ni shadcn', () {
    for (final f in ['welcome_screen.dart', 'auth_login_screen.dart']) {
      final src = File('lib/features/auth/presentation/$f').readAsStringSync();
      expect(src, isNot(contains('material.dart')), reason: f);
      expect(src, isNot(contains('shadcn_ui')), reason: f);
    }
  });

  group('goldens', () {
    for (final (name, path, error) in [
      ('welcome', '/welcome', null),
      ('login_error', '/auth/login', LoginError.invalidCredentials),
    ]) {
      for (final width in cgGoldenWidths) {
        for (final scale in cgGoldenScales) {
          final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
          testWidgets('golden entry_${name}_$tag', tags: const ['golden'], (tester) async {
            _phone(tester, width: width, height: 900);
            _Auth.next = error;
            await tester.pumpWidget(_app(path, textScale: scale));
            await tester.pumpAndSettle();
            if (error != null) {
              final fields = find.byType(EditableText);
              await tester.enterText(fields.at(0), 'lea@fac.fr');
              await tester.enterText(fields.at(1), 'secret');
              await tester.tap(find.widgetWithText(CgButton, 'Se connecter'));
              await tester.pumpAndSettle();
              FocusManager.instance.primaryFocus?.unfocus();
              await tester.pumpAndSettle();
            }
            await expectLater(find.byType(CgGoldenFrame), matchesGoldenFile('goldens/entry_${name}_$tag.png'));
          });
        }
      }
    }
  });
}
