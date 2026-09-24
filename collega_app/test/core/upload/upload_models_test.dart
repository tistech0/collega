import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/upload/upload_api.dart';
import 'package:collega_app/core/upload/upload_models.dart';

DioException _err(int status, Object? data) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: data),
    );

void main() {
  test('UploadInitResponse.fromJson', () {
    final r = UploadInitResponse.fromJson({
      'upload_id': 'u',
      'part_size': 26214400,
      'parts_total': 17,
      'expires_at': '2026-09-22T10:00:00+00:00',
    });
    expect(r.partsTotal, 17);
    expect(r.expiresAt.isUtc, isTrue);
  });

  test('UploadStatusResponse.fromJson trie received', () {
    final r = UploadStatusResponse.fromJson({
      'received': [3, 1],
      'parts_total': 4,
      'part_size': 2,
      'size_bytes': 7,
    });
    expect(r.received, [1, 3]);
  });

  group('mapImportDioError', () {
    test('413 avec body HTML Cloudflare → FileTooLargeException', () {
      expect(mapImportDioError(_err(413, '<html>413 Payload Too Large</html>')), isA<FileTooLargeException>());
    });
    test('404 UPLOAD_NOT_FOUND → UploadExpiredException', () {
      expect(
        mapImportDioError(_err(404, {'detail': {'code': 'UPLOAD_NOT_FOUND'}})),
        isA<UploadExpiredException>(),
      );
    });
    test('409 UPLOAD_INCOMPLETE → UploadIncompleteException(missing)', () {
      final e = mapImportDioError(_err(409, {
        'detail': {'code': 'UPLOAD_INCOMPLETE', 'missing': [2, 5]},
      }));
      expect((e as UploadIncompleteException).missing, [2, 5]);
    });
    test('409 JOB_IN_PROGRESS → JobInProgressException', () {
      expect(
        mapImportDioError(_err(409, {'detail': {'code': 'JOB_IN_PROGRESS'}})),
        isA<JobInProgressException>(),
      );
    });
    test('409 COLLEGE_RELOAD_LIMIT → CollegeReloadLimitException', () {
      final e = mapImportDioError(_err(409, {
        'detail': {'code': 'COLLEGE_RELOAD_LIMIT', 'reload_count': 2, 'reload_count_max': 2},
      }));
      expect((e as CollegeReloadLimitException).reloadCountMax, 2);
    });
    test('503 → QueueUnavailableException', () {
      expect(mapImportDioError(_err(503, null)), isA<QueueUnavailableException>());
    });
    test('500 inconnu → renvoie la DioException', () {
      final e = _err(500, null);
      expect(mapImportDioError(e), same(e));
    });
    // Chantier 5 § 4 : 422 / 429 / 500 ont désormais un `detail` objet ; ils restent non typés.
    test('422 VALIDATION_ERROR, 429 RATE_LIMITED, 500 INTERNAL_ERROR → renvoie la DioException', () {
      for (final (status, code) in [(422, 'VALIDATION_ERROR'), (429, 'RATE_LIMITED'), (500, 'INTERNAL_ERROR')]) {
        final e = _err(status, {
          'detail': {'code': code, 'message': 'x', if (status == 422) 'errors': []},
        });
        expect(mapImportDioError(e), same(e));
      }
    });
  });
}
