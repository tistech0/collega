import 'package:collega_app/core/utils/fr_dates.dart';

/// Phrases des erreurs d'import (story 8.13, spec v2 § Feedback : rassurer →
/// expliquer → proposer). Jamais un code technique à l'écran.
String importErrorMessage(String code, {bool reimport = false}) {
  // Le serveur confirme que c'était un réimport : son contenu n'a pas bougé.
  if (code == 'reimport_failed') return 'Le réimport n’a pas abouti. Tes fiches actuelles sont intactes.';
  final message = switch (code) {
    'file_too_large' => 'Ce fichier dépasse 500 Mo. Choisis une version plus légère du PDF.',
    'job_in_progress' => 'Un import de ce collège est déjà en cours. Tu le retrouves dans la Bibliothèque.',
    'queue_unavailable' => 'Le service d’import est momentanément indisponible. Réessaie dans quelques minutes.',
    'college_reload_limit' => 'Ce collège a déjà été réimporté le nombre maximum de fois.',
    'upload_in_progress' => 'Un autre PDF est en cours d’envoi. Attends qu’il se termine.',
    'upload_failed' => 'L’envoi s’est interrompu. Il reprendra tout seul.',
    'upload_expired' => 'L’envoi a expiré. Choisis à nouveau le PDF.',
    'upload_source_missing' => 'Le fichier n’est plus sur l’iPhone. Choisis à nouveau le PDF.',
    'session_expired' => 'Ta session a expiré. Reconnecte-toi puis relance l’import.',
    'generation_failed' => 'La création des fiches n’a pas abouti. Relance l’import de ce PDF.',
    final s when s.startsWith('monthly_reload_limit:') => _monthly(s.substring('monthly_reload_limit:'.length)),
    _ => 'L’import n’a pas pu démarrer. Vérifie ta connexion et réessaie.',
  };
  return reimport ? 'Tes fiches restent. $message' : message;
}

String _monthly(String iso) {
  final date = DateTime.tryParse(iso)?.toLocal();
  if (date == null) return 'Plus de réimport ce mois-ci.';
  return 'Plus de réimport ce mois-ci : le compteur repart le ${frShortDateLong(date)}.';
}

/// « 1er octobre », « 12 novembre ».
String frShortDateLong(DateTime d) => '${d.day == 1 ? '1er' : d.day} ${frMonth(d)}';

/// « Ce fichier fait 612 Mo, maximum 500. »
String tooLargeMessage(int bytes) => 'Ce fichier fait ${(bytes / (1024 * 1024)).round()} Mo, maximum 500.';
