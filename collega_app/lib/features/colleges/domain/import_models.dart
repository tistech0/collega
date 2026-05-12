class ImportStartResponse {
  const ImportStartResponse({
    required this.collegeId,
    required this.jobId,
    required this.status,
  });

  final String collegeId;
  final String jobId;
  final String status;

  factory ImportStartResponse.fromJson(Map<String, dynamic> json) =>
      ImportStartResponse(
        collegeId: json['college_id'] as String,
        jobId: json['job_id'] as String,
        status: json['status'] as String,
      );
}

class CollegeStatusResponse {
  const CollegeStatusResponse({
    required this.collegeId,
    required this.refId,
    required this.status,
    required this.ocrProgress,
    this.totalPages,
    this.jobId,
  });

  final String collegeId;
  final int refId;
  final String status;
  final int ocrProgress;
  final int? totalPages;
  final String? jobId;

  factory CollegeStatusResponse.fromJson(Map<String, dynamic> json) =>
      CollegeStatusResponse(
        collegeId: json['college_id'] as String,
        refId: json['ref_id'] as int,
        status: json['status'] as String,
        ocrProgress: json['ocr_page_progress'] as int? ?? 0,
        totalPages: json['total_pages'] as int?,
        jobId: json['job_id'] as String?,
      );
}

sealed class CollegeImportState {
  const CollegeImportState();
}

class ImportIdle extends CollegeImportState {
  const ImportIdle();
}

class ImportUploading extends CollegeImportState {
  const ImportUploading();
}

class ImportStreaming extends CollegeImportState {
  const ImportStreaming({
    required this.collegeId,
    required this.jobId,
    required this.ocrProgress,
    required this.status,
    this.totalPages,
  });

  final String collegeId;
  final String jobId;
  final int ocrProgress;
  final int? totalPages;
  final String status;

  ImportStreaming copyWith({
    String? collegeId,
    String? jobId,
    int? ocrProgress,
    int? totalPages,
    String? status,
  }) =>
      ImportStreaming(
        collegeId: collegeId ?? this.collegeId,
        jobId: jobId ?? this.jobId,
        ocrProgress: ocrProgress ?? this.ocrProgress,
        totalPages: totalPages ?? this.totalPages,
        status: status ?? this.status,
      );
}

class ImportComplete extends CollegeImportState {
  const ImportComplete({required this.collegeId});
  final String collegeId;
}

class ImportError extends CollegeImportState {
  const ImportError({required this.message});
  final String message;
}

class ReloadLimits {
  const ReloadLimits({
    required this.collegeReloadCount,
    required this.collegeReloadMax,
    required this.monthlyReloads,
    required this.monthlyMax,
    required this.monthlyResetAt,
  });

  final int collegeReloadCount;
  final int collegeReloadMax;
  final int monthlyReloads;
  final int monthlyMax;
  final String monthlyResetAt; // ISO 8601 UTC

  bool get isCollegeLimitReached => collegeReloadCount >= collegeReloadMax;
  bool get isMonthlyLimitReached => monthlyReloads >= monthlyMax;

  factory ReloadLimits.fromJson(Map<String, dynamic> json) => ReloadLimits(
        collegeReloadCount: json['college_reload_count'] as int,
        collegeReloadMax: json['college_reload_max'] as int,
        monthlyReloads: json['monthly_reloads'] as int,
        monthlyMax: json['monthly_max'] as int,
        monthlyResetAt: json['monthly_reset_at'] as String,
      );
}
