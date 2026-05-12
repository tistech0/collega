import 'package:dio/dio.dart';

import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';

class CollegesRepository {
  const CollegesRepository({required this.dio});
  final Dio dio;

  Future<List<UserCollegeStatus>> getUserColleges() async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/v1/colleges');
      final body = response.data;
      if (body == null) {
        AppLogger.error('getUserColleges: null response body', tag: 'CollegesRepository');
        return [];
      }
      final list = body['data'] as List<dynamic>;
      return list
          .map((e) => UserCollegeStatus.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      AppLogger.error('getUserColleges failed', tag: 'CollegesRepository', error: e);
      rethrow;
    } catch (e) {
      AppLogger.error('getUserColleges: unexpected error', tag: 'CollegesRepository', error: e);
      rethrow;
    }
  }
}
