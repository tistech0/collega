import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/notifications/notifications_service.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/data/revenuecat_service.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/auth/paywall_providers.dart';
import 'package:collega_app/features/profile/domain/reminder_time.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/presentation/profile_screen.dart';
import 'package:collega_app/features/profile/profile_providers.dart';

import '../../support/cg_golden.dart';

const _beta = AuthUser(
  id: 'u1',
  email: 'lea@fac.fr',
  isBeta: true,
  isSubscribed: false,
  firstName: 'Léa',
  yearGroup: 'DFASM2',
  faculty: 'Lyon Est',
);

class _Auth extends AuthNotifier {
  static AuthUser user = _beta;
  static String? updateError;
  static String? deleteError;
  static int refreshes = 0;
  static int logouts = 0;
  static int deletes = 0;
  static final updates = <(String?, String?, String?)>[];

  @override
  Future<AuthState> build() async => AuthState(user: user);

  @override
  Future<void> refreshProfile() async => refreshes++;

  @override
  Future<void> logout() async {
    logouts++;
    state = const AsyncData(AuthState());
  }

  @override
  Future<String?> updateProfile({String? firstName, String? yearGroup, String? faculty}) async {
    updates.add((firstName, yearGroup, faculty));
    if (updateError != null) return updateError;
    state = AsyncData(AuthState(user: user.copyWith(firstName: firstName, yearGroup: yearGroup, faculty: faculty)));
    return null;
  }

  static final reminders = <(int?, int?)>[];

  @override
  Future<void> setReminderHour(int? hourUtc, {int? localHour}) async {
    reminders.add((hourUtc, localHour));
    final current = state.valueOrNull!.user!;
    state = AsyncData(AuthState(user: current.copyWith(reminderHourUtc: hourUtc, reminderLocalHour: localHour)));
  }

  @override
  Future<String?> deleteAccount() async {
    deletes++;
    return deleteError;
  }
}

class _Notifications extends NotificationsService {
  _Notifications() : super(dio: Dio(), router: GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => const SizedBox())]));

  static final calls = <String>[];
  static bool fail = false;
  static bool granted = true;

  @override
  Future<bool> requestPermissionsAndRegister() async {
    calls.add('permission');
    return granted;
  }

  @override
  Future<void> setReminder(int hourUtc) async {
    calls.add('set:$hourUtc');
    if (fail) throw DioException(requestOptions: RequestOptions());
  }

  @override
  Future<void> clearReminder() async => calls.add('clear');
}

class _Prefs extends RevisionPrefsNotifier {
  static RevisionPrefs initial = const RevisionPrefs();
  static final saved = <RevisionPrefs>[];

  @override
  Future<RevisionPrefs> build() async => initial;

  @override
  Future<void> save(RevisionPrefs prefs) async {
    saved.add(prefs);
    state = AsyncData(prefs);
  }
}

class _RevenueCat extends RevenueCatService {
  static int manage = 0;
  static RevenueCatSubscriptionInfo? info;

  @override
  Future<void> openSubscriptionManagement() async => manage++;

  @override
  Future<RevenueCatSubscriptionInfo?> getSubscriptionInfo() async => info;
}

Widget _app({List<String>? visited, double textScale = 1}) {
  final router = GoRouter(initialLocation: '/profile', routes: [
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    for (final p in ['/legal/cgu', '/legal/privacy', '/welcome'])
      GoRoute(path: p, builder: (_, __) {
        visited?.add(p);
        return const SizedBox();
      }),
  ]);
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(_Auth.new),
      notificationsServiceProvider.overrideWith((_) => _Notifications()),
      revisionPrefsProvider.overrideWith(_Prefs.new),
      revenueCatServiceProvider.overrideWithValue(_RevenueCat()),
    ],
    child: CgTheme(
      data: CgThemeData.light,
      child: WidgetsApp.router(
        debugShowCheckedModeBanner: false,
        color: CgColors.light.accent,
        routerConfig: router,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: true),
          child: CgGoldenFrame(child: child!),
        ),
      ),
    ),
  );
}

void _phone(WidgetTester tester, {double width = 393, double height = 2400}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester, {List<String>? visited, double textScale = 1}) async {
  await tester.pumpWidget(_app(visited: visited, textScale: textScale));
  await tester.pumpAndSettle();
}

Finder _row(String title) => find.ancestor(of: find.text(title), matching: find.byType(CgListRow));

void main() {
  setUpAll(loadCgFonts);
  setUp(() {
    _Auth.user = _beta;
    _Auth.updateError = null;
    _Auth.deleteError = null;
    _Auth.refreshes = 0;
    _Auth.logouts = 0;
    _Auth.deletes = 0;
    _Auth.updates.clear();
    _Notifications.calls.clear();
    _Notifications.fail = false;
    _Notifications.granted = true;
    _Auth.reminders.clear();
    _Prefs.initial = const RevisionPrefs();
    _Prefs.saved.clear();
    _RevenueCat.manage = 0;
    _RevenueCat.info = null;
  });

  group('compte', () {
    testWidgets('prénom, détails et email ; données relues à l’ouverture', (tester) async {
      _phone(tester);
      await _open(tester);
      expect(find.text('Profil'), findsWidgets);
      expect(find.text('Léa'), findsOneWidget);
      expect(find.text('DFASM2 · Lyon Est · lea@fac.fr'), findsOneWidget);
      expect(_Auth.refreshes, 1);
    });

    testWidgets('sans prénom : une invitation, jamais « — »', (tester) async {
      _phone(tester);
      _Auth.user = const AuthUser(id: 'u', email: 'lea@fac.fr', isBeta: true, isSubscribed: false);
      await _open(tester);
      expect(find.text('Ajoute ton prénom'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('modifier : prénom requis dit sous le champ, puis enregistré', (tester) async {
      _phone(tester);
      await _open(tester);
      await tester.tap(find.text('Léa'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier le profil'), findsOneWidget);
      final fields = find.descendant(of: find.byType(CgSheetPanel), matching: find.byType(EditableText));
      await tester.enterText(fields.at(0), '  ');
      await tester.tap(find.widgetWithText(CgButton, 'Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Saisis ton prénom.'), findsOneWidget);
      expect(_Auth.updates, isEmpty);

      await tester.enterText(fields.at(0), ' Léna ');
      await tester.tap(find.widgetWithText(CgButton, 'Enregistrer'));
      await tester.pumpAndSettle();
      expect(_Auth.updates, [('Léna', 'DFASM2', 'Lyon Est')]);
      expect(find.text('Modifier le profil'), findsNothing);
      expect(find.text('Léna'), findsOneWidget);
    });

    testWidgets('modifier : échec dit dans la sheet, qui reste ouverte', (tester) async {
      _phone(tester);
      _Auth.updateError = 'boom';
      await _open(tester);
      await tester.tap(find.text('Léa'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CgButton, 'Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Ton profil n’a pas pu être enregistré. Réessaie dans un instant.'), findsOneWidget);
      expect(find.text('boom'), findsNothing);
      expect(find.text('Modifier le profil'), findsOneWidget);
    });
  });

  group('accès et quota', () {
    testWidgets('beta : accès expliqué, badge, pas de « Gérer mon abonnement »', (tester) async {
      _phone(tester);
      await _open(tester);
      expect(find.text('Beta privée'), findsOneWidget);
      expect(find.text('Accès offert pendant la beta privée'), findsOneWidget);
      expect(find.descendant(of: _row('Beta privée'), matching: find.byType(CgBadge)), findsOneWidget);
      expect(find.text('Gérer mon abonnement'), findsNothing);
    });

    testWidgets('abonné : Collega Premium, renouvellement daté, « Gérer mon abonnement »', (tester) async {
      _phone(tester);
      _Auth.user = _beta.copyWith(isBeta: false, isSubscribed: true);
      _RevenueCat.info = RevenueCatSubscriptionInfo(expirationDate: DateTime(2026, 10, 12), willRenew: true);
      await _open(tester);
      expect(find.text('Collega Premium'), findsOneWidget);
      expect(find.text('Se renouvelle le 12 octobre'), findsOneWidget);
      await tester.tap(find.text('Gérer mon abonnement'));
      await tester.pumpAndSettle();
      expect(_RevenueCat.manage, 1);
    });

    testWidgets('abonné résilié : accès jusqu’à la date', (tester) async {
      _phone(tester);
      _Auth.user = _beta.copyWith(isBeta: false, isSubscribed: true);
      _RevenueCat.info = RevenueCatSubscriptionInfo(expirationDate: DateTime(2026, 10, 12), willRenew: false);
      await _open(tester);
      expect(find.text('Résilié · accès jusqu’au 12 octobre'), findsOneWidget);
    });

    testWidgets('réimports : « 0 sur 3 », barre vide, renouvellement daté', (tester) async {
      _phone(tester);
      _Auth.user = _beta.copyWith(monthlyReloads: 0, monthlyMax: 3, monthlyResetAt: DateTime(2026, 10, 1, 12));
      await _open(tester);
      expect(find.text('Réimports ce mois'), findsOneWidget);
      expect(find.text('0 sur 3'), findsOneWidget);
      expect(find.text('Se renouvelle le 1er octobre'), findsOneWidget);
      expect(tester.widget<ProfileQuotaBar>(find.byType(ProfileQuotaBar)).fraction, 0);
      expect(find.textContaining('reimport'), findsNothing);
    });

    testWidgets('réimports épuisés : barre pleine', (tester) async {
      _phone(tester);
      _Auth.user = _beta.copyWith(monthlyReloads: 3, monthlyMax: 3);
      await _open(tester);
      expect(find.text('3 sur 3'), findsOneWidget);
      expect(tester.widget<ProfileQuotaBar>(find.byType(ProfileQuotaBar)).fraction, 1);
    });
  });

  group('révision', () {
    testWidgets('rangs : tous cochés par défaut (lisible sans la couleur), décocher enregistre', (tester) async {
      _phone(tester);
      final handle = tester.ensureSemantics();
      await _open(tester);
      for (final r in ['A', 'B', 'C']) {
        expect(tester.getSemantics(_row('Rang $r')), matchesSemantics(
          label: 'Rang $r', isSelected: true, isButton: true, hasTapAction: true,
          hasEnabledState: true, isEnabled: true,
        ));
      }
      await tester.tap(find.text('Rang A'));
      await tester.pumpAndSettle();
      expect(_Prefs.saved.last.defaultRangs, ['B', 'C']);
      handle.dispose();
    });

    testWidgets('rangs : au moins un ; tout recocher = « tous »', (tester) async {
      _phone(tester);
      _Prefs.initial = const RevisionPrefs(defaultRangs: ['A']);
      await _open(tester);
      await tester.tap(find.text('Rang A'));
      await tester.pumpAndSettle();
      expect(find.text('Garde au moins un rang.'), findsOneWidget);
      expect(_Prefs.saved, isEmpty);

      await tester.tap(find.text('Rang B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rang C'));
      await tester.pumpAndSettle();
      expect(_Prefs.saved.last.defaultRangs, isNull);
    });

    testWidgets('fiches par session : choix dans une sheet', (tester) async {
      _phone(tester);
      await _open(tester);
      expect(find.text('Toutes'), findsOneWidget);
      await tester.tap(find.text('Fiches par session'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(CgSheetPanel), matching: find.text('20')));
      await tester.pumpAndSettle();
      expect(_Prefs.saved.last.defaultMaxCards, 20);
      expect(find.byType(CgSheetPanel), findsNothing);
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('fiches par session : une valeur hors liste reste proposée', (tester) async {
      _phone(tester);
      _Prefs.initial = const RevisionPrefs(defaultMaxCards: 7);
      await _open(tester);
      await tester.tap(find.text('Fiches par session'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(CgSheetPanel), matching: find.text('7')), findsOneWidget);
    });

    testWidgets('chronomètre : trois choix, « Demander » enregistré, durée si actif', (tester) async {
      _phone(tester);
      await _open(tester);
      expect(find.text('Durée par carte'), findsNothing);
      await tester.tap(find.text('Demander'));
      await tester.pumpAndSettle();
      expect(_Prefs.saved.last.timerMode, TimerMode.ask);
      expect(find.text('Durée par carte'), findsOneWidget);
      await tester.tap(find.text('1 min'));
      await tester.pumpAndSettle();
      expect(_Prefs.saved.last.timerDurationSeconds, 60);
    });
  });

  group('rappel', () {
    testWidgets('état venu du serveur : allumé, heure locale affichée', (tester) async {
      _phone(tester);
      final today = DateTime.now();
      _Auth.user = _beta.copyWith(reminderHourUtc: reminderUtcHour(19, today));
      await _open(tester);
      expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, isTrue);
      expect(find.text('19:00'), findsOneWidget);
    });

    testWidgets('allumer : heure choisie à la roue, envoyée en UTC, mémorisée', (tester) async {
      _phone(tester);
      await _open(tester);
      expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, isFalse);
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(find.text('Heure du rappel'), findsOneWidget);
      await tester.tap(find.widgetWithText(CgButton, 'Valider'));
      await tester.pumpAndSettle();
      final utc = reminderUtcHour(8, DateTime.now());
      expect(_Notifications.calls, ['permission', 'set:$utc']);
      expect(_Auth.reminders, [(utc, 8)]);
      expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, isTrue);
      expect(find.text('08:00'), findsOneWidget);
    });

    testWidgets('notifications refusées : rien n’est réglé, on dit où les autoriser', (tester) async {
      _phone(tester);
      _Notifications.granted = false;
      await _open(tester);
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CgButton, 'Valider'));
      await tester.pumpAndSettle();
      expect(_Notifications.calls, ['permission']);
      expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, isFalse);
      expect(find.text('Autorise les notifications de Collega dans Réglages pour recevoir ton rappel.'), findsOneWidget);
    });

    testWidgets('heure locale choisie affichée (même après un changement d’heure)', (tester) async {
      _phone(tester);
      _Auth.user = _beta.copyWith(reminderHourUtc: 3, reminderLocalHour: 8);
      await _open(tester);
      expect(find.text('08:00'), findsOneWidget);
    });

    testWidgets('changer l’heure en échec : « modifié », l’ancien rappel reste', (tester) async {
      _phone(tester);
      _Notifications.fail = true;
      _Auth.user = _beta.copyWith(reminderHourUtc: 6, reminderLocalHour: 8);
      await _open(tester);
      await tester.tap(find.text('Heure'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CgButton, 'Valider'));
      await tester.pumpAndSettle();
      expect(find.text('Le rappel n’a pas pu être modifié. Réessaie dans un instant.'), findsOneWidget);
      expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, isTrue);
      expect(find.text('08:00'), findsOneWidget);
    });

    testWidgets('allumer puis renoncer (sheet fermée) : rien n’est envoyé', (tester) async {
      _phone(tester);
      await _open(tester);
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(_Notifications.calls, isEmpty);
      expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, isFalse);
    });

    testWidgets('échec : l’interrupteur reste éteint et on le dit', (tester) async {
      _phone(tester);
      _Notifications.fail = true;
      await _open(tester);
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CgButton, 'Valider'));
      await tester.pumpAndSettle();
      expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, isFalse);
      expect(find.text('Le rappel n’a pas pu être activé. Réessaie dans un instant.'), findsOneWidget);
    });

    testWidgets('éteindre : rappel supprimé côté serveur', (tester) async {
      _phone(tester);
      _Auth.user = _beta.copyWith(reminderHourUtc: 6);
      await _open(tester);
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(_Notifications.calls, ['clear']);
      expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, isFalse);
      expect(find.text('Heure'), findsNothing);
    });
  });

  group('application et compte', () {
    testWidgets('CGU et Confidentialité s’ouvrent', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await _open(tester, visited: visited);
      await tester.tap(find.text('Conditions générales d’utilisation'));
      await tester.pumpAndSettle();
      expect(visited, ['/legal/cgu']);
    });

    testWidgets('« Se déconnecter » neutre (secondaire), jamais rouge', (tester) async {
      _phone(tester);
      await _open(tester);
      final button = tester.widget<CgButton>(find.widgetWithText(CgButton, 'Se déconnecter'));
      expect(button.variant, CgButtonVariant.secondary);
      expect(
        tester.widgetList<CgButton>(find.byType(CgButton)).where((b) => b.variant == CgButtonVariant.destructive),
        isEmpty,
      );
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(_Auth.logouts, 1);
    });

    testWidgets('« Supprimer mon compte » : action sheet avec la conséquence, puis suppression', (tester) async {
      _phone(tester);
      await _open(tester);
      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.textContaining('Tes collèges, tes fiches et ta progression seront effacés'), findsOneWidget);
      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();
      expect(_Auth.deletes, 1);
    });

    testWidgets('abonné : l’action sheet rappelle d’annuler l’abonnement dans Réglages', (tester) async {
      _phone(tester);
      _Auth.user = _beta.copyWith(isSubscribed: true);
      await _open(tester);
      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Réglages'), findsOneWidget);
    });

    testWidgets('suppression en échec : dit honnêtement, session gardée', (tester) async {
      _phone(tester);
      _Auth.deleteError = 'Internal Server Error';
      await _open(tester);
      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();
      expect(find.text('La suppression n’a pas abouti. Ton compte est intact, réessaie dans un instant.'), findsOneWidget);
      expect(find.text('Internal Server Error'), findsNothing);
      expect(find.text('Léa'), findsOneWidget);
    });
  });

  testWidgets('accessibilité : cibles étiquetées, 44 pt, contraste du texte (8.15)', (tester) async {
    _phone(tester, height: 900);
    final handle = tester.ensureSemantics();
    _Auth.user = _beta.copyWith(reminderHourUtc: 6, monthlyResetAt: DateTime(2026, 10, 1, 12));
    await _open(tester);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement', (tester) async {
    _phone(tester, width: 375, height: 4000);
    _Auth.user = _beta.copyWith(reminderHourUtc: 6);
    _Prefs.initial = const RevisionPrefs(timerMode: TimerMode.on);
    await _open(tester, textScale: 1.6);
    expect(tester.takeException(), isNull);
  });

  test('aucun widget Material ni shadcn', () {
    final src = File('lib/features/profile/presentation/profile_screen.dart').readAsStringSync();
    expect(src, isNot(contains('material.dart')));
    expect(src, isNot(contains('shadcn_ui')));
  });

  group('goldens', () {
    for (final width in cgGoldenWidths) {
      for (final scale in cgGoldenScales) {
        final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
        testWidgets('golden profile_beta_$tag', (tester) async {
          _phone(tester, width: width, height: 900);
          _Auth.user = _beta.copyWith(monthlyReloads: 1, monthlyResetAt: DateTime(2026, 10, 1, 12));
          await _open(tester, textScale: scale);
          await expectLater(find.byType(CgGoldenFrame), matchesGoldenFile('goldens/profile_beta_$tag.png'));
        });
      }
    }
  });
}
