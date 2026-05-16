import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/presentation/auth_login_screen.dart';
import 'package:collega_app/features/auth/presentation/auth_register_screen.dart';
import 'package:collega_app/features/auth/presentation/paywall_screen.dart';
import 'package:collega_app/features/colleges/presentation/college_detail_screen.dart';
import 'package:collega_app/features/colleges/presentation/college_import_screen.dart';
import 'package:collega_app/features/colleges/presentation/colleges_screen.dart';
import 'package:collega_app/features/colleges/presentation/import_progress_screen.dart';
import 'package:collega_app/features/colleges/presentation/item_detail_screen.dart';
import 'package:collega_app/features/demo/presentation/demo_drill_screen.dart';
import 'package:collega_app/features/demo/presentation/demo_screen.dart';
import 'package:collega_app/features/home/presentation/home_screen.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/presentation/drill_screen.dart';
import 'package:collega_app/features/planning/presentation/planning_config_screen.dart';
import 'package:collega_app/features/profile/presentation/profile_screen.dart';
import 'package:collega_app/shared/widgets/bottom_nav_bar.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/demo',
    redirect: (context, state) {
      if (authAsync.isLoading) return null;

      final isAuth = authAsync.valueOrNull?.isAuthenticated ?? false;
      final hasAccess = authAsync.valueOrNull?.hasAccess ?? false;

      if (state.fullPath == null || state.fullPath == '/') return '/demo';

      final isProtected = state.matchedLocation.startsWith('/home') ||
          state.matchedLocation.startsWith('/colleges') ||
          state.matchedLocation.startsWith('/search') ||
          state.matchedLocation.startsWith('/profile') ||
          state.matchedLocation.startsWith('/drill') ||
          state.matchedLocation.startsWith('/planning');

      if (!isAuth && (isProtected || state.matchedLocation == '/paywall')) return '/demo';

      if (isAuth && !hasAccess && isProtected) return '/paywall';

      if (isAuth && hasAccess && state.matchedLocation == '/paywall') return '/home';

      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      if (isAuth && isAuthRoute) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/planning/config',
        builder: (ctx, s) => const PlanningConfigScreen(),
      ),
      GoRoute(path: '/demo', builder: (ctx, s) => const DemoScreen()),
      GoRoute(path: '/demo/drill', builder: (ctx, s) => const DemoDrillScreen()),
      GoRoute(
        path: '/drill',
        builder: (ctx, s) {
          final extra = s.extra;
          if (extra is! DrillSessionParams) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Paramètres manquants')),
            );
          }
          return DrillScreen(params: extra);
        },
      ),
      GoRoute(path: '/auth/register', builder: (ctx, s) => const AuthRegisterScreen()),
      GoRoute(path: '/auth/login', builder: (ctx, s) => const AuthLoginScreen()),
      GoRoute(path: '/paywall', builder: (ctx, s) => const PaywallScreen()),
      GoRoute(
        path: '/colleges/:ref_id/import',
        builder: (ctx, s) => CollegeImportScreen(
          refId: int.parse(s.pathParameters['ref_id']!),
        ),
      ),
      GoRoute(
        path: '/colleges/:ref_id/import/progress',
        builder: (ctx, s) {
          final extra = s.extra as Map<String, dynamic>?;
          if (extra == null) {
            return const Scaffold(body: Center(child: Text('Navigation invalide')));
          }
          return ImportProgressScreen(
            collegeId: extra['collegeId'] as String,
            refId: extra['refId'] as int,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (ctx, s) => const HomeScreen()),
          GoRoute(path: '/colleges', builder: (ctx, s) => const CollegesScreen()),
          GoRoute(
            path: '/colleges/:ref_id',
            builder: (ctx, s) => CollegeDetailScreen(
              refId: int.parse(s.pathParameters['ref_id']!),
            ),
          ),
          GoRoute(
            path: '/colleges/:ref_id/items/:item_id',
            builder: (ctx, s) => ItemDetailScreen(
              refId: int.parse(s.pathParameters['ref_id']!),
              itemId: s.pathParameters['item_id']!,
            ),
          ),
          GoRoute(path: '/search', builder: (ctx, s) => const _SearchStub()),
          GoRoute(path: '/profile', builder: (ctx, s) => const ProfileScreen()),
        ],
      ),
    ],
  );
});

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

class _SearchStub extends StatelessWidget {
  const _SearchStub();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Recherche'));
  }
}

