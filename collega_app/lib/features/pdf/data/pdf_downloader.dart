import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

import 'package:collega_app/core/network/cloudflare_access.dart';
import 'package:collega_app/env.dart';

class PdfDownloadFailed implements Exception {
  const PdfDownloadFailed(this.reason);
  final Object reason;

  @override
  String toString() => 'PdfDownloadFailed($reason)';
}

/// Télécharge le PDF en service d'un collège dans [into] (fichier `.part`).
abstract interface class PdfDownloader {
  Future<File> download({
    required String collegeId,
    required String version,
    required Directory into,
    required void Function(double) onProgress,
  });
}

/// URLSession d'arrière-plan (background_downloader, comme l'envoi) : le
/// téléchargement continue si on quitte l'écran ou l'app.
class BackgroundPdfDownloader implements PdfDownloader {
  BackgroundPdfDownloader({required this.accessToken, FileDownloader? downloader})
      : _dl = downloader ?? FileDownloader();

  /// Jeton d'accès frais (lu juste avant la requête).
  final Future<String> Function() accessToken;
  final FileDownloader _dl;

  static const group = 'college-pdf';

  @override
  Future<File> download({
    required String collegeId,
    required String version,
    required Directory into,
    required void Function(double) onProgress,
  }) async {
    await into.create(recursive: true);
    final filename = '${collegeId}_$version.pdf.part';
    // Répertoire relatif à Application Support : le chemin absolu du conteneur
    // iOS change d'un lancement à l'autre.
    final (baseDirectory, directory, _) = await Task.split(filePath: '${into.path}/$filename');
    final task = DownloadTask(
      taskId: '$collegeId|$version',
      url: '$backendBaseUrl/v1/colleges/$collegeId/pdf',
      baseDirectory: baseDirectory,
      directory: directory,
      filename: filename,
      headers: {
        'Authorization': 'Bearer ${await accessToken()}',
        ...cloudflareAccessHeaders(clientId: cfAccessClientId, clientSecret: cfAccessClientSecret),
      },
      group: group,
      retries: 3,
      allowPause: true,
      updates: Updates.statusAndProgress,
    );
    final result = await _dl.download(task, onProgress: (p) {
      if (p >= 0) onProgress(p);
    });
    final file = File('${into.path}/$filename');
    if (result.status != TaskStatus.complete || !await file.exists()) {
      if (await file.exists()) await file.delete();
      throw PdfDownloadFailed(result.exception ?? result.status);
    }
    return file;
  }
}
