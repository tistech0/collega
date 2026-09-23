import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/search/domain/search_result.dart';

void main() {
  group('SearchResult.fromJson', () {
    test('parse correctement tous les champs', () {
      final json = {
        'item_id': 'abc-123',
        'item_number': 232,
        'rang': 'A',
        'chapter_title': 'Insuffisance Cardiaque',
        'college_id': 'col-uuid',
        'college_ref_id': 1,
        'excerpt': '<mark>BNP</mark> élevé',
      };
      final result = SearchResult.fromJson(json);
      expect(result.itemId, 'abc-123');
      expect(result.itemNumber, 232);
      expect(result.rang, 'A');
      expect(result.chapterTitle, 'Insuffisance Cardiaque');
      expect(result.collegeId, 'col-uuid');
      expect(result.collegeRefId, 1);
      expect(result.excerpt, '<mark>BNP</mark> élevé');
    });

    test('chapter_title peut être null', () {
      final json = {
        'item_id': 'abc',
        'item_number': 10,
        'rang': 'B',
        'chapter_title': null,
        'college_id': 'c',
        'college_ref_id': 2,
        'excerpt': 'texte',
      };
      final result = SearchResult.fromJson(json);
      expect(result.chapterTitle, isNull);
    });
  });
}
