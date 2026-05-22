import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/network/sse_client.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/env.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/college_import_repository.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

export 'package:collega_app/features/colleges/data/college_import_repository.dart'
    show SubscriptionRequiredException, JobInProgressException, QueueUnavailableException,
         CollegeReloadLimitException, MonthlyReloadLimitException;

final collegeImportRepositoryProvider = Provider<CollegeImportRepository>(
  (ref) => CollegeImportRepository(
    dio: ref.read(apiClientProvider).dio,
  ),
);

class CollegeImportNotifier extends AsyncNotifier<CollegeImportState> {
  StreamSubscription<Map<String, dynamic>>? _sseSubscription;
  SseClient? _sseClient;
  // Story 7.2 (review patch) : flag de disposal — Riverpod 2.6 n'expose pas
  // `ref.mounted` sur AsyncNotifierProviderRef, donc on track soi-même pour
  // détecter qu'un await long (refresh JWT, lecture storage) s'est terminé
  // après que le notifier a été disposé (navigation pendant la connexion SSE).
  bool _disposed = false;

  @override
  Future<CollegeImportState> build() async {
    ref.onDispose(() {
      _disposed = true;
      _sseSubscription?.cancel();
      _sseClient?.disconnect();
    });
    return const ImportIdle();
  }

  Future<void> reset() async {
    await _sseSubscription?.cancel();
    _sseClient?.disconnect();
    _sseSubscription = null;
    _sseClient = null;
    state = const AsyncValue.data(ImportIdle());
  }

  Future<void> startImport(int refId, File file) async {
    state = const AsyncValue.data(ImportUploading());
    try {
      final repo = ref.read(collegeImportRepositoryProvider);
      final response = await repo.importPdf(refId, file);

      final db = ref.read(databaseProvider);
      await db.into(db.collegeImports).insertOnConflictUpdate(
            CollegeImportsCompanion.insert(
              id: response.collegeId,
              refId: refId,
              jobId: response.jobId,
              status: response.status,
              updatedAt: DateTime.now().toUtc(),
            ),
          );

      state = AsyncValue.data(ImportStreaming(
        collegeId: response.collegeId,
        jobId: response.jobId,
        ocrProgress: 0,
        totalPages: null,
        status: 'pending',
      ));

      await _connectSse(response.collegeId);
    } on SubscriptionRequiredException {
      state = const AsyncValue.data(ImportError(message: 'subscription_required'));
    } on JobInProgressException {
      state = const AsyncValue.data(ImportError(message: 'job_in_progress'));
    } on QueueUnavailableException {
      state = const AsyncValue.data(ImportError(message: 'queue_unavailable'));
    } on CollegeReloadLimitException {
      state = const AsyncValue.data(ImportError(message: 'college_reload_limit'));
    } on MonthlyReloadLimitException catch (e) {
      state = AsyncValue.data(ImportError(message: 'monthly_reload_limit:${e.resetAt}'));
    } on DioException catch (e) {
      state = AsyncValue.data(ImportError(message: e.message ?? 'network_error'));
    }
  }

  Future<void> _connectSse(String collegeId) async {
    await _sseSubscription?.cancel();

    // Story 7.2 AC #5 — refresh défensif AVANT (re)connexion SSE pour éviter
    // un token figé entre background et foreground (ou expiré après >30 min).
    final refreshOk = await ref.read(apiClientProvider).ensureFreshAccessToken();
    if (_disposed) return;
    if (!refreshOk) {
      AppLogger.warning(
        'SSE refresh failed — session expirée, transition vers ImportError',
        tag: 'CollegeImportNotifier',
      );
      state = const AsyncValue.data(ImportError(message: 'session_expired'));
      return;
    }

    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'access_token') ?? '';
    if (_disposed) return;
    _sseClient = SseClient(backendBaseUrl, tokenProvider: () => token);

    _sseSubscription = _sseClient!
        .connect('/v1/colleges/$collegeId/stream')
        .listen(
          (event) => _handleSseEvent(event, collegeId),
          onError: (Object e) =>
              AppLogger.error('SSE error', tag: 'CollegeImportNotifier', error: e),
        );
  }

  void _handleSseEvent(Map<String, dynamic> event, String collegeId) {
    final eventType = event['event'] as String?;
    final data = event['data'] as Map<String, dynamic>? ?? {};

    final current = state.valueOrNull;
    if (current is! ImportStreaming) return;

    switch (eventType) {
      case 'ocr_progress':
        final page = data['page'] as int? ?? 0;
        final total = data['total'] as int?;
        state = AsyncValue.data(current.copyWith(
          ocrProgress: page,
          totalPages: total,
          status: 'processing',
        ));
        _updateDriftProgress(collegeId, page, total, 'processing');
      case 'card_generation_started':
        state = AsyncValue.data(current.copyWith(status: 'ocr_complete'));
        _updateDriftProgress(collegeId, current.ocrProgress, current.totalPages, 'ocr_complete');
      case 'generation_complete':
        state = AsyncValue.data(ImportComplete(collegeId: collegeId));
        ref.invalidate(collegesProvider);
      case 'generation_failed':
        state = const AsyncValue.data(ImportError(message: 'generation_failed'));
    }
  }

  void _updateDriftProgress(String collegeId, int page, int? total, String status) {
    final db = ref.read(databaseProvider);
    unawaited(
      db.into(db.collegeImports).insertOnConflictUpdate(
        CollegeImportsCompanion(
          id: Value(collegeId),
          ocrProgress: Value(page),
          totalPages: Value(total),
          status: Value(status),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      ).catchError((Object e) {
        AppLogger.error('Drift update failed', tag: 'CollegeImportNotifier', error: e);
        return 0;
      }),
    );
  }

  Future<void> reconnectIfActive(String collegeId) async {
    final repo = ref.read(collegeImportRepositoryProvider);
    try {
      final status = await repo.getStatus(collegeId);
      if (status.status == 'pending' || status.status == 'processing') {
        state = AsyncValue.data(ImportStreaming(
          collegeId: collegeId,
          jobId: status.jobId ?? '',
          ocrProgress: status.ocrProgress,
          totalPages: status.totalPages,
          status: status.status,
        ));
        await _connectSse(collegeId);
      } else if (status.status == 'generation_complete') {
        state = AsyncValue.data(ImportComplete(collegeId: collegeId));
        ref.invalidate(collegesProvider);
      }
    } catch (e) {
      AppLogger.warning('reconnectIfActive failed: $e', tag: 'CollegeImportNotifier');
    }
  }

}

final collegeImportProvider =
    AsyncNotifierProvider<CollegeImportNotifier, CollegeImportState>(
  CollegeImportNotifier.new,
);
