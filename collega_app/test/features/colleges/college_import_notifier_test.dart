import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_client.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/upload/chunked_upload_service.dart';
import 'package:collega_app/core/upload/part_transport.dart';
import 'package:collega_app/core/upload/upload_api.dart';
import 'package:collega_app/core/upload/upload_models.dart';
import 'package:collega_app/core/upload/upload_providers.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/college_import_repository.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

class _FakeCollegeImportRepository extends CollegeImportRepository {
  _FakeCollegeImportRepository({
    this.importResult,
    this.throwOnImport,
    this.statusOverride,
  }) : super(dio: Dio());

  final ImportStartResponse? importResult;
  final Exception? throwOnImport;
  final CollegeStatusResponse? statusOverride;
  int statusCalls = 0;

  @override
  Future<ImportStartResponse> importPdf(int refId, File pdfFile) async {
    if (throwOnImport != null) throw throwOnImport!;
    return importResult!;
  }

  @override
  Future<CollegeStatusResponse> getStatus(String collegeId) async {
    statusCalls++;
    return statusOverride ??
        CollegeStatusResponse(
          collegeId: collegeId,
          refId: 15,
          status: 'pending',
          ocrProgress: 0,
        );
  }
}

/// Fake `ApiClient` qui trace les appels à `ensureFreshAccessToken()` pour
/// vérifier que `_connectSse` les déclenche bien avant l'ouverture SSE
/// (Story 7.2 AC #5).
class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.refreshResult = true})
      : super(const FlutterSecureStorage());

  final bool refreshResult;
  int refreshCalls = 0;

  @override
  Future<bool> ensureFreshAccessToken() async {
    refreshCalls += 1;
    return refreshResult;
  }
}

AppDatabase _makeInMemoryDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

/// `File` dont seul `length()` est implémenté — évite d'écrire 90+ MB sur disque en test.
class _SizedFile implements File {
  _SizedFile(this.path, this.size);
  @override
  final String path;
  final int size;

  @override
  Future<int> length() async => size;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _NoopUploadApi implements UploadApi {
  @override
  Future<UploadInitResponse> init(int refId, int sizeBytes) => throw UnimplementedError();
  @override
  Future<UploadStatusResponse> status(String uploadId) => throw UnimplementedError();
  @override
  Future<ImportStartResponse> complete(String uploadId) => throw UnimplementedError();
}

/// Service d'upload par morceaux factice : compte les appels et simule la progression.
class _FakeChunkedUploadService extends ChunkedUploadService {
  _FakeChunkedUploadService({required super.db, required super.cacheDir, this.pending = false, this.uploadError})
      : super(api: _NoopUploadApi(), transport: InMemoryPartTransport());

  final bool pending;
  final Exception? uploadError;
  int uploadCalls = 0, resumeCalls = 0;

  @override
  Future<bool> hasPending() async => pending;

  @override
  Future<ImportStartResponse> upload(int refId, File file, {void Function(double)? onProgress}) async {
    uploadCalls++;
    if (uploadError != null) throw uploadError!;
    onProgress?.call(0.5);
    onProgress?.call(1);
    return const ImportStartResponse(collegeId: 'c', jobId: 'j', status: 'pending');
  }

  @override
  Future<ImportStartResponse?> resume({void Function(double)? onProgress}) async {
    resumeCalls++;
    if (!pending) return null;
    onProgress?.call(0.5);
    onProgress?.call(1);
    return const ImportStartResponse(collegeId: 'c', jobId: 'j', status: 'pending');
  }
}

Future<_FakeChunkedUploadService> _makeFakeChunkedService(AppDatabase db, {bool pending = false, Exception? uploadError}) async {
  final dir = await Directory.systemTemp.createTemp('notif');
  addTearDown(() => dir.delete(recursive: true));
  if (pending) {
    await db.into(db.pendingUploads).insert(PendingUploadsCompanion.insert(
          uploadId: 'u1', refId: 15, filePath: '${dir.path}/x.pdf', sizeBytes: 25, partSize: 10, partsTotal: 3,
          createdAt: DateTime.now(),
        ));
  }
  return _FakeChunkedUploadService(db: db, cacheDir: dir, pending: pending, uploadError: uploadError);
}

class _CountingColleges extends CollegesNotifier {
  static int builds = 0;
  @override
  Future<List<CollegeListEntry>> build() async {
    builds++;
    return const [];
  }
}

ProviderContainer _makeContainer(
  _FakeCollegeImportRepository repo, {
  _FakeApiClient? apiClient,
  AppDatabase? db,
  ChunkedUploadService? chunked,
}) {
  return ProviderContainer(
    overrides: [
      collegeImportRepositoryProvider.overrideWithValue(repo),
      secureStorageProvider.overrideWithValue(const FlutterSecureStorage()),
      databaseProvider.overrideWithValue(db ?? _makeInMemoryDb()),
      if (apiClient != null) apiClientProvider.overrideWithValue(apiClient),
      if (chunked != null) chunkedUploadServiceProvider.overrideWith((ref) async => chunked),
    ],
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Stub du channel flutter_secure_storage pour éviter les appels plateforme en test
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  group('CollegeImportNotifier', () {
    test('startImport success → passe par ImportUploading puis ImportStreaming', () async {
      final repo = _FakeCollegeImportRepository(
        importResult: const ImportStartResponse(
          collegeId: 'college-uuid-15',
          jobId: 'job-uuid-1',
          status: 'pending',
        ),
      );
      // P1 (review patch) : _connectSse exige un refresh OK pour rester en
      // ImportStreaming — sinon transition vers ImportError(session_expired).
      // L'apiClient par défaut n'a pas de backend → on injecte un fake OK.
      final container = _makeContainer(repo, apiClient: _FakeApiClient());
      addTearDown(container.dispose);

      final states = <CollegeImportState>[];
      container.listen<AsyncValue<CollegeImportState>>(
        collegeImportProvider,
        (_, next) {
          if (next.valueOrNull != null) states.add(next.value!);
        },
      );

      final tmpFile = File('${Directory.systemTemp.path}/test.pdf');
      tmpFile.writeAsBytesSync([0x25, 0x50, 0x44, 0x46, 0x2D]);

      await container.read(collegeImportProvider.notifier).startImport(15, tmpFile);

      expect(states.any((s) => s is ImportUploading), isTrue);
      final lastState = states.last;
      expect(lastState, isA<ImportStreaming>());
      if (lastState is ImportStreaming) {
        expect(lastState.collegeId, 'college-uuid-15');
        expect(lastState.jobId, 'job-uuid-1');
      }

      tmpFile.deleteSync();
    });

    test('startImport avec 403 → état ImportError subscription_required', () async {
      final repo = _FakeCollegeImportRepository(
        throwOnImport: const SubscriptionRequiredException(),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final tmpFile = File('${Directory.systemTemp.path}/test403.pdf');
      tmpFile.writeAsBytesSync([0x25, 0x50, 0x44, 0x46, 0x2D]);

      await container.read(collegeImportProvider.notifier).startImport(15, tmpFile);

      final state = container.read(collegeImportProvider).valueOrNull;
      expect(state, isA<ImportError>());
      if (state is ImportError) {
        expect(state.message, 'subscription_required');
      }

      tmpFile.deleteSync();
    });

    test('startImport avec 409 → état ImportError job_in_progress', () async {
      final repo = _FakeCollegeImportRepository(
        throwOnImport: const JobInProgressException(),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final tmpFile = File('${Directory.systemTemp.path}/test409.pdf');
      tmpFile.writeAsBytesSync([0x25, 0x50, 0x44, 0x46, 0x2D]);

      await container.read(collegeImportProvider.notifier).startImport(15, tmpFile);

      final state = container.read(collegeImportProvider).valueOrNull;
      expect(state, isA<ImportError>());
      if (state is ImportError) {
        expect(state.message, 'job_in_progress');
      }

      tmpFile.deleteSync();
    });

    test(
      'startImport déclenche ensureFreshAccessToken AVANT _connectSse (AC #5)',
      () async {
        final repo = _FakeCollegeImportRepository(
          importResult: const ImportStartResponse(
            collegeId: 'college-uuid-15',
            jobId: 'job-uuid-1',
            status: 'pending',
          ),
        );
        final apiClient = _FakeApiClient();
        final container = _makeContainer(repo, apiClient: apiClient);
        addTearDown(container.dispose);

        final tmpFile = File('${Directory.systemTemp.path}/test_refresh.pdf');
        tmpFile.writeAsBytesSync([0x25, 0x50, 0x44, 0x46, 0x2D]);

        await container.read(collegeImportProvider.notifier).startImport(15, tmpFile);

        // _connectSse a été appelé en interne → refresh a été déclenché 1x
        expect(apiClient.refreshCalls, 1);

        tmpFile.deleteSync();
      },
    );

    test(
      'reconnectIfActive sur status pending → refresh JWT puis connect SSE',
      () async {
        final repo = _FakeCollegeImportRepository(
          statusOverride: CollegeStatusResponse(
            collegeId: 'college-uuid-15',
            refId: 15,
            status: 'pending',
            ocrProgress: 2,
          ),
        );
        final apiClient = _FakeApiClient();
        final container = _makeContainer(repo, apiClient: apiClient);
        addTearDown(container.dispose);

        await container
            .read(collegeImportProvider.notifier)
            .reconnectIfActive('college-uuid-15');

        expect(apiClient.refreshCalls, 1);
        final state = container.read(collegeImportProvider).valueOrNull;
        expect(state, isA<ImportStreaming>());
      },
    );

    test(
      'reconnectIfActive avec refresh échoué → pas de connexion SSE',
      () async {
        final repo = _FakeCollegeImportRepository(
          statusOverride: CollegeStatusResponse(
            collegeId: 'college-uuid-15',
            refId: 15,
            status: 'pending',
            ocrProgress: 0,
          ),
        );
        final apiClient = _FakeApiClient(refreshResult: false);
        final container = _makeContainer(repo, apiClient: apiClient);
        addTearDown(container.dispose);

        await container
            .read(collegeImportProvider.notifier)
            .reconnectIfActive('college-uuid-15');

        // refresh tenté
        expect(apiClient.refreshCalls, 1);
        // P1 (review patch) : transition vers ImportError(session_expired) au
        // lieu de rester silencieusement bloqué en ImportStreaming.
        final state = container.read(collegeImportProvider).valueOrNull;
        expect(state, isA<ImportError>());
        if (state is ImportError) {
          expect(state.message, 'session_expired');
        }
      },
    );

    test(
      'reconnectIfActive sur status generation_complete → pas de refresh SSE',
      () async {
        final repo = _FakeCollegeImportRepository(
          statusOverride: CollegeStatusResponse(
            collegeId: 'college-uuid-15',
            refId: 15,
            status: 'generation_complete',
            ocrProgress: 0,
          ),
        );
        final apiClient = _FakeApiClient();
        final container = _makeContainer(repo, apiClient: apiClient);
        addTearDown(container.dispose);

        await container
            .read(collegeImportProvider.notifier)
            .reconnectIfActive('college-uuid-15');

        // Pas de _connectSse appelé → refresh non déclenché
        expect(apiClient.refreshCalls, 0);
      },
    );
    test(
      'import (ou réimport) terminé → les nouvelles fiches du collège arrivent dans Drift (revue 8.7)',
      () async {
        final repo = _FakeCollegeImportRepository(
          statusOverride: CollegeStatusResponse(
            collegeId: 'college-uuid-15',
            refId: 15,
            status: 'generation_complete',
            ocrProgress: 0,
          ),
        );
        final db = _makeInMemoryDb();
        addTearDown(db.close);
        final fetched = Completer<void>();
        final container = ProviderContainer(
          overrides: [
            collegeImportRepositoryProvider.overrideWithValue(repo),
            secureStorageProvider.overrideWithValue(const FlutterSecureStorage()),
            databaseProvider.overrideWithValue(db),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
            collegeCardsFetcherProvider.overrideWithValue((id) async {
              if (!fetched.isCompleted) scheduleMicrotask(fetched.complete);
              return [
                FlashCardModel(
                  id: 'new-1', itemId: 'i1', collegeId: id, cardType: 'qa', rang: 'A',
                  recto: 'Q', verso: 'R', ocrConfidenceScore: 0.9, lowConfidence: false,
                ),
              ];
            }),
          ],
        );
        addTearDown(container.dispose);

        await container.read(collegeImportProvider.notifier).reconnectIfActive('college-uuid-15');
        await fetched.future;
        await pumpEventQueue();
        final ids = (await db.select(db.flashCards).get()).map((c) => c.id);
        expect(ids, ['new-1']);
        expect(container.read(collegeDataVersionProvider('college-uuid-15')), 1,
            reason: 'le détail ouvert se recharge');
      },
    );
    test(
      'reconnectIfActive sur status ocr_complete (génération en cours) → reconnecte SSE',
      () async {
        // Régression : la phase de génération Claude est la plus longue et
        // silencieuse ; un retour au premier plan pendant cette phase doit
        // reprendre le stream, pas laisser l'écran figé.
        final repo = _FakeCollegeImportRepository(
          statusOverride: CollegeStatusResponse(
            collegeId: 'college-uuid-15',
            refId: 15,
            status: 'ocr_complete',
            ocrProgress: 355,
            totalPages: 355,
          ),
        );
        final apiClient = _FakeApiClient();
        final container = _makeContainer(repo, apiClient: apiClient);
        addTearDown(container.dispose);

        await container
            .read(collegeImportProvider.notifier)
            .reconnectIfActive('college-uuid-15');

        expect(apiClient.refreshCalls, 1);
        final state = container.read(collegeImportProvider).valueOrNull;
        expect(state, isA<ImportStreaming>());
        if (state is ImportStreaming) {
          expect(state.status, 'ocr_complete');
          expect(state.ocrProgress, 355);
        }
      },
    );

    test(
      'reconnectIfActive sur status failed → ImportError generation_failed',
      () async {
        final repo = _FakeCollegeImportRepository(
          statusOverride: CollegeStatusResponse(
            collegeId: 'college-uuid-15',
            refId: 15,
            status: 'failed',
            ocrProgress: 0,
          ),
        );
        final apiClient = _FakeApiClient();
        final container = _makeContainer(repo, apiClient: apiClient);
        addTearDown(container.dispose);

        await container
            .read(collegeImportProvider.notifier)
            .reconnectIfActive('college-uuid-15');

        expect(apiClient.refreshCalls, 0);
        final state = container.read(collegeImportProvider).valueOrNull;
        expect(state, isA<ImportError>());
        if (state is ImportError) expect(state.message, 'generation_failed');
      },
    );

    test(
      'stream SSE coupé pendant ImportStreaming → re-sync via /status automatique',
      () async {
        // Cloudflare coupe une connexion SSE silencieuse (~100 s) : sans
        // reconnexion l'app reste bloquée en ImportStreaming alors que le
        // backend a terminé. Ici le stream échoue immédiatement (pas de
        // backend en test) et /status répond generation_complete.
        final repo = _FakeCollegeImportRepository(
          importResult: const ImportStartResponse(
            collegeId: 'college-uuid-15',
            jobId: 'job-uuid-1',
            status: 'pending',
          ),
          statusOverride: CollegeStatusResponse(
            collegeId: 'college-uuid-15',
            refId: 15,
            status: 'generation_complete',
            ocrProgress: 355,
            totalPages: 355,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            collegeImportRepositoryProvider.overrideWithValue(repo),
            secureStorageProvider.overrideWithValue(const FlutterSecureStorage()),
            databaseProvider.overrideWithValue(_makeInMemoryDb()),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
            sseReconnectDelayProvider.overrideWithValue(Duration.zero),
          ],
        );
        addTearDown(container.dispose);

        final completed = Completer<void>();
        container.listen<AsyncValue<CollegeImportState>>(
          collegeImportProvider,
          (_, next) {
            if (next.valueOrNull is ImportComplete && !completed.isCompleted) {
              completed.complete();
            }
          },
        );

        final tmpFile = File('${Directory.systemTemp.path}/test-sse-cut.pdf');
        tmpFile.writeAsBytesSync([0x25, 0x50, 0x44, 0x46, 0x2D]);
        addTearDown(tmpFile.deleteSync);

        await container.read(collegeImportProvider.notifier).startImport(15, tmpFile);

        await completed.future.timeout(const Duration(seconds: 15));
        expect(container.read(collegeImportProvider).valueOrNull, isA<ImportComplete>());
      },
    );
    test(
      'reconnectIfActive appelé N fois en parallèle → UN seul /status et UN seul refresh',
      () async {
        // Régression prod 2026-09-21 : N écrans empilés rappelaient reconnectIfActive au
        // même onResume → N GET /status + N streams SSE → pool DB épuisé côté backend.
        final repo = _FakeCollegeImportRepository(
          statusOverride: CollegeStatusResponse(
            collegeId: 'college-uuid-15', refId: 15, status: 'processing', ocrProgress: 5,
          ),
        );
        final apiClient = _FakeApiClient();
        final container = _makeContainer(repo, apiClient: apiClient);
        addTearDown(container.dispose);
        final notifier = container.read(collegeImportProvider.notifier);

        await Future.wait([
          notifier.reconnectIfActive('college-uuid-15'),
          notifier.reconnectIfActive('college-uuid-15'),
          notifier.reconnectIfActive('college-uuid-15'),
        ]);

        expect(repo.statusCalls, 1);
        expect(apiClient.refreshCalls, 1);
        expect(container.read(collegeImportProvider).valueOrNull, isA<ImportStreaming>());
      },
    );

    test('startImport > 500 MB → ImportError file_too_large sans appel réseau', () async {
      final repo = _FakeCollegeImportRepository();
      final container = _makeContainer(repo, apiClient: _FakeApiClient());
      addTearDown(container.dispose);
      final big = _SizedFile('${Directory.systemTemp.path}/big.pdf', 500 * 1024 * 1024 + 1);

      await container.read(collegeImportProvider.future);
      await container.read(collegeImportProvider.notifier).startImport(15, big);

      final state = container.read(collegeImportProvider).valueOrNull;
      expect(state, isA<ImportError>());
      expect((state as ImportError).message, 'file_too_large');
    });

    test('startImport > 90 MB → passe par ChunkedUploadService (progression) puis ImportStreaming', () async {
      final repo = _FakeCollegeImportRepository();
      final db = _makeInMemoryDb();
      final fakeSvc = await _makeFakeChunkedService(db);
      final container = _makeContainer(repo, apiClient: _FakeApiClient(), db: db, chunked: fakeSvc);
      addTearDown(container.dispose);
      final big = _SizedFile('${Directory.systemTemp.path}/mid.pdf', 90 * 1024 * 1024 + 1);
      final states = <CollegeImportState>[];
      container.listen<AsyncValue<CollegeImportState>>(collegeImportProvider, (_, n) {
        if (n.valueOrNull != null) states.add(n.value!);
      });

      await container.read(collegeImportProvider.future);
      await container.read(collegeImportProvider.notifier).startImport(15, big);

      expect(states.whereType<ImportUploading>().map((s) => s.progress), containsAll([0.5, 1.0]));
      expect(states.last, isA<ImportStreaming>());
      expect(fakeSvc.uploadCalls, 1);
      expect((await db.select(db.collegeImports).get()).single.jobId, 'j');
    });

    test('startImport ≤ 90 MB → chemin mono-requête, service par morceaux non appelé', () async {
      final repo = _FakeCollegeImportRepository(
        importResult: const ImportStartResponse(collegeId: 'c', jobId: 'j', status: 'pending'),
      );
      final db = _makeInMemoryDb();
      final fakeSvc = await _makeFakeChunkedService(db);
      final container = _makeContainer(repo, apiClient: _FakeApiClient(), db: db, chunked: fakeSvc);
      addTearDown(container.dispose);
      final small = _SizedFile('${Directory.systemTemp.path}/small.pdf', 90 * 1024 * 1024);

      await container.read(collegeImportProvider.future);
      await container.read(collegeImportProvider.notifier).startImport(15, small);

      expect(fakeSvc.uploadCalls, 0);
      expect(container.read(collegeImportProvider).valueOrNull, isA<ImportStreaming>());
    });

    test('startImport avec pending_uploads existant → upload_in_progress', () async {
      final repo = _FakeCollegeImportRepository();
      final db = _makeInMemoryDb();
      final fakeSvc = await _makeFakeChunkedService(db, pending: true);
      final container = _makeContainer(repo, apiClient: _FakeApiClient(), db: db, chunked: fakeSvc);
      addTearDown(container.dispose);
      final big = _SizedFile('${Directory.systemTemp.path}/mid2.pdf', 90 * 1024 * 1024 + 1);

      await container.read(collegeImportProvider.future);
      await container.read(collegeImportProvider.notifier).startImport(15, big);

      expect((container.read(collegeImportProvider).valueOrNull as ImportError).message, 'upload_in_progress');
      expect(fakeSvc.uploadCalls, 0);
    });

    test('startImport par morceaux : PartUploadFailed → upload_failed', () async {
      final repo = _FakeCollegeImportRepository();
      final db = _makeInMemoryDb();
      final fakeSvc = await _makeFakeChunkedService(db, uploadError: const PartUploadFailed(2, 'boom'));
      final container = _makeContainer(repo, apiClient: _FakeApiClient(), db: db, chunked: fakeSvc);
      addTearDown(container.dispose);
      final big = _SizedFile('${Directory.systemTemp.path}/mid3.pdf', 90 * 1024 * 1024 + 1);

      await container.read(collegeImportProvider.future);
      await container.read(collegeImportProvider.notifier).startImport(15, big);

      expect((container.read(collegeImportProvider).valueOrNull as ImportError).message, 'upload_failed');
    });

    test('startImport par morceaux : 413 → file_too_large', () async {
      final repo = _FakeCollegeImportRepository();
      final db = _makeInMemoryDb();
      final fakeSvc = await _makeFakeChunkedService(db, uploadError: const FileTooLargeException());
      final container = _makeContainer(repo, apiClient: _FakeApiClient(), db: db, chunked: fakeSvc);
      addTearDown(container.dispose);
      final big = _SizedFile('${Directory.systemTemp.path}/mid4.pdf', 90 * 1024 * 1024 + 1);

      await container.read(collegeImportProvider.future);
      await container.read(collegeImportProvider.notifier).startImport(15, big);

      expect((container.read(collegeImportProvider).valueOrNull as ImportError).message, 'file_too_large');
    });

    test('resumePendingUpload : reprise → ImportStreaming avec le refId de la ligne', () async {
      final repo = _FakeCollegeImportRepository();
      final db = _makeInMemoryDb();
      final fakeSvc = await _makeFakeChunkedService(db, pending: true);
      final container = _makeContainer(repo, apiClient: _FakeApiClient(), db: db, chunked: fakeSvc);
      addTearDown(container.dispose);

      await container.read(collegeImportProvider.future);
      await container.read(collegeImportProvider.notifier).resumePendingUpload();

      expect(container.read(collegeImportProvider).valueOrNull, isA<ImportStreaming>());
      expect(fakeSvc.resumeCalls, 1);
      expect((await db.select(db.collegeImports).get()).single.refId, 15);
    });

    test('envoi accepté → la Bibliothèque se recharge (le collège existe côté serveur)', () async {
      final repo = _FakeCollegeImportRepository();
      final db = _makeInMemoryDb();
      final fakeSvc = await _makeFakeChunkedService(db, pending: true);
      _CountingColleges.builds = 0;
      final container = ProviderContainer(overrides: [
        collegeImportRepositoryProvider.overrideWithValue(repo),
        secureStorageProvider.overrideWithValue(const FlutterSecureStorage()),
        databaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(_FakeApiClient()),
        chunkedUploadServiceProvider.overrideWith((ref) async => fakeSvc),
        collegesProvider.overrideWith(_CountingColleges.new),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(collegesProvider, (_, __) {});
      addTearDown(sub.close);
      await container.read(collegesProvider.future);
      expect(_CountingColleges.builds, 1);

      await container.read(collegeImportProvider.future);
      await container.read(collegeImportProvider.notifier).resumePendingUpload();
      await container.read(collegesProvider.future);

      expect(_CountingColleges.builds, 2);
    });

    test('resumePendingUpload sans ligne → état inchangé, resume non appelé', () async {
      final repo = _FakeCollegeImportRepository();
      final db = _makeInMemoryDb();
      final fakeSvc = await _makeFakeChunkedService(db);
      final container = _makeContainer(repo, apiClient: _FakeApiClient(), db: db, chunked: fakeSvc);
      addTearDown(container.dispose);

      await container.read(collegeImportProvider.future);
      await container.read(collegeImportProvider.notifier).resumePendingUpload();

      expect(container.read(collegeImportProvider).valueOrNull, isA<ImportIdle>());
      expect(fakeSvc.resumeCalls, 0);
    });

    test('reset() ne coupe pas un upload par morceaux en cours', () async {
      final repo = _FakeCollegeImportRepository();
      final container = _makeContainer(repo, apiClient: _FakeApiClient());
      addTearDown(container.dispose);
      final notifier = container.read(collegeImportProvider.notifier);
      await container.read(collegeImportProvider.future);

      notifier.debugSetState(const ImportUploading(progress: 0.3));
      await notifier.reset();

      expect(container.read(collegeImportProvider).valueOrNull, isA<ImportUploading>());
    });
  });

  group('résumé et échec d’un réimport (chantier 1)', () {
    Future<CollegeImportNotifier> streaming(ProviderContainer container) async {
      final notifier = container.read(collegeImportProvider.notifier);
      await container.read(collegeImportProvider.future);
      notifier.debugSetState(const ImportStreaming(
        collegeId: 'c', jobId: 'j', ocrProgress: 80, totalPages: 80, status: 'ocr_complete',
      ));
      return notifier;
    }

    test('generation_complete avec résumé → ImportComplete.summary', () async {
      final container = _makeContainer(_FakeCollegeImportRepository());
      addTearDown(container.dispose);
      final notifier = await streaming(container);
      notifier.debugHandleSseEvent({
        'event': 'generation_complete',
        'data': {'college_id': 'c', 'summary': {'changed': 0, 'added': 0, 'removed': 0, 'unchanged': 24, 'quota_refunded': true}},
      }, 'c');
      final s = container.read(collegeImportProvider).value! as ImportComplete;
      expect(s.summary!.nothingChanged, isTrue);
      expect(s.summary!.quotaRefunded, isTrue);
    });

    test('generation_complete d’un premier import → pas de résumé', () async {
      final container = _makeContainer(_FakeCollegeImportRepository());
      addTearDown(container.dispose);
      final notifier = await streaming(container);
      notifier.debugHandleSseEvent({'event': 'generation_complete', 'data': {'college_id': 'c', 'summary': null}}, 'c');
      expect((container.read(collegeImportProvider).value! as ImportComplete).summary, isNull);
    });

    test('generation_failed d’un réimport → reimport_failed', () async {
      final container = _makeContainer(_FakeCollegeImportRepository());
      addTearDown(container.dispose);
      final notifier = await streaming(container);
      notifier.debugHandleSseEvent(
          {'event': 'generation_failed', 'data': {'college_id': 'c', 'message': 'x', 'reimport': true}}, 'c');
      expect((container.read(collegeImportProvider).value! as ImportError).message, 'reimport_failed');
    });

    test('reconnectIfActive : réimport en échec d’après /status → reimport_failed', () async {
      final repo = _FakeCollegeImportRepository(
        statusOverride: CollegeStatusResponse(
          collegeId: 'college-uuid-15', refId: 15, status: 'failed', ocrProgress: 0, reimport: true,
        ),
      );
      final container = _makeContainer(repo, apiClient: _FakeApiClient());
      addTearDown(container.dispose);
      await container.read(collegeImportProvider.notifier).reconnectIfActive('college-uuid-15');
      expect((container.read(collegeImportProvider).valueOrNull! as ImportError).message, 'reimport_failed');
    });
  });

  group('avancement de la génération (8.13)', () {
    test('generation_progress : fiches prêtes et items au fil de l’eau', () async {
      final container = _makeContainer(_FakeCollegeImportRepository());
      addTearDown(container.dispose);
      final notifier = container.read(collegeImportProvider.notifier);
      await container.read(collegeImportProvider.future);
      notifier.debugSetState(const ImportStreaming(
        collegeId: 'c', jobId: 'j', ocrProgress: 80, totalPages: 80, status: 'ocr_complete',
      ));
      notifier.debugHandleSseEvent(
        {'event': 'generation_progress', 'data': {'items_done': 3, 'items_total': 32, 'cards': 21}},
        'c',
      );
      final s = container.read(collegeImportProvider).value! as ImportStreaming;
      expect([s.itemsDone, s.itemsTotal, s.cards], [3, 32, 21]);
      expect(s.status, 'ocr_complete');

      // Un événement OCR tardif ne remet pas le compteur à zéro.
      notifier.debugHandleSseEvent({'event': 'ocr_progress', 'data': {'page': 80, 'total': 80}}, 'c');
      final after = container.read(collegeImportProvider).value! as ImportStreaming;
      expect(after.cards, 21);
      expect(after.status, 'ocr_complete', reason: 'la génération ne revient pas en lecture');
    });
  });

  test('reprise (retour au premier plan) : le compteur de fiches ne repart pas de zéro', () async {
    final repo = _FakeCollegeImportRepository(
      statusOverride: CollegeStatusResponse(
        collegeId: 'c', refId: 3, status: 'ocr_complete', ocrProgress: 80, totalPages: 80, jobId: 'j',
      ),
    );
    final container = _makeContainer(repo, apiClient: _FakeApiClient());
    addTearDown(container.dispose);
    final notifier = container.read(collegeImportProvider.notifier);
    await container.read(collegeImportProvider.future);
    notifier.debugSetState(const ImportStreaming(
      collegeId: 'c', jobId: 'j', ocrProgress: 80, totalPages: 80, status: 'ocr_complete',
      itemsDone: 3, itemsTotal: 32, cards: 21, preview: ['Q'],
    ));
    await notifier.reconnectIfActive('c');
    final s = container.read(collegeImportProvider).value! as ImportStreaming;
    expect([s.itemsDone, s.itemsTotal, s.cards], [3, 32, 21]);
    expect(s.preview, ['Q']);
  });
}
