import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/pdf/data/backup_excluder.dart';

enum LocalPdfStatus { absent, upToDate, outdated }

/// Copies locales des PDF importés (partie B) : `<collegeId>_<version>.pdf`, où
/// la version est l'id du job d'import (convention du serveur). Plusieurs
/// versions d'un même collège peuvent coexister le temps d'un réimport.
class LocalPdfStore {
  LocalPdfStore(this.root, {this.excluder = const NoopBackupExcluder()});

  final Directory root;
  final BackupExcluder excluder;

  File fileFor(String collegeId, String version) => File(p.join(root.path, '${collegeId}_$version.pdf'));

  File _lastPageFile(String collegeId) => File(p.join(root.path, '$collegeId.page'));

  Future<List<File>> _copies(String collegeId) async {
    if (!await root.exists()) return const [];
    final files = <File>[];
    await for (final e in root.list()) {
      final name = p.basename(e.path);
      if (e is File && name.startsWith('${collegeId}_') && name.endsWith('.pdf')) files.add(e);
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync())); // plus récente d'abord
    return files;
  }

  /// La copie à ouvrir : celle de [serverVersion] si présente, sinon (version
  /// inconnue) la plus récente ; null si rien d'utilisable.
  Future<File?> readable(String collegeId, String? serverVersion) async {
    final copies = await _copies(collegeId);
    if (serverVersion == null) return copies.isEmpty ? null : copies.first;
    final wanted = fileFor(collegeId, serverVersion);
    if (!await wanted.exists()) return null;
    final wantedTime = wanted.lastModifiedSync();
    for (final f in copies) {
      // Versions dépassées : plus anciennes que la version en service. Les plus
      // récentes (réimport pas encore publié) restent.
      if (f.path != wanted.path && f.lastModifiedSync().isBefore(wantedTime)) await _delete(f);
    }
    return wanted;
  }

  Future<LocalPdfStatus> status(String collegeId, String? serverVersion) async {
    if (await readable(collegeId, serverVersion) != null) return LocalPdfStatus.upToDate;
    return (await _copies(collegeId)).isEmpty ? LocalPdfStatus.absent : LocalPdfStatus.outdated;
  }

  /// Copie du PDF choisi à l'import (la source reste intacte : l'envoi en a besoin).
  Future<void> keepCopy({required String collegeId, required String version, required File source}) async {
    await root.create(recursive: true);
    final dest = fileFor(collegeId, version);
    final tmp = File('${dest.path}.tmp');
    await source.copy(tmp.path);
    await _stamp(collegeId, tmp);
    await tmp.rename(dest.path);
    await _exclude(dest);
  }

  /// Téléchargement complet déplacé en place.
  Future<void> adopt({required String collegeId, required String version, required File downloaded}) async {
    await root.create(recursive: true);
    final dest = fileFor(collegeId, version);
    await _stamp(collegeId, downloaded);
    await downloaded.rename(dest.path);
    await _exclude(dest);
  }

  /// La date de modification ordonne les versions d'un collège (la plus récente
  /// arrivée sur le téléphone gagne). `File.copy` garde celle du fichier choisi,
  /// et elle n'a qu'une précision d'une seconde : on la pose nous-mêmes,
  /// strictement après toutes les copies déjà là.
  Future<void> _stamp(String collegeId, File f) async {
    final now = DateTime.now();
    var at = now.subtract(Duration(milliseconds: now.millisecond, microseconds: now.microsecond));
    for (final other in await _copies(collegeId)) {
      final t = other.lastModifiedSync();
      if (!t.isBefore(at)) at = t.add(const Duration(seconds: 1));
    }
    await f.setLastModified(at);
  }

  Future<void> deleteExcept(Set<String> collegeIds) async {
    if (!await root.exists()) return;
    await for (final e in root.list()) {
      final name = p.basename(e.path);
      final collegeId = name.split(RegExp(r'[_.]')).first;
      if (e is File && !collegeIds.contains(collegeId)) await _delete(e);
    }
  }

  Future<void> clear() async {
    if (await root.exists()) await root.delete(recursive: true);
  }

  Future<int?> lastPage(String collegeId) async {
    final f = _lastPageFile(collegeId);
    if (!await f.exists()) return null;
    return int.tryParse((await f.readAsString()).trim());
  }

  Future<void> saveLastPage(String collegeId, int page) async {
    await root.create(recursive: true);
    await _lastPageFile(collegeId).writeAsString('$page');
  }

  Future<void> _exclude(File f) async {
    try {
      await excluder.exclude(f.path);
    } catch (e) {
      // Pas bloquant : au pire, le PDF part dans la sauvegarde iCloud.
      AppLogger.warning('exclusion de sauvegarde impossible : $e', tag: 'LocalPdfStore');
    }
  }

  Future<void> _delete(File f) async {
    try {
      await f.delete();
    } catch (e) {
      AppLogger.warning('suppression impossible : $e', tag: 'LocalPdfStore');
    }
  }
}
