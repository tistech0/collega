import 'dart:io';

import 'package:dio/dio.dart';

import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

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
          receiveTimeout: const Duration(minutes: 5),
        ),
      );
      return ImportStartResponse.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final code = ((e.response?.data as Map?)?['detail'] as Map?)?['code'] as String?;

      if (status == 403 && code == 'SUBSCRIPTION_REQUIRED') {
        throw const SubscriptionRequiredException();
      }
      if (status == 409 && code == 'JOB_IN_PROGRESS') {
        throw const JobInProgressException();
      }
      if (status == 409 && code == 'COLLEGE_RELOAD_LIMIT') {
        final detail = (e.response?.data as Map?)?['detail'] as Map?;
        throw CollegeReloadLimitException(
          reloadCount: (detail?['reload_count'] as num).toInt(),
          reloadCountMax: (detail?['reload_count_max'] as num).toInt(),
        );
      }
      if (status == 409 && code == 'MONTHLY_RELOAD_LIMIT') {
        final detail = (e.response?.data as Map?)?['detail'] as Map?;
        throw MonthlyReloadLimitException(
          monthlyReloads: (detail?['monthly_reloads'] as num).toInt(),
          monthlyMax: (detail?['monthly_max'] as num).toInt(),
          resetAt: detail?['reset_at'] as String,
        );
      }
      if (status == 503) throw const QueueUnavailableException();
      AppLogger.error('importPdf failed', tag: 'CollegeImportRepository', error: e);
      rethrow;
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
