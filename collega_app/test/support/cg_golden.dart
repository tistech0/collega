import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

import 'cg_fonts.dart';

/// Largeurs iPhone du spec (SE/mini · 15/16 · Pro Max) et échelles de texte (1,0 / 1,6).
const cgGoldenWidths = [375.0, 393.0, 430.0];
const cgGoldenScales = [1.0, 1.6];

/// Déclare les 6 goldens d'un sujet : `goldens/<name>_<largeur>_<échelle>.png`.
///
/// [height] : hauteur de la surface (le contenu doit y tenir à 1,6×).
void cgGoldenMatrix(
  String name,
  Widget Function() build, {
  double height = 844,
  bool disableAnimations = true,
}) {
  setUpAll(loadCgFonts);
  for (final width in cgGoldenWidths) {
    for (final scale in cgGoldenScales) {
      final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
      testWidgets('golden $name $tag', (tester) async {
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(cgTestApp(
          build(),
          textScale: scale,
          disableAnimations: disableAnimations,
        ));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(CgGoldenFrame),
          matchesGoldenFile('goldens/${name}_$tag.png'),
        );
      });
    }
  }
}

/// Enveloppe de test : thème Collega UI, échelle de texte, animations réduites.
Widget cgTestApp(Widget child, {double textScale = 1, bool disableAnimations = false}) {
  return CgTheme(
    data: CgThemeData.light,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildCgMaterialTheme(CgThemeData.light),
      home: Builder(builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: CgGoldenFrame(child: child),
        );
      }),
    ),
  );
}

/// Cadre repérable par les goldens (fond `ground`).
class CgGoldenFrame extends StatelessWidget {
  const CgGoldenFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return ColoredBox(
      color: c.ground,
      child: DefaultTextStyle(style: CgType.body.copyWith(color: c.ink), child: child),
    );
  }
}
