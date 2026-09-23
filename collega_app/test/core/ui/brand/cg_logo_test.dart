import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/brand/cg_logo.dart';

void main() {
  testWidgets('logo (anneau des rangs + pile) : SVG lu « Collega » par VoiceOver, carré', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: CgLogo(size: 64)),
    ));
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.bySemanticsLabel('Collega'), findsOneWidget);
    expect(tester.getSize(find.byType(CgLogo)), const Size(64, 64));
    handle.dispose();
  });

  testWidgets('arrondi iOS par défaut (rayon 22,37 %), plein cadre pour l’icône d’app', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Column(mainAxisSize: MainAxisSize.min, children: [CgLogo(size: 100), CgLogo(size: 100, rounded: false)]),
    ));
    final clips = tester.widgetList<ClipRRect>(find.byType(ClipRRect)).toList();
    expect(clips, hasLength(1));
    expect(clips.single.borderRadius, BorderRadius.circular(22.37));
  });

  test('une seule source : le SVG embarqué est celui de assets/brand/logo.svg', () {
    expect(File('assets/brand/logo.svg').readAsStringSync().trim(), CgLogo.svg);
  });
}
