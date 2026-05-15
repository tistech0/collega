import 'package:flutter/foundation.dart';

@immutable
class HomeSessionConfig {
  const HomeSessionConfig({
    required this.collegeId,
    required this.collegeName,
    this.rangs,
    this.maxCards = 0,
    this.statusFilter = 'all',
  });

  final String collegeId;
  final String collegeName;
  final List<String>? rangs;
  final int maxCards;
  final String statusFilter;

  bool get onlyARevoir => statusFilter == 'a_revoir';

  HomeSessionConfig copyWith({
    String? collegeId,
    String? collegeName,
    Object? rangs = _absent,
    int? maxCards,
    String? statusFilter,
  }) {
    return HomeSessionConfig(
      collegeId: collegeId ?? this.collegeId,
      collegeName: collegeName ?? this.collegeName,
      rangs: identical(rangs, _absent) ? this.rangs : rangs as List<String>?,
      maxCards: maxCards ?? this.maxCards,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }

  static const _absent = Object();
}
