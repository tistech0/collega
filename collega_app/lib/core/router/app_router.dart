import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/features/demo/presentation/demo_screen.dart';
import 'package:collega_app/features/demo/presentation/demo_drill_screen.dart';
import 'package:collega_app/shared/widgets/bottom_nav_bar.dart';

final appRouter = GoRouter(
  initialLocation: '/demo',
  redirect: (context, state) {
    if (state.fullPath == null || state.fullPath == '/') return '/demo';
    return null;
  },
  routes: [
    GoRoute(path: '/demo', builder: (ctx, s) => const DemoScreen()),
    GoRoute(path: '/demo/drill', builder: (ctx, s) => const DemoDrillScreen()),
    GoRoute(path: '/auth/register', builder: (ctx, s) => const _AuthRegisterStub()),
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (ctx, s) => const _HomeStub(),
        ),
        GoRoute(
          path: '/colleges',
          builder: (ctx, s) => const _CollegesStub(),
        ),
        GoRoute(
          path: '/search',
          builder: (ctx, s) => const _SearchStub(),
        ),
        GoRoute(
          path: '/profile',
          builder: (ctx, s) => const _ProfileStub(),
        ),
      ],
    ),
  ],
);

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});
  final Widget child;

  int _tabIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/colleges')) return 1;
    if (path.startsWith('/search')) return 2;
    if (path.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _tabIndex(context),
        onTap: (i) {
          const paths = ['/home', '/colleges', '/search', '/profile'];
          context.go(paths[i]);
        },
      ),
    );
  }
}

class _AuthRegisterStub extends StatelessWidget {
  const _AuthRegisterStub();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Inscription'),
            ShadButton.ghost(
              onPressed: () => context.go('/demo'),
              child: const Text('Retour à la démo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeStub extends StatelessWidget {
  const _HomeStub();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Accueil'));
  }
}

class _CollegesStub extends StatelessWidget {
  const _CollegesStub();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Collèges'));
  }
}

class _SearchStub extends StatelessWidget {
  const _SearchStub();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Recherche'));
  }
}

class _ProfileStub extends StatelessWidget {
  const _ProfileStub();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Profil'));
  }
}
