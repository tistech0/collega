import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/utils/fr_dates.dart';

void main() {
  test('dates françaises', () {
    final d = DateTime(2026, 9, 21);
    expect(frDayTitle(d), 'Lundi 21');
    expect(frMonth(d), 'septembre');
    expect(frWeekdayInitial(DateTime(2026, 9, 27)), 'D');
    expect(frWeekday(DateTime(2026, 9, 23)), 'mercredi');
  });

  test('dates courtes et longues (planning, 8.8-8.9)', () {
    expect(frShortDate(DateTime(2026, 9, 21)), '21 sept.');
    expect(frShortDate(DateTime(2026, 5, 1)), '1er mai');
    expect(frShortDate(DateTime(2026, 7, 3)), '3 juil.');
    expect(frLongDate(DateTime(2026, 10, 1)), 'jeudi 1er octobre');
  });
}
