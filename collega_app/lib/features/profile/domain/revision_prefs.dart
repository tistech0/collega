import 'package:flutter/foundation.dart';

/// Chronomètre par fiche : jamais, toujours, ou choisi au lancement de chaque session.
enum TimerMode { off, on, ask }

@immutable
class RevisionPrefs {
  const RevisionPrefs({
    this.defaultRangs,
    this.defaultMaxCards = 0,
    this.timerMode = TimerMode.off,
    this.timerDurationSeconds = 30,
  });

  final List<String>? defaultRangs;
  final int defaultMaxCards;
  final TimerMode timerMode;
  final int timerDurationSeconds;

  /// Chrono actif d'office (le mode « demander » laisse la session décider).
  bool get timerEnabled => timerMode == TimerMode.on;

  RevisionPrefs copyWith({
    Object? defaultRangs = _absent,
    int? defaultMaxCards,
    TimerMode? timerMode,
    int? timerDurationSeconds,
  }) {
    return RevisionPrefs(
      defaultRangs: identical(defaultRangs, _absent)
          ? this.defaultRangs
          : defaultRangs as List<String>?,
      defaultMaxCards: defaultMaxCards ?? this.defaultMaxCards,
      timerMode: timerMode ?? this.timerMode,
      timerDurationSeconds: timerDurationSeconds ?? this.timerDurationSeconds,
    );
  }

  static const _absent = Object();
  static const RevisionPrefs defaults = RevisionPrefs();
}
