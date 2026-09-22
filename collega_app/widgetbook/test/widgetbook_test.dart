import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_widgetbook/main.dart';

void main() {
  testWidgets('le catalogue démarre et liste la page Tokens', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const CollegaWidgetbook());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Fondation'), findsWidgets);
  });
}
