import 'dart:async';

import 'package:background_downloader/background_downloader.dart';

import 'package:collega_app/core/network/cloudflare_access.dart';
import 'package:collega_app/core/upload/part_transport.dart';
import 'package:collega_app/env.dart';

/// Envoi des morceaux en arrière-plan (URLSession background / WorkManager) via background_downloader.
/// Les PUT parts n'ont pas besoin de JWT (upload_id = jeton, cf. spec §3.4) : seuls les headers
/// Cloudflare Access sont joints.
class BackgroundPartTransport implements PartTransport {
  BackgroundPartTransport({FileDownloader? downloader}) : _dl = downloader ?? FileDownloader() {
    _dl.registerCallbacks(
      group: group,
      taskStatusCallback: _onStatus,
      taskProgressCallback: _onProgress,
    );
  }

  static const group = 'college-import';
  final FileDownloader _dl;
  final _events = StreamController<PartEvent>.broadcast();

  static UploadTask buildTask(PartUpload part) {
    return UploadTask(
      taskId: '${part.uploadId}|${part.partIndex}',
      url: '$backendBaseUrl/v1/colleges/import/${part.uploadId}/parts/${part.partIndex}',
      httpRequestMethod: 'PUT',
      post: 'binary',
      baseDirectory: BaseDirectory.root,
      directory: part.file.parent.path,
      filename: part.file.uri.pathSegments.last,
      headers: {
        'Content-Type': 'application/octet-stream',
        ...cloudflareAccessHeaders(clientId: cfAccessClientId, clientSecret: cfAccessClientSecret),
      },
      group: group,
      retries: 3,
      updates: Updates.statusAndProgress,
      metaData: '${part.uploadId}|${part.partIndex}',
    );
  }

  static (String, int) parseMetaData(String metaData) {
    final sep = metaData.lastIndexOf('|');
    return (metaData.substring(0, sep), int.parse(metaData.substring(sep + 1)));
  }

  void _onStatus(TaskStatusUpdate u) {
    final (uploadId, n) = parseMetaData(u.task.metaData);
    switch (u.status) {
      case TaskStatus.complete:
        _events.add(PartDone(uploadId, n));
      case TaskStatus.failed || TaskStatus.notFound || TaskStatus.canceled:
        _events.add(PartFailed(uploadId, n, u.exception ?? u.status));
      default:
        break;
    }
  }

  void _onProgress(TaskProgressUpdate u) {
    if (u.progress < 0) return; // valeurs négatives = états spéciaux du package
    final (uploadId, n) = parseMetaData(u.task.metaData);
    _events.add(PartProgress(uploadId, n, u.progress));
  }

  @override
  Stream<PartEvent> get events => _events.stream;

  @override
  Future<void> enqueue(PartUpload part) async {
    final ok = await _dl.enqueue(buildTask(part));
    if (!ok) _events.add(PartFailed(part.uploadId, part.partIndex, StateError('enqueue refused')));
  }

  static const _activeStatuses = {
    TaskStatus.enqueued,
    TaskStatus.running,
    TaskStatus.paused,
    TaskStatus.waitingToRetry,
  };

  @override
  Future<Set<int>> queued(String uploadId) async {
    final records = await _dl.database.allRecords(group: group);
    return {
      for (final r in records)
        if (r.task.metaData.startsWith('$uploadId|') && _activeStatuses.contains(r.status))
          parseMetaData(r.task.metaData).$2,
    };
  }

  @override
  Future<void> cancelAll(String uploadId) async {
    final records = await _dl.database.allRecords(group: group);
    final ids = [for (final r in records) if (r.task.metaData.startsWith('$uploadId|')) r.taskId];
    if (ids.isNotEmpty) await _dl.cancelTasksWithIds(ids);
  }
}
