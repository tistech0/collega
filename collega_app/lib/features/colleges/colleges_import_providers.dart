import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/network/sse_client.dart';
import 'package:collega_app/core/upload/chunked_upload_service.dart';
import 'package:collega_app/core/upload/upload_models.dart';
import 'package:collega_app/core/upload/upload_providers.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/env.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/college_cards_sync.dart';
import 'package:collega_app/features/colleges/data/college_import_repository.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

export 'package:collega_app/features/colleges/data/college_import_repository.dart'
    show SubscriptionRequiredException, JobInProgressException, QueueUnavailableException,
         CollegeReloadLimitException, MonthlyReloadLimitException;

/// PDF choisi et sa taille (lue une fois, au choix).
typedef PickedPdf = ({File file, int size});

/// Choix du PDF (sélecteur de fichiers iOS) ; remplacé en test.
final pdfPickerProvider = Provider<Future<PickedPdf?> Function()>((ref) => () async {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      final path = result?.files.single.path;
      if (path == null) return null;
      final file = File(path);
      return (file: file, size: await file.length());
    });

final collegeImportRepositoryProvider = Provider<CollegeImportRepository>(
  (ref) => CollegeImportRepository(
    dio: ref.read(apiClientProvider).dio,
  ),
);

/// Délai de base avant re-synchronisation quand le stream SSE se ferme ou
/// échoue en cours d'import (backoff exponentiel jusqu'à [_sseReconnectMaxDelay]).
/// Overridable en test pour ne pas attendre.
final sseReconnectDelayProvider = Provider<Duration>((_) => const Duration(seconds: 3));
const _sseReconnectMaxDelay = Duration(seconds: 30);

class CollegeImportNotifier extends AsyncNotifier<CollegeImportState> {
  StreamSubscription<Map<String, dynamic>>? _sseSubscription;
  SseClient? _sseClient;
  // Story 7.2 (review patch) : flag de disposal — Riverpod 2.6 n'expose pas
  // `ref.mounted` sur AsyncNotifierProviderRef, donc on track soi-même pour
  // détecter qu'un await long (refresh JWT, lecture storage) s'est terminé
  // après que le notifier a été disposé (navigation pendant la connexion SSE).
  bool _disposed = false;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  // Appels concurrents à reconnectIfActive (N écrans, onResume + resync) fusionnés
  // en une seule requête /status + un seul stream SSE.
  Future<void>? _resyncInFlight;

  @override
  Future<CollegeImportState> build() async {
    ref.onDispose(() {
      _disposed = true;
      _reconnectTimer?.cancel();
      _sseSubscription?.cancel();
      _sseClient?.disconnect();
    });
    return const ImportIdle();
  }

  Future<void> reset() async {
    // Un upload par morceaux en cours (transport arrière-plan) survit à la navigation :
    // l'écran d'import le réaffiche via ImportUploading.progress.
    if (state.valueOrNull case ImportUploading(progress: != null)) return;
    // Un import suivi (SSE) continue : ouvrir un écran d'import ne le coupe pas.
    if (state.valueOrNull is ImportStreaming) return;
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    await _sseSubscription?.cancel();
    _sseClient?.disconnect();
    _sseSubscription = null;
    _sseClient = null;
    state = const AsyncValue.data(ImportIdle());
  }

  Future<void> startImport(int refId, File file) async {
    state = AsyncValue.data(ImportUploading(refId: refId));
    try {
      final size = await file.length();
      if (size > ChunkedUploadService.maxSize) {
        state = const AsyncValue.data(ImportError(message: 'file_too_large'));
        return;
      }
      final ImportStartResponse response;
      if (size > ChunkedUploadService.chunkThreshold) {
        // Story 7.11 : au-delà de 90 MB, Cloudflare refuserait la requête unique (413).
        final chunked = await ref.read(chunkedUploadServiceProvider.future);
        if (await chunked.hasPending()) {
          state = const AsyncValue.data(ImportError(message: 'upload_in_progress'));
          return;
        }
        response = await chunked.upload(refId, file, onProgress: _onUploadProgress);
      } else {
        final repo = ref.read(collegeImportRepositoryProvider);
        response = await repo.importPdf(refId, file);
      }
      await _afterUploadAccepted(refId, response);
    } on FileTooLargeException {
      state = const AsyncValue.data(ImportError(message: 'file_too_large'));
    } on UploadExpiredException {
      state = const AsyncValue.data(ImportError(message: 'upload_expired'));
    } on PartUploadFailed catch (e) {
      AppLogger.error('part upload failed', tag: 'CollegeImportNotifier', error: e.error);
      state = const AsyncValue.data(ImportError(message: 'upload_failed'));
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

  /// Upload accepté (202) : mémorise l'import en local, passe en streaming et ouvre le SSE.
  Future<void> _afterUploadAccepted(int refId, ImportStartResponse response) async {
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
    // Le serveur connaît désormais le collège : la Bibliothèque le montre « import en cours ».
    ref.invalidate(collegesProvider);

    await _connectSse(response.collegeId);
  }

  void _onUploadProgress(double p) {
    if (_disposed) return;
    final current = state.valueOrNull;
    if (current is ImportUploading) state = AsyncValue.data(ImportUploading(refId: current.refId, progress: p));
  }

  bool _resumeInFlight = false;

  /// Reprise d'un upload par morceaux interrompu (démarrage / retour premier plan, Story 7.11).
  /// No-op sans ligne `pending_uploads` ou si une reprise / un upload est déjà en cours.
  Future<void> resumePendingUpload() async {
    if (_resumeInFlight || state.valueOrNull is ImportUploading) return;
    final ChunkedUploadService chunked;
    final int refId;
    try {
      chunked = await ref.read(chunkedUploadServiceProvider.future);
      if (_disposed || !await chunked.hasPending()) return;
      final db = ref.read(databaseProvider);
      refId = (await db.select(db.pendingUploads).get()).first.refId;
    } catch (e) {
      // Pas de reprise possible (DB / cache indisponible) : on ne touche pas à l'état.
      AppLogger.warning('resumePendingUpload: check failed: $e', tag: 'CollegeImportNotifier');
      return;
    }
    _resumeInFlight = true;
    state = AsyncValue.data(ImportUploading(refId: refId, progress: 0));
    try {
      final response = await chunked.resume(onProgress: _onUploadProgress);
      if (response != null) await _afterUploadAccepted(refId, response);
    } on UploadExpiredException {
      state = const AsyncValue.data(ImportError(message: 'upload_expired'));
    } on UploadSourceMissing {
      state = const AsyncValue.data(ImportError(message: 'upload_source_missing'));
    } on PartUploadFailed catch (e) {
      AppLogger.error('part upload failed (resume)', tag: 'CollegeImportNotifier', error: e.error);
      state = const AsyncValue.data(ImportError(message: 'upload_failed'));
    } catch (e) {
      AppLogger.warning('resumePendingUpload failed: $e', tag: 'CollegeImportNotifier');
      state = const AsyncValue.data(ImportError(message: 'network_error'));
    } finally {
      _resumeInFlight = false;
    }
  }

  @visibleForTesting
  void debugSetState(CollegeImportState value) => state = AsyncValue.data(value);

  @visibleForTesting
  void debugHandleSseEvent(Map<String, dynamic> event, String collegeId) => _handleSseEvent(event, collegeId);

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
    // Un seul stream actif : l'ancien client est déconnecté (cancel token), pas
    // seulement sa subscription — sinon la connexion HTTP reste ouverte côté serveur.
    _sseClient?.disconnect();
    _sseClient = SseClient(backendBaseUrl, tokenProvider: () => token);

    _sseSubscription = _sseClient!
        .connect('/v1/colleges/$collegeId/stream')
        .listen(
          (event) {
            _reconnectAttempt = 0;
            _handleSseEvent(event, collegeId);
          },
          onError: (Object e) {
            AppLogger.error('SSE error', tag: 'CollegeImportNotifier', error: e);
            _scheduleResync(collegeId);
          },
          // Cloudflare / proxies coupent un stream silencieux (~100 s) et les
          // réseaux mobiles perdent des connexions : une fermeture sans
          // événement terminal n'est PAS une fin d'import.
          onDone: () => _scheduleResync(collegeId),
        );
  }

  /// Re-synchronise via GET /status puis rouvre le SSE si l'import est encore
  /// actif. Backoff exponentiel ; abandonné si l'état n'est plus ImportStreaming.
  void _scheduleResync(String collegeId) {
    if (_disposed || state.valueOrNull is! ImportStreaming) return;
    final base = ref.read(sseReconnectDelayProvider);
    var delay = base * (1 << _reconnectAttempt);
    if (delay > _sseReconnectMaxDelay) delay = _sseReconnectMaxDelay;
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(0, 10);
    AppLogger.warning(
      'SSE fermé pendant l\'import — resync dans ${delay.inSeconds}s',
      tag: 'CollegeImportNotifier',
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_disposed || state.valueOrNull is! ImportStreaming) return;
      unawaited(reconnectIfActive(collegeId));
    });
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
        // Un événement OCR tardif ne ramène pas la génération en lecture.
        final status = current.status == 'ocr_complete' ? 'ocr_complete' : 'processing';
        state = AsyncValue.data(current.copyWith(ocrProgress: page, totalPages: total, status: status));
        _updateDriftProgress(collegeId, page, total, status);
      case 'generation_progress':
        state = AsyncValue.data(current.copyWith(
          status: 'ocr_complete',
          itemsDone: data['items_done'] as int? ?? current.itemsDone,
          itemsTotal: data['items_total'] as int? ?? current.itemsTotal,
          cards: data['cards'] as int? ?? current.cards,
          preview: (data['preview'] as List?)?.whereType<String>().toList() ?? current.preview,
        ));
      case 'card_generation_started':
        state = AsyncValue.data(current.copyWith(status: 'ocr_complete'));
        _updateDriftProgress(collegeId, current.ocrProgress, current.totalPages, 'ocr_complete');
      case 'generation_complete':
        state = AsyncValue.data(ImportComplete(collegeId: collegeId));
        _onGenerationComplete(collegeId);
      case 'generation_failed':
        state = const AsyncValue.data(ImportError(message: 'generation_failed'));
    }
  }

  /// Fiches prêtes (import ou réimport, même `college_id`) : la liste, le détail
  /// et les fiches locales repartent du serveur. Sans cela le détail et le drill
  /// resteraient sur les fiches supprimées par le réimport (revue 8.7).
  void _onGenerationComplete(String collegeId) {
    ref.invalidate(collegesProvider);
    final db = ref.read(databaseProvider);
    unawaited(ref.read(collegeCardsFetcherProvider)(collegeId).then((cards) async {
      await syncCollegeCards(db, collegeId, cards);
    }).catchError((Object e) {
      AppLogger.warning('fiches du collège $collegeId après import : $e', tag: 'CollegeImportNotifier');
    }).whenComplete(() {
      // Le détail (s'il est ouvert) recharge items et fiches. Pas d'invalidate :
      // en debug, invalider un provider jamais lu le construit (appel réseau inutile).
      if (!_disposed) ref.read(collegeDataVersionProvider(collegeId).notifier).state++;
    }));
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

  Future<void> reconnectIfActive(String collegeId) {
    final inFlight = _resyncInFlight;
    if (inFlight != null) return inFlight;
    final run = _reconnectIfActive(collegeId).whenComplete(() => _resyncInFlight = null);
    _resyncInFlight = run;
    return run;
  }

  Future<void> _reconnectIfActive(String collegeId) async {
    final repo = ref.read(collegeImportRepositoryProvider);
    try {
      final status = await repo.getStatus(collegeId);
      if (_disposed) return;
      switch (status.status) {
        // ocr_complete = génération Claude en cours : phase la plus longue,
        // il faut bien reprendre le stream ici aussi.
        case 'pending' || 'processing' || 'ocr_complete':
          // Même import déjà suivi : on garde le compteur de fiches et l'aperçu
          // (le flux les renverra au prochain changement).
          final previous = state.valueOrNull;
          final same = previous is ImportStreaming && previous.collegeId == collegeId ? previous : null;
          state = AsyncValue.data(ImportStreaming(
            collegeId: collegeId,
            jobId: status.jobId ?? '',
            ocrProgress: status.ocrProgress,
            totalPages: status.totalPages,
            status: status.status,
            itemsDone: same?.itemsDone ?? 0,
            itemsTotal: same?.itemsTotal,
            cards: same?.cards ?? 0,
            preview: same?.preview ?? const [],
          ));
          await _connectSse(collegeId);
        case 'generation_complete':
          state = AsyncValue.data(ImportComplete(collegeId: collegeId));
          _onGenerationComplete(collegeId);
        case 'failed':
          state = const AsyncValue.data(ImportError(message: 'generation_failed'));
      }
    } catch (e) {
      AppLogger.warning('reconnectIfActive failed: $e', tag: 'CollegeImportNotifier');
      // Réseau indisponible : on réessaie tant que l'import est en cours.
      _scheduleResync(collegeId);
    }
  }

}

final collegeImportProvider =
    AsyncNotifierProvider<CollegeImportNotifier, CollegeImportState>(
  CollegeImportNotifier.new,
);
