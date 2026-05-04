import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/demo/demo_providers.dart';

void main() {
  group('DemoDrillNotifier', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('état initial correct', () {
      final state = container.read(demoDrillProvider);
      expect(state.currentIndex, 0);
      expect(state.isFlipped, false);
      expect(state.isComplete, false);
      expect(state.evaluations, isEmpty);
    });

    test('flip() bascule isFlipped à true', () {
      container.read(demoDrillProvider.notifier).flip();
      expect(container.read(demoDrillProvider).isFlipped, true);
    });

    test('flip() deux fois revient à false', () {
      final notifier = container.read(demoDrillProvider.notifier);
      notifier.flip();
      notifier.flip();
      expect(container.read(demoDrillProvider).isFlipped, false);
    });

    test('evaluate() ajoute à evaluations et remet isFlipped à false', () {
      final notifier = container.read(demoDrillProvider.notifier);
      notifier.flip();
      notifier.evaluate('MAITRISE');
      final state = container.read(demoDrillProvider);
      expect(state.evaluations[0], 'MAITRISE');
      expect(state.isFlipped, false);
      expect(state.currentIndex, 1);
    });

    test('evaluate() après 3 évals → isComplete = true', () {
      final notifier = container.read(demoDrillProvider.notifier);
      notifier.flip();
      notifier.evaluate('MAITRISE');
      notifier.flip();
      notifier.evaluate('BIEN');
      notifier.flip();
      notifier.evaluate('A_REVOIR');
      final state = container.read(demoDrillProvider);
      expect(state.isComplete, true);
      expect(state.evaluations.length, 3);
    });

    test('reset() remet l\'état initial', () {
      final notifier = container.read(demoDrillProvider.notifier);
      notifier.flip();
      notifier.evaluate('MAITRISE');
      notifier.reset();
      final state = container.read(demoDrillProvider);
      expect(state.currentIndex, 0);
      expect(state.isFlipped, false);
      expect(state.isComplete, false);
      expect(state.evaluations, isEmpty);
    });
  });
}
