import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/notifications/notifications_service.dart';
import 'package:collega_app/core/router/app_router.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/profile/domain/reminder_sync.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.listen(authProvider, (previous, authState) {
      final wasAuth = previous?.valueOrNull?.isAuthenticated == true;
      final isAuth = authState.valueOrNull?.isAuthenticated == true;
      if (isAuth) {
        final notifications = ref.read(notificationsServiceProvider);
        notifications.requestPermissionsAndRegister();
        // Changement d'heure depuis le réglage du rappel : l'heure locale reste la bonne.
        resyncReminderOffset(
          user: authState.valueOrNull!.user!,
          notifications: notifications,
          auth: ref.read(authProvider.notifier),
          now: DateTime.now(),
        );
      } else if (wasAuth && !isAuth) {
        // P10: reset du connecteur APNs au logout pour que le prochain user puisse s'enregistrer
        ref.read(notificationsServiceProvider).reset();
      }
    });

    // Collega UI : CgTheme au-dessus des routes ; MaterialApp n'est qu'un conteneur
    // technique (localisations, Navigator), neutralisé par le thème Collega.
    return CgTheme(
      data: CgThemeData.light,
      child: MaterialApp.router(
        title: 'Collega',
        theme: buildCgMaterialTheme(CgThemeData.light).copyWith(
          cupertinoOverrideTheme: buildCgCupertinoTheme(CgThemeData.light),
        ),
        routerConfig: router,
        builder: collegaAppBuilder,
        debugShowCheckedModeBanner: false,
        // App en français uniquement : sélecteur de date iOS, libellés système.
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
      ),
    );
  }
}

/// Texte courant Collega pour tout `Text` sans style explicite : sous MaterialApp,
/// il hériterait sinon du style d'alerte (rouge, souligné jaune).
Widget collegaAppBuilder(BuildContext context, Widget? child) => DefaultTextStyle(
      style: CgType.body.copyWith(color: CgTheme.of(context).colors.ink),
      child: child ?? const SizedBox.shrink(),
    );
