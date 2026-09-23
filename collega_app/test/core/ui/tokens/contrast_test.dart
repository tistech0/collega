import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_tab_bar.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/contrast.dart';

/// Story 8.1 — contrastes du spec v2 (§ Fondation visuelle / Accessibilité).
/// Ce test échoue dès qu'un couple de tokens passe sous son seuil.
void main() {
  const c = CgColors.light;

  // (texte, fond, seuil, pourquoi)
  final pairs = <(String, Color, Color, double)>[
    ('ink / ground', c.ink, c.ground, 7),
    ('ink / surface', c.ink, c.surface, 7),
    ('ink2 / ground', c.ink2, c.ground, 4.5),
    ('ink2 / surface', c.ink2, c.surface, 4.5),
    // 8.15 : ink3 porte du texte (intertitres, valeurs, précisions, onglets) → 4,5:1.
    ('ink3 / ground (texte tertiaire)', c.ink3, c.ground, 4.5),
    ('ink3 / surface', c.ink3, c.surface, 4.5),
    ('ink3 / soft (placeholder de recherche)', c.ink3, c.soft, 4.5),
    ('accent / ground (texte)', c.accent, c.ground, 4.5),
    ('accent / surface (texte)', c.accent, c.surface, 4.5),
    ('accentInk / accent (bouton primaire, drill)', c.accentInk, c.accent, 4.5),
    ('accent / accentSoft (badge A, sélection)', c.accent, c.accentSoft, 4.5),
    ('rankB / rankBSoft (badge B)', c.rankB, c.rankBSoft, 4.5),
    ('rankC / soft (badge C)', c.rankC, c.soft, 4.5),
    ('reviewInk / ground (« À revoir » en texte)', c.reviewInk, c.ground, 4.5),
    ('reviewInk / surface', c.reviewInk, c.surface, 4.5),
    ('onReview / review (étiquette sur fond orange)', c.onReview, c.review, 4.5),
    ('danger / ground', c.danger, c.ground, 4.5),
    ('danger / surface', c.danger, c.surface, 4.5),
    ('warningInk / ground (badge OCR)', c.warningInk, c.ground, 4.5),
    ('ground / ink (toast)', c.ground, c.ink, 4.5),
    ('ink2 / soft (segmented, recherche)', c.ink2, c.soft, 4.5),
  ];

  test('tab bar translucide : libellé inactif ≥ 4,5:1 au-dessus du contenu le plus sombre', () {
    for (final under in [c.ink, c.accent, c.review]) {
      final fill = Color.alphaBlend(c.surface.withValues(alpha: CgTabBar.fillAlpha), under);
      expect(contrastRatio(c.ink3, fill), greaterThanOrEqualTo(4.5), reason: '$under');
    }
  });

  test('ink2 et ink3 restent deux niveaux distincts (≥ 1,4:1 entre eux)', () {
    expect(contrastRatio(c.ink2, c.ink3), greaterThanOrEqualTo(1.4));
  });

  for (final (name, fg, bg, min) in pairs) {
    test('$name ≥ $min:1', () {
      expect(contrastRatio(fg, bg), greaterThanOrEqualTo(min));
    });
  }

  test('accent / ground en surface ≥ 3:1 (anneau plein, CTA)', () {
    expect(contrastRatio(c.accent, c.ground), greaterThanOrEqualTo(3));
  });

  test('line reste discret (≈ 1,3:1, entre 1,1 et 1,5)', () {
    final ratio = contrastRatio(c.line, c.ground);
    expect(ratio, inInclusiveRange(1.1, 1.5));
  });

  test('états de progression : luminance croissante mastered < good < unseen', () {
    expect(c.mastered.computeLuminance(), lessThan(c.good.computeLuminance()));
    expect(c.good.computeLuminance(), lessThan(c.unseen.computeLuminance()));
  });

  test('review ≠ danger (à revoir n’est pas une erreur)', () {
    expect(c.review, isNot(c.danger));
  });

  test('contrastRatio : noir/blanc = 21, symétrique', () {
    const black = Color(0xFF000000), white = Color(0xFFFFFFFF);
    expect(contrastRatio(black, white), closeTo(21, 0.01));
    expect(contrastRatio(white, black), closeTo(21, 0.01));
  });
}
