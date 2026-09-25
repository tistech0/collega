import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/brand/cg_logo.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/presentation/auth_login_screen.dart';
import 'package:collega_app/features/auth/presentation/welcome_screen.dart';
import 'package:collega_app/features/auth/presentation/paywall_screen.dart';
import 'package:collega_app/features/colleges/presentation/college_detail_screen.dart';
import 'package:collega_app/features/colleges/presentation/college_import_screen.dart';
import 'package:collega_app/features/colleges/presentation/colleges_screen.dart';
import 'package:collega_app/features/colleges/presentation/import_progress_screen.dart';
import 'package:collega_app/features/colleges/presentation/item_detail_screen.dart';
import 'package:collega_app/features/demo/presentation/demo_screen.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/drill/presentation/drill_screen.dart';
import 'package:collega_app/features/legal/presentation/legal_screen.dart';
import 'package:collega_app/features/planning/presentation/planning_screen.dart';
import 'package:collega_app/features/search/presentation/search_sheet.dart';
import 'package:collega_app/features/profile/presentation/profile_screen.dart';
import 'package:collega_app/features/progress/progress_screen.dart';
import 'package:collega_app/features/colleges/presentation/pending_upload_resumer.dart';
import 'package:collega_app/features/shell/app_shell.dart';
import 'package:collega_app/features/today/presentation/today_screen.dart';

/// Un seul routeur pour toute la vie de l'app (revue 8.12) : un changement de
/// connexion réévalue les redirections (`refreshListenable`) au lieu de recréer
/// le routeur — qui repartait de l'écran de marque et perdait l'écran courant
/// (erreur de connexion jamais affichée, Profil renvoyé sur Aujourd'hui).
final routerProvider = Provider<GoRouter>((ref) {
  final authChanges = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => authChanges.value++);
  ref.onDispose(authChanges.dispose);

  final router = GoRouter(
    // Écran neutre le temps de relire la session (jamais l'écran de marque
    // pour un compte connecté).
    initialLocation: '/splash',
    refreshListenable: authChanges,
    redirect: (context, state) {
      final authAsync = ref.read(authProvider);
      // Premier chargement seulement : pendant une connexion, la valeur
      // précédente reste lue (l'écran de connexion ne bouge pas).
      if (!authAsync.hasValue) return null;

      final isAuth = authAsync.valueOrNull?.isAuthenticated ?? false;
      final hasAccess = authAsync.valueOrNull?.hasAccess ?? false;

      if (state.matchedLocation == '/splash') {
        return isAuth ? (hasAccess ? '/home' : '/paywall') : '/welcome';
      }

      // R3 (Story 7.1) : un user authentifié ne voit jamais la démo ni l'écran de marque.
      final isDemoRoute = state.matchedLocation == '/demo' ||
          state.matchedLocation.startsWith('/demo/') ||
          state.matchedLocation == '/welcome';
      if (isAuth && isDemoRoute) {
        return hasAccess ? '/home' : '/paywall';
      }

      if (state.fullPath == null || state.fullPath == '/') {
        return isAuth ? (hasAccess ? '/home' : '/paywall') : '/welcome';
      }

      final isProtected = state.matchedLocation.startsWith('/home') ||
          state.matchedLocation.startsWith('/colleges') ||
          state.matchedLocation.startsWith('/progress') ||
          state.matchedLocation.startsWith('/profile') ||
          state.matchedLocation.startsWith('/drill') ||
          state.matchedLocation.startsWith('/planning');

      if (!isAuth && (isProtected || state.matchedLocation == '/paywall')) return '/welcome';

      if (isAuth && !hasAccess && isProtected) return '/paywall';

      if (isAuth && hasAccess && state.matchedLocation == '/paywall') return '/home';

      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      if (isAuth && isAuthRoute) return '/home';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', pageBuilder: (ctx, s) => _instant(s, const _Splash())),
      // Ancienne adresse du planning (story 8.9 : sous Progression).
      GoRoute(path: '/planning/config', redirect: (ctx, s) => '/progress/planning'),
      GoRoute(path: '/welcome', pageBuilder: (ctx, s) => _instant(s, const WelcomeScreen())),
      GoRoute(path: '/demo', builder: (ctx, s) => const DemoScreen()),
      // Anciens liens (8.12) : la démo est un seul écran ; l'inscription est fermée.
      GoRoute(path: '/demo/drill', redirect: (ctx, s) => '/demo'),
      GoRoute(path: '/auth/register', redirect: (ctx, s) => '/welcome'),
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
      GoRoute(path: '/auth/login', builder: (ctx, s) => const AuthLoginScreen()),
      GoRoute(path: '/paywall', pageBuilder: (ctx, s) => _instant(s, const PaywallScreen())),
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
        // Sans contexte (lien, app relancée) : le collège, qui dit s'il est en import.
        redirect: (ctx, s) => s.extra is Map ? null : '/colleges/${s.pathParameters['ref_id']}',
        builder: (ctx, s) {
          final extra = s.extra! as Map<String, dynamic>;
          return ImportProgressScreen(
            collegeId: extra['collegeId'] as String,
            refId: extra['refId'] as int,
            reimport: extra['reimport'] as bool? ?? false,
          );
        },
      ),
      // Recherche : sheet depuis Aujourd'hui / Bibliothèque (story 8.10) ; ancien lien.
      GoRoute(path: '/search', redirect: (ctx, s) => '/home'),
      ShellRoute(
        // Le cadre des onglets ne glisse jamais : seuls les écrans poussés dedans le font.
        pageBuilder: (context, state, child) => _instant(
          state,
          PendingUploadResumer(child: AppShell(location: state.uri.path, child: child)),
        ),
        routes: [
          GoRoute(path: '/home', pageBuilder: (ctx, s) => _instant(s, const TodayScreen())),
          GoRoute(path: '/progress', pageBuilder: (ctx, s) => _instant(s, const ProgressScreen())),
          GoRoute(path: '/colleges', pageBuilder: (ctx, s) => _instant(s, const CollegesScreen())),
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
          GoRoute(path: '/profile', pageBuilder: (ctx, s) => _instant(s, const ProfileScreen())),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Racines d'onglet et écrans d'entrée : remplacés sans glissement (un onglet iOS
/// ne pousse pas d'écran) ; les écrans empilés gardent la transition iOS et le
/// retour par balayage.
Page<void> _instant(GoRouterState state, Widget child) => NoTransitionPage<void>(key: state.pageKey, child: child);

/// Fond de l'app pendant la relecture de la session (quelques millisecondes).
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: CgTheme.of(context).colors.ground,
        // Même logo, même place que l'écran de lancement iOS : aucun saut.
        child: const Center(child: CgLogo(size: _launchLogo)),
      );

  static const _launchLogo = 120.0;
}
