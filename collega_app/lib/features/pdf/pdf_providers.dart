import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/pdf/data/backup_excluder.dart';
import 'package:collega_app/features/pdf/data/local_pdf_store.dart';
import 'package:collega_app/features/pdf/data/pdf_downloader.dart';

/// Copies locales des PDF (partie B), dans Application Support (jamais purgé par
/// iOS, contrairement aux caches), exclues de la sauvegarde iCloud.
final localPdfStoreProvider = FutureProvider<LocalPdfStore>((ref) async {
  final support = await getApplicationSupportDirectory();
  return LocalPdfStore(Directory(p.join(support.path, 'pdfs')), excluder: const ChannelBackupExcluder());
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

  Future<void> start(String version) async {
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
      await store.adopt(collegeId: arg, version: version, downloaded: part);
      state = const PdfDownloadDone();
    } catch (e) {
      AppLogger.warning('téléchargement du PDF échoué : $e', tag: 'PdfDownloadNotifier');
      state = const PdfDownloadFailedState();
    }
  }
}

final pdfDownloadProvider =
    NotifierProvider.family<PdfDownloadNotifier, PdfDownloadState, String>(PdfDownloadNotifier.new);
