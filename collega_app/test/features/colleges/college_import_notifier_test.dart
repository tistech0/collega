import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_client.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
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

  @override
  Future<ImportStartResponse> importPdf(int refId, File pdfFile) async {
    if (throwOnImport != null) throw throwOnImport!;
    return importResult!;
  }

  @override
  Future<CollegeStatusResponse> getStatus(String collegeId) async {
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

ProviderContainer _makeContainer(
  _FakeCollegeImportRepository repo, {
  _FakeApiClient? apiClient,
}) {
  return ProviderContainer(
    overrides: [
      collegeImportRepositoryProvider.overrideWithValue(repo),
      secureStorageProvider.overrideWithValue(const FlutterSecureStorage()),
      databaseProvider.overrideWithValue(_makeInMemoryDb()),
      if (apiClient != null) apiClientProvider.overrideWithValue(apiClient),
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
  });
}
