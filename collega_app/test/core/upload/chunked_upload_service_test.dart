import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/upload/chunked_upload_service.dart';
import 'package:collega_app/core/upload/part_transport.dart';
import 'package:collega_app/core/upload/upload_api.dart';
import 'package:collega_app/core/upload/upload_models.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

class _FakeApi implements UploadApi {
  _FakeApi({this.received = const [], this.statusError});
  final List<int> received;
  final Exception? statusError;
  int initCalls = 0, completeCalls = 0;

  @override
  Future<UploadInitResponse> init(int refId, int sizeBytes) async {
    initCalls++;
    return UploadInitResponse(
      uploadId: 'u1',
      partSize: 10,
      partsTotal: (sizeBytes + 9) ~/ 10,
      expiresAt: DateTime.utc(2027),
    );
  }

  @override
  Future<UploadStatusResponse> status(String uploadId) async {
    if (statusError != null) throw statusError!;
    return UploadStatusResponse(received: received, partsTotal: 3, partSize: 10, sizeBytes: 25);
  }

  @override
  Future<ImportStartResponse> complete(String uploadId) async {
    completeCalls++;
    return const ImportStartResponse(collegeId: 'c', jobId: 'j', status: 'pending');
  }
}

Future<(ChunkedUploadService, AppDatabase, File, InMemoryPartTransport, _FakeApi)> _setup({
  List<int> received = const [],
  Set<int> failing = const {},
  Exception? statusError,
}) async {
  final dir = await Directory.systemTemp.createTemp('cus');
  addTearDown(() => dir.delete(recursive: true));
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final api = _FakeApi(received: received, statusError: statusError);
  final transport = InMemoryPartTransport(failing: failing);
  final src = File('${dir.path}/src.pdf')..writeAsBytesSync(List.filled(25, 0x25));
  final svc = ChunkedUploadService(api: api, transport: transport, db: db, cacheDir: dir);
  return (svc, db, src, transport, api);
}

PendingUploadsCompanion _pending(File src) => PendingUploadsCompanion.insert(
      uploadId: 'u1',
      refId: 3,
      filePath: src.path,
      sizeBytes: 25,
      partSize: 10,
      partsTotal: 3,
      createdAt: DateTime.now(),
    );

void main() {
  test('upload : init → pending_uploads → 3 morceaux → complete → ligne supprimée', () async {
    final (svc, db, src, transport, api) = await _setup();
    final progress = <double>[];

    final r = await svc.upload(3, src, onProgress: progress.add);

    expect(r.collegeId, 'c');
    expect(transport.enqueued.map((p) => p.partIndex), [0, 1, 2]);
    expect(api.completeCalls, 1);
    expect(progress.last, 1.0);
    expect(await db.select(db.pendingUploads).get(), isEmpty);
    expect(Directory('${svc.cacheDir.path}/parts_u1').existsSync(), isFalse);
  });

  test('upload : un morceau en échec → PartUploadFailed, ligne pending conservée', () async {
    final (svc, db, src, _, api) = await _setup(failing: {1});
    await expectLater(svc.upload(3, src), throwsA(isA<PartUploadFailed>()));
    expect(api.completeCalls, 0);
    expect((await db.select(db.pendingUploads).get()).single.uploadId, 'u1');
  });

  test('resume : ne renvoie que les morceaux manquants puis complete', () async {
    final (svc, db, src, transport, api) = await _setup(received: [0, 2]);
    await db.into(db.pendingUploads).insert(_pending(src));

    final r = await svc.resume();

    expect(r?.jobId, 'j');
    expect(transport.enqueued.map((p) => p.partIndex), [1]);
    expect(api.initCalls, 0);
    expect(await db.select(db.pendingUploads).get(), isEmpty);
  });

  test('resume : tout déjà reçu → complete direct sans enqueue', () async {
    final (svc, db, src, transport, api) = await _setup(received: [0, 1, 2]);
    await db.into(db.pendingUploads).insert(_pending(src));

    final r = await svc.resume();

    expect(r?.jobId, 'j');
    expect(transport.enqueued, isEmpty);
    expect(api.completeCalls, 1);
  });

  test('resume : upload expiré → UploadExpiredException et ligne supprimée', () async {
    final (svc, db, src, _, _) = await _setup(statusError: const UploadExpiredException());
    await db.into(db.pendingUploads).insert(_pending(src));

    await expectLater(svc.resume(), throwsA(isA<UploadExpiredException>()));

    expect(await db.select(db.pendingUploads).get(), isEmpty);
  });

  test('resume : fichier source disparu → ligne supprimée, UploadSourceMissing', () async {
    final (svc, db, src, _, _) = await _setup();
    await db.into(db.pendingUploads).insert(_pending(src));
    src.deleteSync();

    await expectLater(svc.resume(), throwsA(isA<UploadSourceMissing>()));

    expect(await db.select(db.pendingUploads).get(), isEmpty);
  });

  test('resume sans ligne → null', () async {
    final (svc, _, _, _, _) = await _setup();
    expect(await svc.resume(), isNull);
  });

  test('hasPending reflète la table', () async {
    final (svc, db, src, _, _) = await _setup();
    expect(await svc.hasPending(), isFalse);
    await db.into(db.pendingUploads).insert(_pending(src));
    expect(await svc.hasPending(), isTrue);
  });
}
