import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/search/search_providers.dart';

/// Propriétaire des données locales (fiches, progression, session du jour).
///
/// La progression n'existe que sur l'appareil : la déconnexion ne l'efface pas
/// (l'étudiant qui se reconnecte la retrouve). Seule la connexion d'un AUTRE
/// compte vide la base, pour ne jamais lui montrer les données du précédent.
class LocalDataOwner {
  const LocalDataOwner({required this.storage, required this.db, this.clearPdfs});

  final FlutterSecureStorage storage;
  final AppDatabase db;

  /// Supprime les PDF gardés sur le téléphone (partie B).
  final Future<void> Function()? clearPdfs;

  static const storageKey = 'local_data_owner';

  Future<void> claim(String userId) async {
    final previous = await storage.read(key: storageKey);
    if (previous != null && previous != userId) {
      await db.deleteEverything();
      // Les recherches récentes (trousseau) suivent la même règle.
      await storage.delete(key: SecureSearchRecentsStore.storageKey);
      await clearPdfs?.call();
    }
    if (previous != userId) await storage.write(key: storageKey, value: userId);
  }
}
