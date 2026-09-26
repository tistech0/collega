import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/collega_ui.dart';

import '../../../support/cg_golden.dart';

Widget _host({String? feedback, VoidCallback? onUseful, VoidCallback? onReport}) => cgTestApp(
      Center(
        child: CgCardFeedback(
          feedback: feedback,
          onUseful: onUseful ?? () {},
          onReport: onReport ?? () {},
        ),
      ),
    );

void main() {
  testWidgets('deux icônes étiquetées pour VoiceOver, 44 pt chacune', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.bySemanticsLabel('Fiche utile'), findsOneWidget);
    expect(find.bySemanticsLabel('Signaler la fiche'), findsOneWidget);
    for (final key in [CgCardFeedback.usefulKey, CgCardFeedback.reportKey]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.width, greaterThanOrEqualTo(CgSpace.tapTarget));
      expect(size.height, greaterThanOrEqualTo(CgSpace.tapTarget));
    }
  });

  testWidgets('toucher appelle le bon rappel', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_host(onUseful: () => calls.add('useful'), onReport: () => calls.add('report')));
    await tester.tap(find.byKey(CgCardFeedback.usefulKey));
    await tester.tap(find.byKey(CgCardFeedback.reportKey));
    expect(calls, ['useful', 'report']);
  });

  testWidgets('état choisi annoncé (selected) et lisible sans la couleur (fond accentSoft)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(feedback: 'positive'));
    expect(
      tester.getSemantics(find.byKey(CgCardFeedback.usefulKey)),
      matchesSemantics(label: 'Fiche utile', isButton: true, isSelected: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.byKey(CgCardFeedback.reportKey)),
      matchesSemantics(label: 'Signaler la fiche', isButton: true, hasTapAction: true),
    );
    final decorated = tester.widgetList<DecoratedBox>(
      find.descendant(of: find.byKey(CgCardFeedback.usefulKey), matching: find.byType(DecoratedBox)),
    );
    expect(
      decorated.any((d) => (d.decoration as BoxDecoration).color == CgThemeData.light.colors.accentSoft),
      isTrue,
    );
    handle.dispose();
  });
}
