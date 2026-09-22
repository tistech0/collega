import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

enum _CgBoneShape { line, block, ring }

/// Bloc de chargement aux formes du contenu final (spec v2 § CgSkeleton) :
/// fond `soft`, pulsation d'opacité 1 → 0,55 → 1 en [CgMotion.skeletonPulse],
/// en boucle — la seule animation en boucle autorisée. Statique en mouvement
/// réduit. Jamais un spinner.
///
/// Invisible pour VoiceOver : c'est l'écran (ou [CgSkeletonList]) qui annonce
/// « Chargement », une seule fois.
class CgSkeleton extends StatelessWidget {
  /// Ligne de texte (rayon `badge`).
  const CgSkeleton.line({super.key, this.width = double.infinity, this.height = 14})
      : radius = CgRadius.badge,
        _shape = _CgBoneShape.line;

  /// Bloc (carte, hero). `width` null : toute la largeur disponible.
  const CgSkeleton.block({super.key, this.width, required this.height, this.radius = CgRadius.l})
      : _shape = _CgBoneShape.block;

  /// Anneau (disque plein à la taille de [CgRing]).
  const CgSkeleton.ring({super.key, double size = 56})
      : width = size,
        height = size,
        radius = 0,
        _shape = _CgBoneShape.ring;

  final double? width;
  final double height;
  final double radius;
  final _CgBoneShape _shape;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CgSkeletonPulse(
        // Largeur imposée par un parent `stretch` : la forme garde la sienne,
        // calée au début (sinon une ligne de 180 pt s'étire sur tout l'écran).
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          heightFactor: 1,
          child: _Bone(
            width: width ?? double.infinity,
            height: height,
            radius: radius,
            circle: _shape == _CgBoneShape.ring,
          ),
        ),
      ),
    );
  }
}

/// Lignes de liste en chargement (pastille 36 + titre + sous-titre), sous une
/// seule pulsation et un seul nœud VoiceOver « Chargement ».
///
/// Les lignes suivent le Dynamic Type : à 1,6×, elles ont la hauteur du texte
/// qu'elles remplacent (pas de saut quand le contenu arrive).
class CgSkeletonList extends StatelessWidget {
  const CgSkeletonList({super.key, this.rows = 5}) : assert(rows > 0);

  final int rows;

  /// Géométrie des lignes de liste de la maquette (`.row`, `.ico`).
  static const _leadingSize = 36.0;
  static const _rowPadding = 14.0;
  static const _rowGap = 14.0;
  static const _titleHeight = 14.0;
  static const _subtitleHeight = 12.0;

  /// Largeurs variées d'une ligne à l'autre : un bloc uniforme se lit comme un motif.
  static const _titleWidths = [0.62, 0.48, 0.7, 0.55];
  static const _subtitleWidths = [0.4, 0.3, 0.46, 0.34];

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      container: true,
      label: 'Chargement',
      excludeSemantics: true,
      child: CgSkeletonPulse(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: _rowPadding),
              child: Row(children: [
                const _Bone(width: _leadingSize, height: _leadingSize, radius: CgRadius.s),
                const SizedBox(width: _rowGap),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FractionallySizedBox(
                      widthFactor: _titleWidths[i % _titleWidths.length],
                      child: _Bone(height: scaler.scale(_titleHeight), radius: CgRadius.badge),
                    ),
                    const SizedBox(height: CgSpace.s2),
                    FractionallySizedBox(
                      widthFactor: _subtitleWidths[i % _subtitleWidths.length],
                      child: _Bone(height: scaler.scale(_subtitleHeight), radius: CgRadius.badge),
                    ),
                  ]),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Pulsation partagée d'un groupe de skeletons (public pour composer un
/// écran de chargement sur mesure sous une seule pulsation).
class CgSkeletonPulse extends StatefulWidget {
  const CgSkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<CgSkeletonPulse> createState() => _CgSkeletonPulseState();
}

class _CgSkeletonPulseState extends State<CgSkeletonPulse> with SingleTickerProviderStateMixin {
  /// Creux de la pulsation (spec : 1 → 0,55 → 1).
  static const _minOpacity = 0.55;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: CgMotion.skeletonPulse);

  /// Creux à mi-cycle, retour lissé (cosinus) : pas d'à-coup à la boucle.
  late final Animation<double> _opacity = _controller.drive(
    _PulseTween(minOpacity: _minOpacity),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Suit « Réduire les animations » y compris s'il change en cours de route.
    if (CgMotion.reduced(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _opacity, child: widget.child);
}

class _PulseTween extends Animatable<double> {
  const _PulseTween({required this.minOpacity});

  final double minOpacity;

  @override
  double transform(double t) => 1 - (1 - minOpacity) * (1 - math.cos(2 * math.pi * t)) / 2;
}

/// Une forme `soft` sans animation (la pulsation est portée par le parent).
class _Bone extends StatelessWidget {
  const _Bone({this.width = double.infinity, required this.height, required this.radius, this.circle = false});

  final double width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.soft,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.all(Radius.circular(radius)),
        ),
      ),
    );
  }
}
