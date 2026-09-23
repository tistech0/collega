import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Story 8.15 : le design system v1 (shadcn_ui, thème Material « AppColors ») est retiré.
void main() {
  test('pubspec : plus de shadcn_ui ni de google_fonts', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('shadcn_ui')));
    expect(pubspec, isNot(contains('google_fonts')));
  });

  test('lib/ : aucun import de shadcn_ui ni du thème v1', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('shadcn_ui') || src.contains('core/theme/app_theme.dart')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
    expect(File('lib/core/theme/app_theme.dart').existsSync(), isFalse);
  });

  test('Material cantonné au conteneur technique (app, thème Collega, main)', () {
    final allowed = {'lib/app.dart', 'lib/core/ui/theme/cg_theme.dart', 'lib/main.dart'};
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || allowed.contains(f.path)) continue;
      if (f.readAsStringSync().contains('package:flutter/material.dart')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });
}
