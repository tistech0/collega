import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:collega_app/core/ui/theme/cg_theme.dart';

/// Les illustrations des états d'écran (spec v2 § CgState).
enum CgIllustration {
  /// Feuillets empilés : rien d'importé, rien à réviser.
  sheets,

  /// Anneau rompu (un fragment décalé) : le serveur ne répond pas.
  broken,

  /// Ondes coupées : pas de connexion.
  offline,

  /// Loupe sur des lignes : aucun résultat.
  search,

  /// Anneau fermé coché : tout est fait.
  done,
}

/// SVG au trait sur une grille 96, monochromes (colorés par [CgIllustrationArt]) :
/// formes abstraites, jamais d'emoji ni de raster (spec v2 § Ton de voix).
abstract final class CgIllustrations {
  static const sheets = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" fill="none" stroke="#000" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M34 19v-1a6 6 0 0 1 6-6h34a6 6 0 0 1 6 6v46a6 6 0 0 1-6 6h-1"/>'
      '<path d="M27 26v-1a6 6 0 0 1 6-6h34a6 6 0 0 1 6 6v46a6 6 0 0 1-6 6h-1"/>'
      '<rect x="20" y="26" width="46" height="58" rx="6"/>'
      '<path d="M29 42h28M29 52h28M29 62h18"/></svg>';

  static const broken = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" fill="none" stroke="#000" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M78 48A30 30 0 1 1 42.8 18.5"/>'
      '<path d="M68.3 9.8A30 30 0 0 1 86.2 27.7"/></svg>';

  static const offline = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" fill="none" stroke="#000" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M22.5 40.5a36 36 0 0 1 51 0"/>'
      '<path d="M31 49a24 24 0 0 1 34 0"/>'
      '<path d="M39.5 57.5a12 12 0 0 1 17 0"/>'
      '<circle cx="48" cy="68" r="2.5"/>'
      '<path d="M22 20l52 58"/></svg>';

  static const search = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" fill="none" stroke="#000" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="M14 28h44M14 40h28M14 52h20M14 64h14"/>'
      '<circle cx="58" cy="54" r="16"/>'
      '<path d="M69.5 65.5 82 78"/></svg>';

  static const done = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" fill="none" stroke="#000" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">'
      '<circle cx="48" cy="48" r="30"/>'
      '<path d="m35 49 9 9 17-19"/></svg>';

  static String svgOf(CgIllustration illustration) => switch (illustration) {
        CgIllustration.sheets => sheets,
        CgIllustration.broken => broken,
        CgIllustration.offline => offline,
        CgIllustration.search => search,
        CgIllustration.done => done,
      };
}

/// Une illustration, décorative (exclue de VoiceOver : le titre de l'état dit tout).
class CgIllustrationArt extends StatelessWidget {
  const CgIllustrationArt(this.illustration, {super.key, this.size = defaultSize, this.color});

  /// Taille d'un état d'écran (spec v2 : 96 pt).
  static const defaultSize = 96.0;

  final CgIllustration illustration;
  final double size;

  /// Par défaut `accent`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? CgTheme.of(context).colors.accent;
    return ExcludeSemantics(
      child: SvgPicture.string(
        CgIllustrations.svgOf(illustration),
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      ),
    );
  }
}
