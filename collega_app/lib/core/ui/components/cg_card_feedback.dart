import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

/// Avis sur une fiche en deux icônes seules (drill, spec « avis pendant le
/// drill ») : pouce haut « Fiche utile », pouce bas « Signaler la fiche ».
/// L'avis choisi se lit sans la couleur : fond `accentSoft` + état annoncé.
class CgCardFeedback extends StatelessWidget {
  const CgCardFeedback({super.key, required this.feedback, required this.onUseful, required this.onReport});

  /// `'positive'`, `'negative'` ou null (valeurs de `user_feedback`).
  final String? feedback;
  final VoidCallback onUseful;
  final VoidCallback onReport;

  static const usefulKey = ValueKey('cg-card-feedback-useful');
  static const reportKey = ValueKey('cg-card-feedback-report');

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _Toggle(
        key: usefulKey,
        icon: CgIcons.thumbUp,
        semanticLabel: 'Fiche utile',
        selected: feedback == 'positive',
        onTap: onUseful,
      ),
      _Toggle(
        key: reportKey,
        icon: CgIcons.thumbDown,
        semanticLabel: 'Signaler la fiche',
        selected: feedback == 'negative',
        onTap: onReport,
      ),
    ]);
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({super.key, required this.icon, required this.semanticLabel, required this.selected, required this.onTap});

  final String icon;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  static const _disc = 36.0;
  static const _iconSize = 18.0;
  static const _border = 1.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: CgSpace.tapTarget,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? c.accentSoft : null,
                border: Border.all(color: selected ? c.accentSoft : c.line, width: _border),
              ),
              child: SizedBox.square(
                dimension: _disc,
                child: Center(child: CgIcon(icon, size: _iconSize, color: selected ? c.accent : c.ink2)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
