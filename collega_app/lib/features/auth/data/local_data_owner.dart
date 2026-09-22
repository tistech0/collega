import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:collega_app/core/database/app_database.dart';

/// Propriétaire des données locales (fiches, progression, session du jour).
///
/// La progression n'existe que sur l'appareil : la déconnexion ne l'efface pas
/// (l'étudiant qui se reconnecte la retrouve). Seule la connexion d'un AUTRE
/// compte vide la base, pour ne jamais lui montrer les données du précédent.
class LocalDataOwner {
  const LocalDataOwner({required this.storage, required this.db});

  final FlutterSecureStorage storage;
  final AppDatabase db;

  static const storageKey = 'local_data_owner';

  Future<void> claim(String userId) async {
    final previous = await storage.read(key: storageKey);
    if (previous != null && previous != userId) await db.deleteEverything();
    if (previous != userId) await storage.write(key: storageKey, value: userId);
  }
}
