import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/notifications/notifications_service.dart';
import 'package:collega_app/core/router/app_router.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/features/auth/auth_providers.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.listen(authProvider, (previous, authState) {
      final wasAuth = previous?.valueOrNull?.isAuthenticated == true;
      final isAuth = authState.valueOrNull?.isAuthenticated == true;
      if (isAuth) {
        ref.read(notificationsServiceProvider).requestPermissionsAndRegister();
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
        materialThemeBuilder: (context, theme) => neutralizeMaterial(theme).copyWith(
          cupertinoOverrideTheme: buildCgCupertinoTheme(CgThemeData.light),
        ),
      ),
    );
  }
}
