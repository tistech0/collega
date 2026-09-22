import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/foundation/cg_haptics.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Les trois jugements d'une fiche : à revoir, bien, maîtrisé.
///
/// L'ordre suit les gestes de [CgDrillCard] : gauche, haut, droite.
enum CgVerdict { review, good, mastered }

/// Libellés français des verdicts (boutons, étiquettes de prévisualisation).
extension CgVerdictLabel on CgVerdict {
  String get label => switch (this) {
        CgVerdict.review => 'À revoir',
        CgVerdict.good => 'Bien',
        CgVerdict.mastered => 'Maîtrisé',
      };
}

/// Les trois verdicts en boutons (spec v2 § CgVerdictBar) : le chemin VoiceOver
/// et celui de qui ne swipe pas. Chaque bouton joue sa propre haptique puis
/// appelle [onVerdict] ; dans une [CgDrillCard], la carte pilote alors la même
/// sortie que le swipe.
class CgVerdictBar extends StatelessWidget {
  const CgVerdictBar({super.key, required this.onVerdict, this.enabled = true});

  final ValueChanged<CgVerdict> onVerdict;
  final bool enabled;

  /// Clé du bouton d'un verdict (tests, écrans qui le ciblent).
  static Key buttonKey(CgVerdict verdict) => ValueKey('cg-verdict-${verdict.name}');

  /// Au-delà de cette échelle de texte, les boutons s'empilent (spec § Dynamic Type).
  static const stackAboveTextScale = 1.6;

  static const _gap = CgSpace.s2;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(1) > stackAboveTextScale;
    final buttons = [
      for (final v in CgVerdict.values)
        _VerdictButton(
          key: buttonKey(v),
          verdict: v,
          enabled: enabled,
          singleLine: !stacked,
          onPressed: () => _press(v),
        ),
    ];
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, b) in buttons.indexed) ...[
            if (i > 0) const SizedBox(height: _gap),
            b,
          ],
        ],
      );
    }
    // Sur une ligne, les trois libellés partagent une même échelle, réduite juste
    // assez pour que le plus long tienne (« Maîtrisé » à 1,6× sur 375 pt) : pas de
    // mot coupé, pas de tailles inégales d'un bouton à l'autre.
    return LayoutBuilder(builder: (context, constraints) {
      final scaler = MediaQuery.textScalerOf(context);
      final available = (constraints.maxWidth - 2 * _gap) / CgVerdict.values.length - _VerdictButtonState.chrome;
      var needed = 0.0;
      for (final v in CgVerdict.values) {
        final painter = TextPainter(
          text: TextSpan(text: v.label, style: CgType.head),
          textScaler: scaler,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        if (painter.width > needed) needed = painter.width;
        painter.dispose();
      }
      final row = Row(children: [
        for (final (i, b) in buttons.indexed) ...[
          if (i > 0) const SizedBox(width: _gap),
          Expanded(child: b),
        ],
      ]);
      if (needed <= available || available <= 0) return row;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scaler.scale(1) * available / needed)),
        child: row,
      );
    });
  }

  void _press(CgVerdict v) {
    switch (v) {
      case CgVerdict.review:
        CgHaptics.review();
      case CgVerdict.good:
        CgHaptics.good();
      case CgVerdict.mastered:
        CgHaptics.mastered();
    }
    onVerdict(v);
  }
}

/// Un bouton de verdict : même physique que `CgButton` (54 pt, rayon bouton,
/// pressé 0,97) mais avec les couleurs propres aux verdicts — « À revoir » en
/// `reviewInk` n'existe pas parmi les variantes de `CgButton`.
class _VerdictButton extends StatefulWidget {
  const _VerdictButton({
    super.key,
    required this.verdict,
    required this.enabled,
    required this.singleLine,
    required this.onPressed,
  });

  final CgVerdict verdict;
  final bool enabled;

  /// Sur une ligne (barre horizontale), le libellé ne passe jamais à la ligne.
  final bool singleLine;
  final VoidCallback onPressed;

  @override
  State<_VerdictButton> createState() => _VerdictButtonState();
}

class _VerdictButtonState extends State<_VerdictButton> {
  static const _pressedScale = 0.97;
  static const _horizontalPadding = CgSpace.s2;
  static const _verticalPadding = CgSpace.s2;

  static const _borderWidth = 1.0;

  /// Largeur non disponible pour le libellé : marges internes + contour.
  static const chrome = 2 * (_horizontalPadding + _borderWidth);

  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final enabled = widget.enabled;
    final (Color fill, Color? border, Color text) = switch (widget.verdict) {
      _ when !enabled => (c.soft, null, c.ink3),
      CgVerdict.review => (c.surface, c.line, c.reviewInk),
      CgVerdict.good => (c.surface, c.line, c.ink),
      CgVerdict.mastered => (c.accent, null, c.accentInk),
    };
    final label = widget.verdict.label;
    final Widget labelText = Text(
      label,
      style: CgType.head.copyWith(color: text),
      textAlign: TextAlign.center,
      maxLines: widget.singleLine ? 1 : 2,
      softWrap: !widget.singleLine,
      overflow: TextOverflow.ellipsis,
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? widget.onPressed : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? _pressedScale : 1,
          duration: CgMotion.resolve(context, CgMotion.fast),
          curve: CgMotion.out,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CgSpace.buttonHeight),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: CgRadius.buttonAll,
                border: border == null ? null : Border.all(color: border, width: _borderWidth),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding, vertical: _verticalPadding),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: labelText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
