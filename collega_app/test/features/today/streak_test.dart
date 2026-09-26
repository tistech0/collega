import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/today/domain/streak.dart';

void main() {
  const t = 20000;

  int streak(Set<int> completed, {Set<int> excused = const {}}) =>
      streakLength(today: t, completed: completed, excused: excused);

  test('aucune session : 0', () => expect(streak({}), 0));

  test('aujourd’hui fait, rien avant : 1', () => expect(streak({t}), 1));

  test('aujourd’hui et les 2 jours d’avant : 3', () => expect(streak({t, t - 1, t - 2}), 3));

  test('aujourd’hui pas encore fait ne casse pas : on compte depuis hier', () {
    expect(streak({t - 1, t - 2}), 2);
  });

  test('un trou casse la série', () => expect(streak({t, t - 2, t - 3}), 1));

  test('hier manqué et aujourd’hui pas fait : 0', () => expect(streak({t - 2, t - 3}), 0));

  test('jour décalé ou calme : ne casse pas et ne compte pas', () {
    expect(streak({t, t - 2}, excused: {t - 1}), 2);
    expect(streak({t - 1, t - 3}, excused: {t - 2}), 2);
  });

  test('plusieurs jours excusés d’affilée', () {
    expect(streak({t, t - 4}, excused: {t - 1, t - 2, t - 3}), 2);
  });

  test('jour calme puis session faite le même jour : compté une fois', () {
    expect(streak({t, t - 1}, excused: {t}), 2);
  });

  test('seulement des jours excusés : 0', () => expect(streak({}, excused: {t - 1, t - 2}), 0));

  test('jours futurs ignorés', () => expect(streak({t + 1, t}), 1));

  test('seuil d’affichage du badge', () => expect(kStreakMinShown, 2));
}
