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

  test('échec d’un réimport confirmé par le serveur : fiches intactes, sans double préfixe', () {
    const expected = 'Le réimport n’a pas abouti. Tes fiches actuelles sont intactes.';
    expect(importErrorMessage('reimport_failed'), expected);
    expect(importErrorMessage('reimport_failed', reimport: true), expected);
  });
}
