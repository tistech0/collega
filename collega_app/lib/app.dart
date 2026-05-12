import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/notifications/notifications_service.dart';
import 'package:collega_app/core/router/app_router.dart';
import 'package:collega_app/core/theme/app_theme.dart';
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

    return ShadApp.router(
      title: 'AppMédecine',
      theme: buildShadTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
