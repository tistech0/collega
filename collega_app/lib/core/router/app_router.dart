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
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/drill/presentation/drill_screen.dart';
import 'package:collega_app/features/legal/presentation/legal_screen.dart';
import 'package:collega_app/features/planning/presentation/planning_screen.dart';
import 'package:collega_app/features/search/presentation/search_sheet.dart';
import 'package:collega_app/features/profile/presentation/profile_screen.dart';
import 'package:collega_app/features/progress/progress_screen.dart';
import 'package:collega_app/features/shell/app_shell.dart';
import 'package:collega_app/features/today/presentation/today_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/demo',
    redirect: (context, state) {
      if (authAsync.isLoading) return null;

      final isAuth = authAsync.valueOrNull?.isAuthenticated ?? false;
      final hasAccess = authAsync.valueOrNull?.hasAccess ?? false;

      // R3 (Story 7.1) : un user authentifié ne doit jamais voir l'écran démo
      final isDemoRoute = state.matchedLocation == '/demo' ||
          state.matchedLocation.startsWith('/demo/');
      if (isAuth && isDemoRoute) {
        return hasAccess ? '/home' : '/paywall';
      }

      if (state.fullPath == null || state.fullPath == '/') {
        return isAuth ? (hasAccess ? '/home' : '/paywall') : '/demo';
      }

      final isProtected = state.matchedLocation.startsWith('/home') ||
          state.matchedLocation.startsWith('/colleges') ||
          state.matchedLocation.startsWith('/progress') ||
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
      // Ancienne adresse du planning (story 8.9 : sous Progression).
      GoRoute(path: '/planning/config', redirect: (ctx, s) => '/progress/planning'),
      GoRoute(path: '/demo', builder: (ctx, s) => const DemoScreen()),
      GoRoute(path: '/demo/drill', builder: (ctx, s) => const DemoDrillScreen()),
      GoRoute(
        path: '/drill',
        builder: (ctx, s) {
          final extra = s.extra;
          final launch = extra is DrillLaunch
              ? extra
              : extra is DrillSessionParams
                  ? DrillLaunch(params: extra)
                  : null;
          // Lien sans paramètres (deep link invalide) : retour à Aujourd'hui.
          if (launch == null) return const TodayScreen();
          return DrillScreen(launch: launch);
        },
      ),
      GoRoute(path: '/auth/register', builder: (ctx, s) => const AuthRegisterScreen()),
      GoRoute(path: '/auth/login', builder: (ctx, s) => const AuthLoginScreen()),
      GoRoute(path: '/paywall', builder: (ctx, s) => const PaywallScreen()),
      // Story 7.4 AC #9 — documents légaux bundlés (option B).
      GoRoute(
        path: '/legal/cgu',
        builder: (ctx, s) => const LegalScreen(document: LegalDocument.cgu),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (ctx, s) =>
            const LegalScreen(document: LegalDocument.privacy),
      ),
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
      // Recherche : sheet depuis Aujourd'hui / Bibliothèque (story 8.10) ; ancien lien.
      GoRoute(path: '/search', redirect: (ctx, s) => '/home'),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (ctx, s) => const TodayScreen()),
          GoRoute(path: '/progress', builder: (ctx, s) => const ProgressScreen()),
          GoRoute(path: '/colleges', builder: (ctx, s) => const CollegesScreen()),
          // Détail collège et item : sous l'onglet d'où ils sont ouverts
          // (Bibliothèque, Aujourd'hui, Progression) — onglet actif et retour suivent.
          for (final origin in CollegeDetailOrigin.values) ...[
            GoRoute(
              path: '${origin.base}/:ref_id',
              builder: (ctx, s) => CollegeDetailScreen(
                refId: int.parse(s.pathParameters['ref_id']!),
                origin: origin,
              ),
            ),
            GoRoute(
              path: '${origin.base}/:ref_id/items/:item_id',
              builder: (ctx, s) => ItemDetailScreen(
                refId: int.parse(s.pathParameters['ref_id']!),
                itemId: s.pathParameters['item_id']!,
                origin: origin,
                fromSearch: s.extra == kFromSearch,
              ),
            ),
          ],
          GoRoute(path: '/progress/planning', builder: (ctx, s) => const PlanningScreen()),
          GoRoute(path: '/profile', builder: (ctx, s) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
