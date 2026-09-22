import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Story 8.2 — AC5 et AC6 : les composants Collega UI n'importent ni Material ni
/// shadcn_ui, et ne contiennent aucune couleur brute (tout passe par les tokens).
void main() {
  final files = Directory('lib/core/ui/components')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('les 14 composants sont présents', () {
    final names = files.map((f) => f.uri.pathSegments.last).toSet();
    for (final n in [
      'cg_button', 'cg_tab_bar', 'cg_header', 'cg_list_row', 'cg_segmented', 'cg_sheet',
      'cg_drill_card', 'cg_verdict_bar', 'cg_ring', 'cg_rank_bar', 'cg_badge', 'cg_field',
      'cg_state', 'cg_skeleton', 'cg_toast',
    ]) {
      expect(names, contains('$n.dart'));
    }
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final source = file.readAsStringSync();

    test('$name : ni Material ni shadcn_ui', () {
      expect(source, isNot(contains('package:flutter/material.dart')));
      expect(source, isNot(contains('shadcn_ui')));
    });

    test('$name : aucune couleur brute Color(0x…)', () {
      final raw = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)').allMatches(source).toList();
      expect(raw, isEmpty, reason: raw.map((m) => m.group(0)).join(', '));
    });
  }

  test('le point d’entrée collega_ui.dart exporte chaque composant', () {
    final barrel = File('lib/core/ui/collega_ui.dart').readAsStringSync();
    for (final file in files) {
      expect(barrel, contains("components/${file.uri.pathSegments.last}"));
    }
  });
}
