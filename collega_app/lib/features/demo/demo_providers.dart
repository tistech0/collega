import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/demo_data.dart';

@immutable
class DemoDrillState {
  const DemoDrillState({
    this.currentIndex = 0,
    this.isFlipped = false,
    this.evaluations = const {},
    this.isComplete = false,
  });
  final int currentIndex;
  final bool isFlipped;
  final Map<int, String> evaluations; // index → 'A_REVOIR' | 'BIEN' | 'MAITRISE'
  final bool isComplete;

  DemoDrillState copyWith({
    int? currentIndex,
    bool? isFlipped,
    Map<int, String>? evaluations,
    bool? isComplete,
  }) =>
      DemoDrillState(
        currentIndex: currentIndex ?? this.currentIndex,
        isFlipped: isFlipped ?? this.isFlipped,
        evaluations: evaluations ?? this.evaluations,
        isComplete: isComplete ?? this.isComplete,
      );
}

class DemoDrillNotifier extends AutoDisposeNotifier<DemoDrillState> {
  @override
  DemoDrillState build() => const DemoDrillState();

  void flip() => state = state.copyWith(isFlipped: !state.isFlipped);

  void evaluate(String rang) {
    final newEvals = Map<int, String>.from(state.evaluations)..[state.currentIndex] = rang;
    final total = demoCollege.item.cards.length;
    final nextIndex = state.currentIndex + 1;
    state = state.copyWith(
      evaluations: newEvals,
      currentIndex: nextIndex < total ? nextIndex : state.currentIndex,
      isFlipped: false,
      isComplete: newEvals.length >= total,
    );
  }

  void reset() => state = const DemoDrillState();
}

final demoDrillProvider = NotifierProvider.autoDispose<DemoDrillNotifier, DemoDrillState>(
  DemoDrillNotifier.new,
);
