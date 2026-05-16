import 'package:dio/dio.dart';
import 'package:collega_app/features/search/domain/search_result.dart';

class SearchRepository {
  const SearchRepository(this._dio);
  final Dio _dio;

  Future<List<SearchResult>> search(String query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/search',
      queryParameters: {'q': query},
    );
    final body = response.data;
    if (body == null) return [];
    final data = body['data'];
    if (data is! List) return [];
    return data
        .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
