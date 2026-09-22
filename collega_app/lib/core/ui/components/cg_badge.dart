import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

enum _CgBadgeKind { rank, ocr, beta, count }

/// Étiquette sémantique (spec v2 § CgBadge) : rang A/B/C, source OCR à
/// vérifier, beta, compteur. Jamais seule pour porter une information :
/// toujours une lettre ou un mot, la couleur ne fait que renforcer.
class CgBadge extends StatelessWidget {
  /// Rang de connaissance `A`, `B` ou `C`. Affiche « Rang A » ; [short] : « A »
  /// seul (lignes d'items, où la place manque). VoiceOver lit toujours « Rang A ».
  const CgBadge.rank(String rank, {super.key, bool short = false})
      : assert(rank == 'A' || rank == 'B' || rank == 'C', 'Rang attendu : A, B ou C'),
        _kind = _CgBadgeKind.rank,
        _rank = rank,
        _short = short,
        _count = 0,
        _semanticLabel = null,
        onTap = null;

  /// Source OCR douteuse : icône `warning` + « À vérifier ». Avec [onTap], le
  /// badge ouvre l'explication (popover) et sa cible passe à 44 pt.
  const CgBadge.ocr({super.key, this.onTap})
      : _kind = _CgBadgeKind.ocr,
        _rank = '',
        _short = false,
        _count = 0,
        _semanticLabel = null;

  /// « Beta » (Profil, écran de marque).
  const CgBadge.beta({super.key})
      : _kind = _CgBadgeKind.beta,
        _rank = '',
        _short = false,
        _count = 0,
        _semanticLabel = null,
        onTap = null;

  /// Compteur. [semanticLabel] donne l'unité à VoiceOver (« 3 fiches ») ;
  /// sans lui, le nombre seul est lu.
  const CgBadge.count(int count, {super.key, String? semanticLabel})
      : _kind = _CgBadgeKind.count,
        _rank = '',
        _short = false,
        _count = count,
        _semanticLabel = semanticLabel,
        onTap = null;

  final _CgBadgeKind _kind;
  final String _rank;
  final bool _short;
  final int _count;
  final String? _semanticLabel;

  /// Seul le badge OCR est tapable.
  final VoidCallback? onTap;

  /// Hauteur minimale : le badge grandit avec le Dynamic Type au lieu de couper.
  static const _minHeight = 22.0;
  static const _horizontalPadding = CgSpace.s2;
  static const _iconSize = 14.0;
  static const _iconGap = CgSpace.s1;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final (fill, ink) = _colors(c);
    final (text, semantics) = switch (_kind) {
      _CgBadgeKind.rank => (_short ? _rank : 'Rang $_rank', 'Rang $_rank'),
      _CgBadgeKind.ocr => ('À vérifier', 'Source à vérifier'),
      _CgBadgeKind.beta => ('Beta', 'Beta'),
      _CgBadgeKind.count => ('$_count', _semanticLabel ?? '$_count'),
    };

    Widget badge = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(color: fill, borderRadius: CgRadius.badgeAll),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_kind == _CgBadgeKind.ocr) ...[
                // L'icône suit le Dynamic Type comme le texte qu'elle accompagne.
                CgIcon(CgIcons.warning, size: MediaQuery.textScalerOf(context).scale(_iconSize), color: ink),
                const SizedBox(width: _iconGap),
              ],
              Text(
                text,
                maxLines: 1,
                softWrap: false,
                style: CgType.label.copyWith(color: ink, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap != null) {
      // Cible tactile 44 pt autour d'un badge qui reste visuellement à 22 pt.
      badge = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: CgSpace.tapTarget, minHeight: CgSpace.tapTarget),
          child: Center(widthFactor: 1, heightFactor: 1, child: badge),
        ),
      );
    }

    return Semantics(
      container: true,
      button: onTap != null,
      label: semantics,
      excludeSemantics: true,
      onTap: onTap,
      child: badge,
    );
  }

  (Color fill, Color ink) _colors(CgColors c) => switch (_kind) {
        _CgBadgeKind.rank => switch (_rank) {
            'A' => (c.accentSoft, c.accent),
            'B' => (c.rankBSoft, c.rankB),
            _ => (c.soft, c.rankC),
          },
        _CgBadgeKind.ocr => (c.soft, c.warningInk),
        _CgBadgeKind.beta => (c.accentSoft, c.accent),
        _CgBadgeKind.count => (c.soft, c.ink2),
      };
}
