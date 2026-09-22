import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/brand/cg_wordmark.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';

void main() {
  testWidgets('le wordmark est un SVG vectoriel lu « Collega » par VoiceOver', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: CgWordmark(height: 40)),
    ));
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.bySemanticsLabel('Collega'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('couleur accent par défaut, surchargeable (bloc sarcelle)', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [
        CgWordmark(height: 40),
        CgWordmark(height: 40, color: Color(0xFFF2F5F3)),
      ]),
    ));
    final pics = tester.widgetList<SvgPicture>(find.byType(SvgPicture)).toList();
    expect(pics[0].colorFilter, const ColorFilter.mode(Color(0xFF0E5E63), BlendMode.srcIn));
    expect(pics[1].colorFilter, const ColorFilter.mode(Color(0xFFF2F5F3), BlendMode.srcIn));
    expect(CgColors.light.accent, const Color(0xFF0E5E63));
  });

  testWidgets('garde les proportions du dessin (largeur déduite de la hauteur)', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: CgWordmark(height: 40)),
    ));
    final size = tester.getSize(find.byType(CgWordmark));
    expect(size.height, 40);
    expect(size.width, closeTo(40 * CgWordmark.aspectRatio, 0.5));
  });
}
