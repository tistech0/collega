import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logo Collega (vague 2, piste 12 « Anneau des rangs + pile ») : le C en trois
/// arcs aux couleurs des rangs (maîtrisé, bien, à revoir) autour d'une pile de
/// fiches, sur sarcelle. Couleurs de marque fixes (un logo ne suit pas le thème).
/// Source unique : `assets/brand/logo.svg` (icône iOS : `tool/icon`).
class CgLogo extends StatelessWidget {
  const CgLogo({super.key, required this.size, this.rounded = true});

  final double size;

  /// Coins d'icône iOS (22,37 %) ; `false` : plein cadre (iOS applique son masque).
  final bool rounded;

  static const cornerRatio = 0.2237;

  static const svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect width="100" height="100" fill="#0E5E63"/><path d="M69.4 28.45 A29 29 0 0 0 31.36 27.78" stroke="#F2F5F3" stroke-width="9" fill="none" stroke-linecap="round"/><path d="M28.45 30.6 A29 29 0 0 0 28.45 69.4" stroke="#8FC4BD" stroke-width="9" fill="none" stroke-linecap="round"/><path d="M31.36 72.22 A29 29 0 0 0 69.4 71.55" stroke="#D9822B" stroke-width="9" fill="none" stroke-linecap="round"/><rect x="42" y="37" width="17" height="23" rx="2.7" fill="#8FB9B4" transform="rotate(-14 50 50)"/><rect x="43" y="39" width="17" height="23" rx="2.7" fill="#F2F5F3" transform="rotate(-2 50 50)"/></svg>';

  @override
  Widget build(BuildContext context) {
    Widget logo = SvgPicture.string(svg, width: size, height: size);
    if (rounded) logo = ClipRRect(borderRadius: BorderRadius.circular(size * cornerRatio), child: logo);
    return Semantics(label: 'Collega', image: true, excludeSemantics: true, child: SizedBox.square(dimension: size, child: logo));
  }
}
