/// Modèles de l'upload par morceaux (Story 7.11) et exceptions typées de l'import
/// (partagées entre l'upload mono-requête et l'upload par morceaux).
library;

class UploadInitResponse {
  const UploadInitResponse({
    required this.uploadId,
    required this.partSize,
    required this.partsTotal,
    required this.expiresAt,
  });

  final String uploadId;
  final int partSize;
  final int partsTotal;
  final DateTime expiresAt;

  factory UploadInitResponse.fromJson(Map<String, dynamic> json) => UploadInitResponse(
        uploadId: json['upload_id'] as String,
        partSize: json['part_size'] as int,
        partsTotal: json['parts_total'] as int,
        expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
      );
}

class UploadStatusResponse {
  const UploadStatusResponse({
    required this.received,
    required this.partsTotal,
    required this.partSize,
    required this.sizeBytes,
  });

  final List<int> received;
  final int partsTotal;
  final int partSize;
  final int sizeBytes;

  factory UploadStatusResponse.fromJson(Map<String, dynamic> json) => UploadStatusResponse(
        received: (json['received'] as List).cast<int>()..sort(),
        partsTotal: json['parts_total'] as int,
        partSize: json['part_size'] as int,
        sizeBytes: json['size_bytes'] as int,
      );
}

// ── Exceptions d'import ────────────────────────────────────────────────────────

class SubscriptionRequiredException implements Exception {
  const SubscriptionRequiredException();
}

class JobInProgressException implements Exception {
  const JobInProgressException();
}

class QueueUnavailableException implements Exception {
  const QueueUnavailableException();
}

class CollegeReloadLimitException implements Exception {
  const CollegeReloadLimitException({required this.reloadCount, required this.reloadCountMax});
  final int reloadCount;
  final int reloadCountMax;
}

class MonthlyReloadLimitException implements Exception {
  const MonthlyReloadLimitException({
    required this.monthlyReloads,
    required this.monthlyMax,
    required this.resetAt,
  });
  final int monthlyReloads;
  final int monthlyMax;
  final String resetAt; // ISO 8601
}

/// 413 — du backend (> 500 MB) ou de Cloudflare (> 100 MB en mono-requête, body HTML).
class FileTooLargeException implements Exception {
  const FileTooLargeException();
}

/// 404 UPLOAD_NOT_FOUND — état d'upload expiré (TTL 24 h) ou déjà consommé.
class UploadExpiredException implements Exception {
  const UploadExpiredException();
}

/// 409 UPLOAD_INCOMPLETE — `complete` appelé alors que des morceaux manquent.
class UploadIncompleteException implements Exception {
  const UploadIncompleteException(this.missing);
  final List<int> missing;
}
