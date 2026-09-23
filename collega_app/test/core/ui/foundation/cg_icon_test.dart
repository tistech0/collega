import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/foundation/cg_haptics.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';

void main() {
  testWidgets('CgIcon : SVG trait, taille et couleur demandées, décoratif par défaut', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: CgIcon(CgIcons.search, size: 22, color: Color(0xFF0E5E63))),
    ));
    final pic = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(pic.colorFilter, const ColorFilter.mode(Color(0xFF0E5E63), BlendMode.srcIn));
    expect(tester.getSize(find.byType(CgIcon)), const Size(22, 22));
    expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
    handle.dispose();
  });

  testWidgets('CgIcon avec label : lu par VoiceOver', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: CgIcon(CgIcons.close, semanticLabel: 'Fermer')),
    ));
    expect(find.bySemanticsLabel('Fermer'), findsOneWidget);
    handle.dispose();
  });

  test('toutes les icônes sont des SVG 24×24 valides', () {
    for (final entry in CgIcons.all.entries) {
      expect(entry.value, contains('viewBox="0 0 24 24"'), reason: entry.key);
      expect(entry.value, startsWith('<svg'), reason: entry.key);
    }
    expect(CgIcons.all.length, greaterThanOrEqualTo(20));
  });

  group('CgHaptics — un retour distinct par verdict (spec § Mouvement et haptique)', () {
    late List<String> calls;
    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
        return null;
      });
    });

    test('à revoir = impact moyen, bien = léger, maîtrisé = succès (lourd)', () async {
      await CgHaptics.review();
      await CgHaptics.good();
      await CgHaptics.mastered();
      expect(calls, [
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });

    test('sélection (onglet, segmented) et retournement', () async {
      await CgHaptics.selection();
      await CgHaptics.flip();
      expect(calls, ['HapticFeedbackType.selectionClick', 'HapticFeedbackType.lightImpact']);
    });
  });
}
