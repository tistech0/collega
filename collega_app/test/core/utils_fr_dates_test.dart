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
}
