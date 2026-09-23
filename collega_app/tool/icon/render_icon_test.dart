// Rend le logo Collega en PNG (icône iOS 1024 plein cadre, écran de lancement
// arrondi) depuis la même source que l'app. Lancer :
//   flutter test tool/icon/render_icon_test.dart && python3 tool/icon/make_icons.py
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/brand/cg_logo.dart';

Future<void> _render(WidgetTester tester, {required double size, required bool rounded, required String out}) async {
  final key = GlobalKey();
  tester.view.physicalSize = Size(size, size);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(key: key, child: CgLogo(size: size, rounded: rounded)),
  ));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200)); // SVG décodé
  });
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(out)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('icône iOS 1024 plein cadre', (tester) async {
    await _render(tester, size: 1024, rounded: false, out: 'build/icon/app_icon_1024.png');
  });
  testWidgets('écran de lancement 360 arrondi', (tester) async {
    await _render(tester, size: 360, rounded: true, out: 'build/icon/launch_360.png');
  });
}
