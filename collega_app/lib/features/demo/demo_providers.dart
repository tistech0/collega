import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/ui/components/cg_verdict_bar.dart';
import 'package:collega_app/features/demo/domain/demo_data.dart';

/// Démo (story 8.12) : les fiches d'exemple dans le vrai drill, puis un récap.
@immutable
class DemoDrillState {
  const DemoDrillState({this.verdicts = const []});

  /// Un verdict par fiche jugée, dans l'ordre.
  final List<CgVerdict> verdicts;

  int get currentIndex => verdicts.length;
  bool get isComplete => verdicts.length >= demoCollege.item.cards.length;
  int count(CgVerdict v) => verdicts.where((x) => x == v).length;
}

class DemoDrillNotifier extends AutoDisposeNotifier<DemoDrillState> {
  @override
  DemoDrillState build() => const DemoDrillState();

  void judge(CgVerdict verdict) {
    if (state.isComplete) return;
    state = DemoDrillState(verdicts: [...state.verdicts, verdict]);
  }

  void restart() => state = const DemoDrillState();
}

final demoDrillProvider = NotifierProvider.autoDispose<DemoDrillNotifier, DemoDrillState>(DemoDrillNotifier.new);
