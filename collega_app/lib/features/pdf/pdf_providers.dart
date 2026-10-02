import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart' show pdfPickerProvider;
import 'package:collega_app/features/pdf/data/backup_excluder.dart';
import 'package:collega_app/features/pdf/data/local_pdf_store.dart';
import 'package:collega_app/features/pdf/data/pdf_downloader.dart';

/// Copies locales des PDF (partie B), dans Application Support (jamais purgé par
/// iOS, contrairement aux caches), exclues de la sauvegarde iCloud.
final localPdfStoreProvider = FutureProvider<LocalPdfStore>((ref) async {
  final support = await getApplicationSupportDirectory();
  final store = LocalPdfStore(Directory(p.join(support.path, 'pdfs')), excluder: const ChannelBackupExcluder());
  try {
    await store.purgeLeftovers();
  } catch (e) {
    AppLogger.warning('nettoyage des PDF partiels impossible : $e', tag: 'LocalPdfStore');
  }
  return store;
});

final pdfDownloaderProvider = Provider<PdfDownloader>((ref) => BackgroundPdfDownloader(
      accessToken: () async {
        await ref.read(apiClientProvider).ensureFreshAccessToken();
        return await ref.read(secureStorageProvider).read(key: 'access_token') ?? '';
      },
    ));

sealed class PdfDownloadState {
  const PdfDownloadState();
}

class PdfDownloadIdle extends PdfDownloadState {
  const PdfDownloadIdle();
}

class PdfDownloading extends PdfDownloadState {
  const PdfDownloading(this.progress);
  final double progress;
}

class PdfDownloadFailedState extends PdfDownloadState {
  const PdfDownloadFailedState();
}

class PdfDownloadDone extends PdfDownloadState {
  const PdfDownloadDone();
}

/// Téléchargement du PDF d'un collège ; survit à la fermeture de l'écran
/// (provider non autoDispose, comme l'import).
class PdfDownloadNotifier extends FamilyNotifier<PdfDownloadState, String> {
  @override
  PdfDownloadState build(String arg) => const PdfDownloadIdle();

  Future<void> start(String version, {int? expectedSize}) async {
    if (state is PdfDownloading) return;
    state = const PdfDownloading(0);
    try {
      final store = await ref.read(localPdfStoreProvider.future);
      final part = await ref.read(pdfDownloaderProvider).download(
            collegeId: arg,
            version: version,
            into: store.root,
            onProgress: (p) => state = PdfDownloading(p),
          );
      // Jamais une copie invalide (page de connexion Cloudflare, proxy…) : elle
      // serait « à jour » pour toujours, sans moyen de retélécharger.
      if (!await store.verifyDownload(part, expectedSize: expectedSize)) {
        throw const PdfDownloadFailed('fichier reçu invalide');
      }
      await store.adopt(collegeId: arg, version: version, downloaded: part);
      // Le statut local est relu partout (vue collège comprise), même écran quitté.
      ref.invalidate(collegePdfStatusProvider);
      state = const PdfDownloadDone();
    } catch (e) {
      AppLogger.warning('téléchargement du PDF échoué : $e', tag: 'PdfDownloadNotifier');
      state = const PdfDownloadFailedState();
    }
  }
}

final pdfDownloadProvider =
    NotifierProvider.family<PdfDownloadNotifier, PdfDownloadState, String>(PdfDownloadNotifier.new);

/// Statut de la copie locale face à la version serveur ; relu après chaque
/// téléchargement (invalidé par `PdfDownloadNotifier`).
final collegePdfStatusProvider =
    FutureProvider.autoDispose.family<LocalPdfStatus, ({String collegeId, String? version})>((ref, key) async {
  final store = await ref.watch(localPdfStoreProvider.future);
  return store.status(key.collegeId, key.version);
});

/// Empreinte SHA-256 d'un fichier, calculée hors du fil de l'interface (PDF de
/// plusieurs centaines de Mo) ; remplacée en test.
final fileSha256Provider = Provider<Future<String> Function(File)>(
  (ref) => (file) => Isolate.run(() async => (await sha256.bind(file.openRead()).first).toString()),
);

/// Empreinte du PDF en service selon le serveur (null : import trop ancien pour
/// en avoir une) ; remplacée en test.
final pdfFingerprintFetcherProvider = Provider<Future<String?> Function(String collegeId)>((ref) => (collegeId) async {
      final resp = await ref.read(apiClientProvider).get<Map<String, dynamic>>('/v1/colleges/$collegeId/pdf/fingerprint');
      return (resp.data!['data'] as Map<String, dynamic>)['pdf_sha256'] as String?;
    });

sealed class PdfAttachState {
  const PdfAttachState();
}

class PdfAttachIdle extends PdfAttachState {
  const PdfAttachIdle();
}

class PdfAttachChecking extends PdfAttachState {
  const PdfAttachChecking();
}

/// Le fichier choisi n'est pas le PDF importé : ses pages ne correspondraient
/// pas à celles des items.
class PdfAttachMismatch extends PdfAttachState {
  const PdfAttachMismatch();
}

class PdfAttachFailed extends PdfAttachState {
  const PdfAttachFailed();
}

class PdfAttachDone extends PdfAttachState {
  const PdfAttachDone();
}

/// Rattachement d'un PDF choisi sur le téléphone à un collège : le serveur ne
/// garde pas les PDF après la génération (droits des éditeurs), la copie lue
/// est toujours locale. Le fichier n'est accepté que s'il est identique à celui
/// importé (même empreinte), sans rien renvoyer au serveur.
class PdfAttachNotifier extends FamilyNotifier<PdfAttachState, String> {
  @override
  PdfAttachState build(String arg) => const PdfAttachIdle();

  Future<void> start(String version) async {
    if (state is PdfAttachChecking) return;
    final picked = await ref.read(pdfPickerProvider)();
    if (picked == null) return;
    state = const PdfAttachChecking();
    try {
      final (expected, actual) =
          await (ref.read(pdfFingerprintFetcherProvider)(arg), ref.read(fileSha256Provider)(picked.file)).wait;
      if (expected != null && expected != actual) {
        state = const PdfAttachMismatch();
        return;
      }
      final store = await ref.read(localPdfStoreProvider.future);
      await store.keepCopy(collegeId: arg, version: version, source: picked.file);
      ref.invalidate(collegePdfStatusProvider);
      state = const PdfAttachDone();
    } catch (e) {
      AppLogger.warning('rattachement du PDF échoué : $e', tag: 'PdfAttachNotifier');
      state = const PdfAttachFailed();
    }
  }
}

final pdfAttachProvider = NotifierProvider.family<PdfAttachNotifier, PdfAttachState, String>(PdfAttachNotifier.new);
