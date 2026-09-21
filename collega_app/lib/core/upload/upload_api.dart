import 'package:dio/dio.dart';

import 'package:collega_app/core/upload/upload_models.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

/// Mappe une DioException d'import (mono-requête ou morceaux) vers une exception typée.
/// Le 413 peut venir de Cloudflare avec un body HTML (pas de `detail`) : ne jamais caster le body.
/// Renvoie la DioException elle-même si aucun cas connu ne s'applique.
Exception mapImportDioError(DioException e) {
  final status = e.response?.statusCode;
  final data = e.response?.data;
  final detail = data is Map ? data['detail'] as Map? : null;
  final code = detail?['code'] as String?;

  if (status == 413) return const FileTooLargeException();
  if (status == 403 && code == 'SUBSCRIPTION_REQUIRED') return const SubscriptionRequiredException();
  if (status == 404 && code == 'UPLOAD_NOT_FOUND') return const UploadExpiredException();
  if (status == 409 && code == 'UPLOAD_INCOMPLETE') {
    return UploadIncompleteException(((detail?['missing'] as List?) ?? const []).cast<int>());
  }
  if (status == 409 && code == 'JOB_IN_PROGRESS') return const JobInProgressException();
  if (status == 409 && code == 'COLLEGE_RELOAD_LIMIT') {
    return CollegeReloadLimitException(
      reloadCount: (detail?['reload_count'] as num).toInt(),
      reloadCountMax: (detail?['reload_count_max'] as num).toInt(),
    );
  }
  if (status == 409 && code == 'MONTHLY_RELOAD_LIMIT') {
    return MonthlyReloadLimitException(
      monthlyReloads: (detail?['monthly_reloads'] as num).toInt(),
      monthlyMax: (detail?['monthly_max'] as num).toInt(),
      resetAt: detail?['reset_at'] as String,
    );
  }
  if (status == 503) return const QueueUnavailableException();
  return e;
}

/// Routes de l'upload par morceaux (Story 7.11). Les PUT parts passent par [PartTransport].
abstract class UploadApi {
  Future<UploadInitResponse> init(int refId, int sizeBytes);
  Future<UploadStatusResponse> status(String uploadId);
  Future<ImportStartResponse> complete(String uploadId);
}

class DioUploadApi implements UploadApi {
  const DioUploadApi({required this.dio});
  final Dio dio;

  @override
  Future<UploadInitResponse> init(int refId, int sizeBytes) async {
    try {
      final r = await dio.post<Map<String, dynamic>>(
        '/v1/colleges/$refId/import/init',
        data: {'size_bytes': sizeBytes},
      );
      return UploadInitResponse.fromJson(r.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapImportDioError(e);
    }
  }

  @override
  Future<UploadStatusResponse> status(String uploadId) async {
    try {
      final r = await dio.get<Map<String, dynamic>>('/v1/colleges/import/$uploadId');
      return UploadStatusResponse.fromJson(r.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapImportDioError(e);
    }
  }

  @override
  Future<ImportStartResponse> complete(String uploadId) async {
    try {
      // L'assemblage de 500 MB sur le NAS peut prendre plusieurs dizaines de secondes.
      final r = await dio.post<Map<String, dynamic>>(
        '/v1/colleges/import/$uploadId/complete',
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );
      return ImportStartResponse.fromJson(r.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapImportDioError(e);
    }
  }
}
