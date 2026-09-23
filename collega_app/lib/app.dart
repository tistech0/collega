import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/notifications/notifications_service.dart';
import 'package:collega_app/core/router/app_router.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
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

    // Collega UI (story 8.1) : CgTheme au-dessus des routes, Material réduit à un
    // conteneur technique. Les écrans shadcn gardent leurs couleurs jusqu'à leur
    // migration (8.3 → 8.14).
    return CgTheme(
      data: CgThemeData.light,
      child: ShadApp.router(
        title: 'Collega',
        theme: buildShadTheme(),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        // App en français uniquement : sélecteur de date iOS, libellés système.
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        materialThemeBuilder: (context, theme) => neutralizeMaterial(theme).copyWith(
          cupertinoOverrideTheme: buildCgCupertinoTheme(CgThemeData.light),
        ),
      ),
    );
  }
}
