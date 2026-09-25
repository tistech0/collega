import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/domain/import_messages.dart';

void main() {
  test('chaque erreur d’import a une phrase utile (plus de code brut)', () {
    for (final code in [
      'file_too_large', 'job_in_progress', 'queue_unavailable', 'college_reload_limit',
      'monthly_reload_limit:2026-10-01T00:00:00+00:00', 'upload_in_progress', 'upload_failed',
      'upload_expired', 'upload_source_missing', 'session_expired', 'network_error', 'generation_failed',
      'Http status error [500]',
    ]) {
      final m = importErrorMessage(code);
      expect(m, isNotEmpty, reason: code);
      expect(m, isNot(contains('_')), reason: '$code : pas de code technique');
      expect(m, isNot(contains('Http')), reason: code);
    }
  });

  test('messages du spec', () {
    expect(importErrorMessage('monthly_reload_limit:2026-10-01T00:00:00+00:00'),
        'Plus de réimport ce mois-ci : le compteur repart le 1er octobre.');
    expect(importErrorMessage('upload_failed'),
        'L’envoi s’est interrompu. Il repartira de là où il s’est arrêté à ta prochaine ouverture de Collega.');
  });

  test('un autre envoi en cours : le collège est nommé', () {
    expect(uploadInProgressMessage('Cancérologie'),
        'Le PDF de Cancérologie est en cours d’envoi. Attends qu’il soit terminé pour en importer un autre.');
    expect(uploadInProgressMessage(null), importErrorMessage('upload_in_progress'));
  });

  test('réimport : « Tes fiches restent » en tête', () {
    expect(importErrorMessage('college_reload_limit', reimport: true),
        startsWith('Tes fiches restent. '));
    expect(importErrorMessage('college_reload_limit'), isNot(startsWith('Tes fiches restent')));
  });

  test('taille : « Ce fichier fait 612 Mo, maximum 500. »', () {
    expect(tooLargeMessage(612 * 1024 * 1024), 'Ce fichier fait 612 Mo, maximum 500.');
  });
}
