import 'package:flutter/foundation.dart';

@immutable
class SearchResult {
  const SearchResult({
    required this.itemId,
    required this.itemNumber,
    required this.rang,
    this.chapterTitle,
    required this.collegeId,
    required this.collegeRefId,
    required this.excerpt,
  });

  final String itemId;
  final int itemNumber;
  final String rang;
  final String? chapterTitle;
  final String collegeId;
  final int collegeRefId;
  final String excerpt;

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      itemId: json['item_id'] as String,
      itemNumber: json['item_number'] as int,
      rang: json['rang'] as String,
      chapterTitle: json['chapter_title'] as String?,
      collegeId: json['college_id'] as String,
      collegeRefId: json['college_ref_id'] as int,
      excerpt: json['excerpt'] as String,
    );
  }
}
