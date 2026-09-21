import 'dart:async';
import 'dart:io';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/upload/part_splitter.dart';
import 'package:collega_app/core/upload/part_transport.dart';
import 'package:collega_app/core/upload/upload_api.dart';
import 'package:collega_app/core/upload/upload_models.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

/// Un morceau n'a pas pu être envoyé (après les retries du transport).
class PartUploadFailed implements Exception {
  const PartUploadFailed(this.partIndex, this.error);
  final int partIndex;
  final Object error;

  @override
  String toString() => 'PartUploadFailed(part $partIndex: $error)';
}

/// La copie locale du PDF d'un upload en attente a disparu : reprise impossible.
class UploadSourceMissing implements Exception {
  const UploadSourceMissing(this.path);
  final String path;
}

/// Mène un PDF de `init` à `complete` par morceaux, avec reprise via `pending_uploads` (Story 7.11).
class ChunkedUploadService {
  ChunkedUploadService({
    required this.api,
    required this.transport,
    required this.db,
    required this.cacheDir,
  });

  final UploadApi api;
  final PartTransport transport;
  final AppDatabase db;
  final Directory cacheDir;

  /// Au-delà, l'import passe par morceaux (Cloudflare : 100 MB max par requête).
  static const int chunkThreshold = 90 * 1024 * 1024;

  /// Limite backend (`_MAX_PDF_SIZE`).
  static const int maxSize = 500 * 1024 * 1024;

  Future<bool> hasPending() async => (await db.select(db.pendingUploads).get()).isNotEmpty;

  /// init → pending_uploads → morceaux → complete. [onProgress] ∈ [0, 1].
  Future<ImportStartResponse> upload(int refId, File file, {void Function(double)? onProgress}) async {
    final size = await file.length();
    final init = await api.init(refId, size);
    await db.into(db.pendingUploads).insertOnConflictUpdate(PendingUploadsCompanion.insert(
          uploadId: init.uploadId,
          refId: refId,
          filePath: file.path,
          sizeBytes: size,
          partSize: init.partSize,
          partsTotal: init.partsTotal,
          createdAt: DateTime.now().toUtc(),
        ));
    return _send(init.uploadId, file, init.partSize, init.partsTotal, {}, onProgress);
  }

  /// Reprend la ligne `pending_uploads` s'il y en a une ; null sinon.
  Future<ImportStartResponse?> resume({void Function(double)? onProgress}) async {
    final rows = await db.select(db.pendingUploads).get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    final file = File(row.filePath);
    if (!await file.exists()) {
      await _forget(row.uploadId);
      throw UploadSourceMissing(row.filePath);
    }
    final Set<int> received;
    try {
      received = (await api.status(row.uploadId)).received.toSet();
    } on UploadExpiredException {
      await _forget(row.uploadId);
      rethrow;
    }
    return _send(row.uploadId, file, row.partSize, row.partsTotal, received, onProgress);
  }

  Future<ImportStartResponse> _send(
    String uploadId,
    File file,
    int partSize,
    int partsTotal,
    Set<int> received,
    void Function(double)? onProgress,
  ) async {
    final missing = {for (var n = 0; n < partsTotal; n++) if (!received.contains(n)) n};
    final alreadyQueued = await transport.queued(uploadId);
    final toSend = missing.difference(alreadyQueued);
    final fractions = <int, double>{for (final n in received) n: 1.0};
    void report() => onProgress?.call(fractions.values.fold(0.0, (a, b) => a + b) / partsTotal);
    report();

    final pending = Set<int>.from(missing);
    final done = Completer<void>();
    final sub = transport.events.where((e) => e.uploadId == uploadId).listen((e) {
      switch (e) {
        case PartProgress(:final partIndex, :final fraction):
          fractions[partIndex] = fraction;
          report();
        case PartDone(:final partIndex):
          fractions[partIndex] = 1.0;
          pending.remove(partIndex);
          report();
          if (pending.isEmpty && !done.isCompleted) done.complete();
        case PartFailed(:final partIndex, :final error):
          if (!done.isCompleted) done.completeError(PartUploadFailed(partIndex, error));
      }
    });
    try {
      if (toSend.isNotEmpty) {
        final parts = await PartSplitter.split(
          file,
          partSize,
          Directory('${cacheDir.path}/parts_$uploadId'),
          only: toSend,
        );
        for (final f in parts) {
          final n = int.parse(f.path.split('_').last);
          await transport.enqueue(PartUpload(uploadId: uploadId, partIndex: n, file: f));
        }
      }
      if (pending.isNotEmpty) await done.future;
    } finally {
      await sub.cancel();
    }

    final result = await api.complete(uploadId);
    await _forget(uploadId);
    onProgress?.call(1.0);
    return result;
  }

  Future<void> _forget(String uploadId) async {
    await (db.delete(db.pendingUploads)..where((t) => t.uploadId.equals(uploadId))).go();
    final dir = Directory('${cacheDir.path}/parts_$uploadId');
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (e) {
        AppLogger.warning('parts cleanup failed: $e', tag: 'ChunkedUploadService');
      }
    }
  }
}
