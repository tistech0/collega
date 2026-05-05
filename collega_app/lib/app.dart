import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/router/app_router.dart';
import 'package:collega_app/core/theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return ShadApp.router(
      title: 'AppMédecine',
      theme: buildShadTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
