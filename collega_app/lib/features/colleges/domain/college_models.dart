import 'package:collega_app/features/colleges/domain/college_catalog.dart';

class UserCollegeStatus {
  const UserCollegeStatus({
    required this.refId,
    required this.collegeId,
    required this.status,
    required this.cardCountA,
    required this.cardCountB,
    required this.cardCountC,
    this.pdfVersion,
    this.pdfSize,
  });
  final int refId;
  final String collegeId;
  final String status;
  final int cardCountA;
  final int cardCountB;
  final int cardCountC;

  /// PDF en service côté serveur (id du dernier import publié) et sa taille (partie B).
  final String? pdfVersion;
  final int? pdfSize;

  int get totalCards => cardCountA + cardCountB + cardCountC;

  factory UserCollegeStatus.fromJson(Map<String, dynamic> json) =>
      UserCollegeStatus(
        refId: json['college_ref_id'] as int,
        collegeId: json['college_id'] as String,
        status: json['status'] as String,
        cardCountA: json['card_count_a'] as int? ?? 0,
        cardCountB: json['card_count_b'] as int? ?? 0,
        cardCountC: json['card_count_c'] as int? ?? 0,
        pdfVersion: json['pdf_version'] as String?,
        pdfSize: json['pdf_size'] as int?,
      );
}

class CollegeListEntry {
  const CollegeListEntry({
    required this.catalog,
    this.userStatus,
  });
  final CollegeCatalogEntry catalog;
  final UserCollegeStatus? userStatus;

  bool get isImported => userStatus != null;
  bool get isGenerationComplete => userStatus?.status == 'generation_complete';
}
