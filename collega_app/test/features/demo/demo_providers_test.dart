import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/demo/demo_providers.dart';
import 'package:collega_app/features/demo/domain/demo_data.dart';

void main() {
  late ProviderContainer c;
  setUp(() => c = ProviderContainer());
  tearDown(() => c.dispose());

  DemoDrillNotifier n() => c.read(demoDrillProvider.notifier);

  test('état initial : première fiche, rien de jugé', () {
    final s = c.read(demoDrillProvider);
    expect(s.currentIndex, 0);
    expect(s.verdicts, isEmpty);
    expect(s.isComplete, isFalse);
  });

  test('un verdict par fiche, puis terminé ; décompte par verdict', () {
    n().judge(CgVerdict.mastered);
    n().judge(CgVerdict.good);
    expect(c.read(demoDrillProvider).currentIndex, 2);
    n().judge(CgVerdict.mastered);
    final s = c.read(demoDrillProvider);
    expect(s.isComplete, isTrue);
    expect(s.count(CgVerdict.mastered), 2);
    expect(s.count(CgVerdict.good), 1);
    expect(s.count(CgVerdict.review), 0);
    expect(s.verdicts.length, demoCollege.item.cards.length);
  });

  test('restart repart de zéro', () {
    n().judge(CgVerdict.review);
    n().restart();
    expect(c.read(demoDrillProvider).verdicts, isEmpty);
  });
}
