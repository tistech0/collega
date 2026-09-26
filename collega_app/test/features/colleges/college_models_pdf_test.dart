import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/colleges/data/college_cards_sync.dart';

import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';

void main() {
  test('ItemModel lit start_page / end_page (base 0), null si absents', () {
    final base = {'id': 'i1', 'item_number': 340, 'rang': 'A', 'low_confidence': false};
    final withPages = ItemModel.fromJson({...base, 'start_page': 111, 'end_page': 117});
    expect(withPages.startPage, 111);
    expect(withPages.endPage, 117);
    final without = ItemModel.fromJson(base);
    expect(without.startPage, isNull);
    expect(without.endPage, isNull);
  });

  test('UserCollegeStatus lit pdf_version / pdf_size', () {
    final s = UserCollegeStatus.fromJson({
      'college_ref_id': 26, 'college_id': 'c1', 'status': 'generation_complete',
      'pdf_version': 'job-1', 'pdf_size': 398458880,
    });
    expect(s.pdfVersion, 'job-1');
    expect(s.pdfSize, 398458880);
    final none = UserCollegeStatus.fromJson({'college_ref_id': 26, 'college_id': 'c1', 'status': 'pending'});
    expect(none.pdfVersion, isNull);
    expect(none.pdfSize, isNull);
  });

  test('les pages survivent à la synchro drift et à la relecture', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await syncItemsToDrift(db, 'c1', [
      const ItemModel(
        id: 'i1', collegeId: 'c1', itemNumber: 340, rang: 'A', ocrConfidenceScore: 0.9, lowConfidence: false,
        cardCountA: 1, cardCountB: 0, cardCountC: 0, startPage: 111, endPage: 117,
      ),
    ]);
    final row = await db.select(db.items).getSingle();
    expect((row.startPage, row.endPage), (111, 117));
  });
}
