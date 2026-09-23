import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/profile/domain/reminder_time.dart';

void main() {
  test('aller-retour local → UTC → local, pour chaque heure', () {
    final today = DateTime(2026, 9, 23);
    for (var h = 0; h < 24; h++) {
      expect(reminderLocalHour(reminderUtcHour(h, today), today), h, reason: '$h h');
    }
  });

  test('le décalage suit le fuseau de l’appareil', () {
    final today = DateTime(2026, 9, 23);
    final offset = DateTime(2026, 9, 23, 12).timeZoneOffset.inHours;
    expect(reminderUtcHour(12, today), (12 - offset) % 24);
  });

  test('libellé « 08:00 »', () {
    expect(reminderLabel(8), '08:00');
    expect(reminderLabel(21), '21:00');
  });
}
