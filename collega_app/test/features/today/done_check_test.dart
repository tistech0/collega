import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/today/presentation/done_check.dart';

Widget _host(Widget child, {bool reduced = false}) => CgTheme(
      data: CgThemeData.light,
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Directionality(textDirection: TextDirection.ltr, child: Center(child: child)),
      ),
    );

double _scale(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(DoneCheck.scaleKey)).transform.entry(0, 0);

void main() {
  late List<MethodCall> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
        return null;
      },
    );
  });

  testWidgets('sans animation : rond coché à sa taille finale, aucune vibration', (tester) async {
    await tester.pumpWidget(_host(const DoneCheck(size: 56)));
    expect(_scale(tester), 1.0);
    expect(haptics, isEmpty);
    expect(tester.getSize(find.byType(DoneCheck)), const Size(56, 56));
  });

  testWidgets('animé : rebondit puis se pose, une seule vibration', (tester) async {
    await tester.pumpWidget(_host(const DoneCheck(size: 56, animate: true)));
    expect(_scale(tester), lessThan(1.0));
    await tester.pump(DoneCheck.duration * 0.4);
    expect(_scale(tester), greaterThan(1.0));
    await tester.pumpAndSettle();
    expect(_scale(tester), 1.0);
    expect(haptics, hasLength(1));
  });

  testWidgets('réduction des animations : pas de rebond, pas de vibration', (tester) async {
    await tester.pumpWidget(_host(const DoneCheck(size: 56, animate: true), reduced: true));
    expect(_scale(tester), 1.0);
    await tester.pumpAndSettle();
    expect(haptics, isEmpty);
  });

  testWidgets('animate qui passe à vrai après coup : rien n’est rejoué', (tester) async {
    await tester.pumpWidget(_host(const DoneCheck(size: 56)));
    await tester.pumpWidget(_host(const DoneCheck(size: 56, animate: true)));
    expect(_scale(tester), 1.0);
    expect(haptics, isEmpty);
  });
}
