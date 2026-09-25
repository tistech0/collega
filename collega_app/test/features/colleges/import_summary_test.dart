import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/domain/import_messages.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

ImportSummary _s({int changed = 0, int added = 0, int removed = 0, int unchanged = 0, bool refunded = false}) =>
    ImportSummary(changed: changed, added: added, removed: removed, unchanged: unchanged, quotaRefunded: refunded);

void main() {
  test('réimport avec changements : pluriels, compteurs non nuls seulement', () {
    expect(importSummaryText(_s(changed: 3, added: 1, unchanged: 20)), '3 items mis à jour, 1 nouveau, 20 inchangés');
    expect(importSummaryText(_s(changed: 1, removed: 2, unchanged: 1)), '1 item mis à jour, 2 supprimés, 1 inchangé');
    expect(importSummaryText(_s(added: 2, removed: 1)), '2 nouveaux, 1 supprimé');
  });

  test('aucun changement : réimport non décompté si le quota a été rendu', () {
    expect(importSummaryText(_s(unchanged: 24, refunded: true)), 'Aucun changement dans ce PDF : réimport non décompté');
    expect(importSummaryText(_s(unchanged: 24)), 'Aucun changement dans ce PDF');
  });

  test('résumé lu depuis le JSON du serveur', () {
    final s = ImportSummary.fromJson({'changed': 2, 'added': 0, 'removed': 0, 'unchanged': 5, 'quota_refunded': false,
      'cards': 40, 'claude_calls': 2});
    expect([s.changed, s.unchanged, s.quotaRefunded, s.nothingChanged], [2, 5, false, false]);
    expect(ImportSummary.maybeFromJson(null), isNull);
  });

  test('premier import : aucun compteur de changement ; rien à dire sans item insuffisant', () {
    const first = ImportSummary(changed: 0, added: 40, removed: 0, unchanged: 0, quotaRefunded: false, reimport: false);
    expect(importSummaryText(first), isNull);
  });

  test('premier import avec items sans contenu suffisant : seulement la liste, jamais « N nouveaux »', () {
    const first = ImportSummary(changed: 0, added: 40, removed: 0, unchanged: 0, quotaRefunded: false,
        reimport: false, insufficientItems: [215, 230]);
    expect(importSummaryText(first), 'Pas assez de contenu : items 215, 230');
  });

  test('réimport avec items insuffisants : changements puis la liste', () {
    const s = ImportSummary(changed: 1, added: 0, removed: 0, unchanged: 20, quotaRefunded: false,
        insufficientItems: [215]);
    expect(importSummaryText(s), '1 item mis à jour, 20 inchangés. Pas assez de contenu : item 215');
  });

  test('liste longue : 8 items puis « et N autres »', () {
    expect(insufficientItemsText([for (var i = 1; i <= 9; i++) i]), 'Pas assez de contenu : items 1, 2, 3, 4, 5, 6, 7, 8 et 1 autre');
    expect(insufficientItemsText([for (var i = 1; i <= 11; i++) i]),
        'Pas assez de contenu : items 1, 2, 3, 4, 5, 6, 7, 8 et 3 autres');
    expect(insufficientItemsText(const []), isNull);
  });

  test('JSON : reimport et insufficient_items lus ; serveur ancien sans « reimport » = réimport', () {
    final first = ImportSummary.fromJson({'changed': 0, 'added': 40, 'removed': 0, 'unchanged': 0,
      'quota_refunded': false, 'reimport': false, 'insufficient_items': [215, 216]});
    expect(first.reimport, isFalse);
    expect(first.insufficientItems, [215, 216]);
    final old = ImportSummary.fromJson({'changed': 2, 'added': 0, 'removed': 0, 'unchanged': 5, 'quota_refunded': false});
    expect(old.reimport, isTrue);
    expect(old.insufficientItems, isEmpty);
  });

  test('échec d’un réimport confirmé par le serveur : fiches intactes, sans double préfixe', () {
    const expected = 'Le réimport n’a pas abouti. Tes fiches actuelles sont intactes.';
    expect(importErrorMessage('reimport_failed'), expected);
    expect(importErrorMessage('reimport_failed', reimport: true), expected);
  });
}
