import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/shell/tab_reselect.dart';

/// Shell des 4 onglets (story 8.3) : Aujourd'hui · Bibliothèque · Progression · Profil.
///
/// La tab bar flotte au-dessus du contenu ; le drill, l'import et la recherche
/// sont des routes hors shell (plein écran, sans tab bar). Re-taper l'onglet
/// actif remonte l'écran en haut ([TabReselect]).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const paths = ['/home', '/colleges', '/progress', '/profile'];

  /// Écrans pas encore migrés vers Collega UI (détail d'item 8.11, Profil 8.14) :
  /// leur Scaffold ne connaît pas la tab bar flottante. Leur contenu s'arrête
  /// au-dessus de la capsule (un simple padding MediaQuery ne suffit pas : une
  /// barre posée en bottomNavigationBar sans SafeArea finirait sous la capsule,
  /// intapable). Les écrans migrés la réservent eux-mêmes (`CgPage.reserveTabBar`).
  static final _legacyPattern = RegExp(r'^/(profile|((home|progress)/)?colleges/[^/]+/items/)');

  static int indexOf(String location) {
    for (var i = paths.length - 1; i >= 0; i--) {
      if (location.startsWith(paths[i])) return i;
    }
    return 0;
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _reselect = TabReselect();

  @override
  void dispose() {
    _reselect.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    final current = AppShell.indexOf(widget.location);
    if (index == current) {
      _reselect.reselect(index);
      // Déjà sur l'onglet mais dans un écran poussé : retour à sa racine.
      if (widget.location != AppShell.paths[index]) context.go(AppShell.paths[index]);
      return;
    }
    context.go(AppShell.paths[index]);
  }

  @override
  Widget build(BuildContext context) {
    final legacy = AppShell._legacyPattern.hasMatch(widget.location);
    Widget content = widget.child;
    if (legacy) {
      content = Padding(
        padding: EdgeInsets.only(bottom: CgTabBar.reservedHeight(context)),
        child: MediaQuery.removePadding(context: context, removeBottom: true, child: content),
      );
    }
    return TabReselectScope(
      reselect: _reselect,
      child: CgTabBarScope(
        child: ColoredBox(
          color: CgTheme.of(context).colors.ground,
          child: Stack(children: [
            Positioned.fill(child: content),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CgTabBar(
                items: CgTabBar.mainItems,
                currentIndex: AppShell.indexOf(widget.location),
                onTap: _onTap,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
