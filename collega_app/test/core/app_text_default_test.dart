import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/app.dart';
import 'package:collega_app/core/ui/collega_ui.dart';

/// Revue 8.15 : sous MaterialApp, un Text sans style hérite du style d'alerte
/// (rouge, souligné jaune) ; l'app pose le texte courant Collega à sa racine.
void main() {
  testWidgets('texte sans style : encre Collega, jamais le style d’alerte Material', (tester) async {
    late TextStyle inherited;
    await tester.pumpWidget(CgTheme(
      data: CgThemeData.light,
      child: MaterialApp(
        builder: collegaAppBuilder,
        home: Builder(builder: (context) {
          inherited = DefaultTextStyle.of(context).style;
          return const Text('x');
        }),
      ),
    ));
    expect(inherited.color, CgColors.light.ink);
    expect(inherited.decoration, TextDecoration.none);
    expect(inherited.fontFamily, CgType.family);
  });
}
