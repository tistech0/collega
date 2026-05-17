import 'package:flutter/foundation.dart';

@immutable
class RevisionPrefs {
  const RevisionPrefs({
    this.defaultRangs,
    this.defaultMaxCards = 0,
  });

  final List<String>? defaultRangs;
  final int defaultMaxCards;

  RevisionPrefs copyWith({
    Object? defaultRangs = _absent,
    int? defaultMaxCards,
  }) {
    return RevisionPrefs(
      defaultRangs: identical(defaultRangs, _absent)
          ? this.defaultRangs
          : defaultRangs as List<String>?,
      defaultMaxCards: defaultMaxCards ?? this.defaultMaxCards,
    );
  }

  static const _absent = Object();
  static const RevisionPrefs defaults = RevisionPrefs();
}
