import 'package:flutter/foundation.dart';

@immutable
class RevisionPrefs {
  const RevisionPrefs({
    this.defaultRangs,
    this.defaultMaxCards = 0,
    this.timerEnabled = false,
    this.timerDurationSeconds = 30,
  });

  final List<String>? defaultRangs;
  final int defaultMaxCards;
  final bool timerEnabled;
  final int timerDurationSeconds;

  RevisionPrefs copyWith({
    Object? defaultRangs = _absent,
    int? defaultMaxCards,
    bool? timerEnabled,
    int? timerDurationSeconds,
  }) {
    return RevisionPrefs(
      defaultRangs: identical(defaultRangs, _absent)
          ? this.defaultRangs
          : defaultRangs as List<String>?,
      defaultMaxCards: defaultMaxCards ?? this.defaultMaxCards,
      timerEnabled: timerEnabled ?? this.timerEnabled,
      timerDurationSeconds: timerDurationSeconds ?? this.timerDurationSeconds,
    );
  }

  static const _absent = Object();
  static const RevisionPrefs defaults = RevisionPrefs();
}
