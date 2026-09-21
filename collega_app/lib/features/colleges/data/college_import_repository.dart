import 'dart:io';

import 'package:dio/dio.dart';

import 'package:collega_app/core/upload/upload_api.dart' show mapImportDioError;
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

// Les exceptions d'import vivent dans upload_models.dart (partagées avec l'upload par
// morceaux, Story 7.11) ; ré-exportées ici pour les imports existants.
export 'package:collega_app/core/upload/upload_models.dart'
    show
        SubscriptionRequiredException,
        JobInProgressException,
        QueueUnavailableException,
        CollegeReloadLimitException,
        MonthlyReloadLimitException;

class CollegeImportRepository {
  const CollegeImportRepository({required this.dio});
  final Dio dio;

  Future<ImportStartResponse> importPdf(int refId, File pdfFile) async {
    try {
      final formData = FormData.fromMap({
        'pdf': await MultipartFile.fromFile(
          pdfFile.path,
          filename: pdfFile.path.split('/').last,
          contentType: DioMediaType('application', 'pdf'),
        ),
      });
      final response = await dio.post<Map<String, dynamic>>(
        '/v1/colleges/$refId/import',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 20),
          receiveTimeout: const Duration(minutes: 20),
        ),
      );
      return ImportStartResponse.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final mapped = mapImportDioError(e);
      if (identical(mapped, e)) {
        AppLogger.error('importPdf failed', tag: 'CollegeImportRepository', error: e);
      }
      throw mapped;
    }
  }

  Future<ReloadLimits> getReloadLimits(int refId) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/v1/colleges/$refId/reload-limits',
      );
      return ReloadLimits.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      AppLogger.error('getReloadLimits failed', tag: 'CollegeImportRepository', error: e);
      rethrow;
    }
  }

  Future<CollegeStatusResponse> getStatus(String collegeId) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/v1/colleges/$collegeId/status',
      );
      return CollegeStatusResponse.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      AppLogger.error('getStatus failed', tag: 'CollegeImportRepository', error: e);
      rethrow;
    }
  }
}
