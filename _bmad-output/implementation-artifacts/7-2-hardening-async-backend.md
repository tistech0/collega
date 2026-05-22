# Story 7.2 : Hardening Async Backend (Atomicité Quotas, Rate Limit User, Race OCR, JWT SSE)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur backend**,
je veux éliminer les race conditions et les limites manquantes qui ne se manifestent qu'en charge concurrente,
afin que l'app supporte sans incident plusieurs utilisatrices simultanées de la beta élargie sans surcoût Claude et sans 429 collectif.

**Items source :** A1, A3, A4, A5, A6, A9 (cf. `_bmad-output/planning-artifacts/epics-v1.1.md` L.142-196 et `_bmad-output/implementation-artifacts/epic-mvp-retro-2026-05-19.md` § 4)

---

## Acceptance Criteria

1. **AC1 — A1 : Atomicité quotas reload_count + monthly_reloads (router, pas worker)**
   - **Étant donné** deux requêtes `POST /v1/colleges/{ref_id}/import` concurrentes sur le même collège (ou pour deux collèges du même user dans la même seconde) en mode reimport (`college.status == 'generation_complete'`)
   - **Quand** elles arrivent simultanément côté router
   - **Alors** la vérification + l'incrément se fait via **un seul statement SQL atomique** dans le routeur (`app/api/v1/colleges.py:import_college_pdf`) **avant** la création du `GenerationJob` :
     ```sql
     UPDATE colleges SET reload_count = reload_count + 1
     WHERE id = :id AND reload_count < :max RETURNING reload_count;
     ```
     Idem pour `monthly_reloads`.
   - **Et** si l'UPDATE retourne 0 lignes (limite déjà atteinte), la requête échoue avec `409 COLLEGE_RELOAD_LIMIT` (ou `409 MONTHLY_RELOAD_LIMIT` selon le compteur saturé) — pas de `429`, on conserve les codes 409 existants pour ne pas casser le contrat Flutter
   - **Et** aucun cas où les deux requêtes réussissent en faisant dépasser `reload_count > max` ou `monthly_reloads > max`
   - **Et** si la création du `GenerationJob` ou l'enqueue ARQ échoue après l'incrément, l'incrément est **rollback** dans la même transaction (`await db.rollback()`)
   - **Et** l'incrément dans `card_generator.py:105-120` (worker ARQ) est **retiré** (l'incrément a déjà été fait au router — éviter le double comptage)

2. **AC2 — A5 : Cron quotidien ARQ pour reset mensuel défensif**
   - **Étant donné** le worker ARQ `cleanup_worker.py` configuré dans `app/workers/settings.py`
   - **Quand** son nouveau cron `reset_monthly_reloads` s'exécute (1× par jour, à 00:05 UTC pour éviter la collision avec `cleanup_ocr_text` à minute=0)
   - **Alors** une fonction `reset_monthly_reloads(ctx)` met à zéro `monthly_reloads` sur tous les `users` dont `monthly_reloads_reset_at IS NOT NULL AND monthly_reloads_reset_at <= now` via un seul `UPDATE`
   - **Et** met à jour `monthly_reloads_reset_at = _next_month_reset(now)` (réutiliser la fonction existante de `colleges.py:44-48`, à factoriser dans `app/core/time_utils.py` ou équivalent)
   - **Et** un test d'intégration vérifie qu'après le reset, l'utilisateur peut à nouveau lancer `monthly_reloads_max` reimports
   - **Et** la logique lazy de reset dans `colleges.py:186-223` est **conservée en filet de sécurité** (le cron est défensif, pas exclusif)

3. **AC3 — A3 : Rate limit `/v1/search` par user_id (pas par IP)**
   - **Étant donné** un utilisateur authentifié appelant `GET /v1/search?q=...`
   - **Quand** il dépasse `30 requêtes par minute`
   - **Alors** le rate limiting utilise `key_func=lambda req: req.state.user_id` au niveau du décorateur : `@limiter.limit("30/minute", key_func=...)`
   - **Et** `get_current_user` (`app/deps.py:57-84`) est modifié pour peupler `request.state.user_id = str(user.id)` (signature mise à jour pour accepter `request: Request`)
   - **Et** le `Limiter` global dans `app/core/limiter.py:14` reste sur `_get_client_ip` pour ne pas casser les autres endpoints (`/login` 5/min, `DELETE /account` 3/min, `/regenerate` 10/hour, `/notifications/*` 10/min)
   - **Et** deux users distincts sur la même IP (fac, NAT) ne se bloquent plus mutuellement (test : user A fait 30 requêtes, user B doit pouvoir continuer)
   - **Et** un utilisateur non-authentifié appelant `/search` est rejeté par `require_subscription` **avant** que le rate limit ne s'applique (comportement actuel préservé)

4. **AC4 — A4 : Race OCR — contrainte UNIQUE partial index sur `generation_jobs`**
   - **Étant donné** deux requêtes concurrentes sur le même `college_id` :
     - Soit `POST /v1/admin/colleges/{college_id}/process` (admin path)
     - Soit `POST /v1/colleges/{ref_id}/import` (user path)
   - **Quand** elles tentent toutes deux de créer un `GenerationJob` avec `status='pending'`
   - **Alors** la base PostgreSQL applique une contrainte :
     ```sql
     CREATE UNIQUE INDEX idx_one_active_job_per_college
     ON generation_jobs (college_id)
     WHERE status IN ('pending', 'processing', 'ocr_complete');
     ```
   - **Et** la deuxième requête lève un `IntegrityError` SQLAlchemy → catch → retour `409 JOB_IN_PROGRESS` (code identique au pre-check existant `colleges.py:177-181` et `admin.py:90-95`)
   - **Et** la migration Alembic `012_add_unique_constraint_generation_jobs.py` ajoute la contrainte sans data loss (idempotent : `CREATE UNIQUE INDEX IF NOT EXISTS`)
   - **Et** le pre-check SELECT existant (`colleges.py:172-181` et `admin.py:81-95`) est **conservé** (UX : réponse rapide en cas non-concurrent ; la contrainte est le filet de sécurité)

5. **AC5 — A6 : Refresh JWT avant reconnexion SSE**
   - **Étant donné** une connexion SSE active depuis `sse_client.dart` (utilisée par `CollegeImportNotifier._connectSse()`) ouverte depuis > 30 min (access_token expiré côté backend)
   - **Quand** le client se déconnecte (background app, perte réseau, navigation) et tente de se reconnecter via `reconnectIfActive(collegeId)` (`colleges_import_providers.dart:reconnectIfActive`)
   - **Alors** **avant chaque appel à `_connectSse(collegeId)`**, le notifier déclenche `apiClient._getRefresh()` (méthode actuellement privée, à exposer publiquement ou via une méthode wrapper `ensureFreshAccessToken()`) pour valider/rafraîchir le token
   - **Et** la nouvelle connexion SSE utilise le token rafraîchi (re-lu depuis `secureStorage.read(key: 'access_token')` après le refresh)
   - **Et** si le refresh échoue (refresh_token expiré aussi → `_tryRefresh` retourne false), l'app appelle `onForceLogout()` (déjà câblé dans `ApiClient`) qui clear les tokens et trigger le redirect `/login` via le pattern existant
   - **Et** la cold-start path n'est PAS impactée : si pas de connexion SSE active au démarrage, aucun refresh n'est forcé (gain de batterie)

6. **AC6 — A9 : Timeout et retry sur `evaluateSemantic` côté Flutter**
   - **Étant donné** un appel `POST /v1/flash-cards/{id}/evaluate-semantic` depuis `drill_repository.dart:evaluateSemantic`
   - **Quand** la requête timeout (`DioExceptionType.receiveTimeout` ou `connectTimeout`) ou retourne 5xx
   - **Alors** le timeout local de cet appel est explicitement configuré à `15s` via `Options(receiveTimeout: Duration(seconds: 15))` (override du global 30s pour borner cet endpoint indépendamment du Dio global qui sert d'autres appels)
   - **Et** en cas de timeout/5xx, le client retente **une seule fois** automatiquement avant de propager l'erreur
   - **Et** le fallback existant dans `drill_screen.dart:_handleDefinitionSubmit` (`catch (_) → notifier.flip()`) continue de fonctionner comme filet de sécurité (UX : la carte se retourne, le user voit la réponse, pas de bloquage)
   - **Et** un test Dio mock vérifie ce comportement (timeout → retry → fallback)

---

## Tasks / Subtasks

### Backend — Atomicité quotas + race OCR + cron monthly reset

- [x] **T1 — Migration Alembic `012_atomic_quota_and_unique_processing.py` (AC: #1, #4)**
  - Fichier **NEW** : `collega_backend/alembic/versions/012_atomic_quota_and_unique_processing.py`
  - **Up** : Crée la contrainte `UNIQUE INDEX idx_one_active_job_per_college ON generation_jobs (college_id) WHERE status IN ('pending', 'processing', 'ocr_complete')` via `op.create_index(..., postgresql_where=...)`.
  - **Up** : **AVANT** de créer l'index, supprimer les éventuels doublons existants en base (defensive cleanup) : `DELETE FROM generation_jobs g1 USING generation_jobs g2 WHERE g1.id != g2.id AND g1.college_id = g2.college_id AND g1.status IN (...) AND g2.status IN (...) AND g1.created_at > g2.created_at;` (garde le plus ancien). **Logger** le nombre de lignes supprimées.
  - **Down** : `op.drop_index('idx_one_active_job_per_college', table_name='generation_jobs')`.
  - **Vérifier** : la colonne `monthly_reloads_reset_at` existe déjà (migration 007) — pas besoin de l'ajouter.
  - **Tester localement** : `alembic upgrade head && alembic downgrade -1 && alembic upgrade head` doit être idempotent.

- [x] **T2 — Refactor router `import_college_pdf` pour atomicité quotas (AC: #1)**
  - Fichier : `collega_backend/app/api/v1/colleges.py:138-310`
  - **Remplacer** le bloc de check non-atomique (lignes 184-218) par un UPDATE atomique avec RETURNING **pour le seul cas reimport** (`college.status == 'generation_complete'`).
  - Pattern à appliquer :
    ```python
    if college.status == "generation_complete":
        now = datetime.now(timezone.utc)
        is_month_reset = (
            current_user.monthly_reloads_reset_at is None
            or now >= current_user.monthly_reloads_reset_at
        )

        # 1. Reset mensuel lazy si besoin (conserver — filet de sécurité)
        if is_month_reset:
            current_user.monthly_reloads = 0
            current_user.monthly_reloads_reset_at = _next_month_reset(now)
            await db.flush()  # rendre visible le reset au prochain UPDATE

        # 2. Incrément atomique College.reload_count avec RETURNING
        college_update = await db.execute(
            sa_update(College)
            .where(College.id == college.id)
            .where(College.reload_count < settings.reload_count_max)
            .values(reload_count=College.reload_count + 1)
            .returning(College.reload_count)
        )
        new_college_count = college_update.scalar_one_or_none()
        if new_college_count is None:
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "COLLEGE_RELOAD_LIMIT",
                    "message": f"Ce collège ne peut plus être retraité (limite : {settings.reload_count_max})",
                    "reload_count": college.reload_count,
                    "reload_count_max": settings.reload_count_max,
                },
            )

        # 3. Incrément atomique User.monthly_reloads avec RETURNING
        user_update = await db.execute(
            sa_update(User)
            .where(User.id == current_user.id)
            .where(User.monthly_reloads < settings.monthly_reloads_max)
            .values(monthly_reloads=User.monthly_reloads + 1)
            .returning(User.monthly_reloads)
        )
        new_monthly = user_update.scalar_one_or_none()
        if new_monthly is None:
            # ROLLBACK l'incrément college fait juste avant — critique
            await db.rollback()
            reset_at = current_user.monthly_reloads_reset_at or _next_month_reset(now)
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "MONTHLY_RELOAD_LIMIT",
                    "message": f"Limite mensuelle atteinte ({settings.monthly_reloads_max} reimports/mois)",
                    "monthly_reloads": current_user.monthly_reloads,
                    "monthly_max": settings.monthly_reloads_max,
                    "reset_at": reset_at.isoformat(),
                },
            )
    ```
  - **CRITIQUE — ordre** : incrémenter College AVANT User. Si l'incrément User échoue, le `await db.rollback()` annule les deux (la transaction n'est pas encore commit). Si on incrémentait User d'abord puis College, et que College échoue, on aurait consommé un monthly_reload pour rien.
  - **CRITIQUE — rollback transaction** : `await db.rollback()` annule TOUTES les opérations de la transaction en cours (y compris le `db.add(college)` ou `db.flush()` si premier import — mais ici on est dans la branche `status == 'generation_complete'` donc le college existe déjà → pas de souci).
  - **À conserver** : le pre-check lignes 172-181 (`existing_job in pending/processing/ocr_complete`) → utile pour UX, garde le 409 JOB_IN_PROGRESS rapide.
  - **À conserver** : la création + commit du `GenerationJob` (lignes 265-275). Si le commit échoue après l'incrément, le rollback global FastAPI s'occupe d'annuler les UPDATE — mais **vérifier** que la session n'est pas committée entre l'UPDATE et la création du job. ⚠️ Risque : si `await db.flush()` est appelé entre temps, les UPDATE deviennent visibles. Garder tout dans la même transaction unique jusqu'au `await db.commit()` final L.274.
  - **À retirer** : le bloc `# Auto-reset mensuel si besoin — commité avec la transaction de succès` lignes 220-223 est **déplacé en amont** (étape 1 ci-dessus, avant les UPDATE) — l'intention reste mais le moment change.

- [x] **T3 — Retirer l'incrément double-comptage dans le worker (AC: #1)**
  - Fichier : `collega_backend/app/services/generation/card_generator.py:107-121`
  - **Supprimer** le bloc `if is_reimport and not job.hash_shared:` avec ses 2 `sa_update` (lignes 107-121). L'incrément est désormais fait au routeur (T2).
  - **Conserver** la requête de détection `is_reimport` (lignes 98-105) car elle peut être utile pour des logs ou métriques futures — sinon la retirer aussi. **Décision : retirer entièrement** si plus utilisée après T3, pour éviter du dead code.
  - **Vérifier** que les tests `tests/services/test_card_generator.py` (s'ils existent) n'asserent pas sur `reload_count += 1` post-worker. Adapter les assertions.

- [x] **T4 — Cron ARQ `reset_monthly_reloads` quotidien (AC: #2)**
  - Fichier : `collega_backend/app/workers/cleanup_worker.py`
  - Ajouter une nouvelle fonction async dans le même module (réutiliser `async_session_factory`) :
    ```python
    async def reset_monthly_reloads(ctx: dict) -> None:
        """Reset défensif des compteurs mensuels (cron quotidien)."""
        from app.api.v1.colleges import _next_month_reset  # ou factoriser ailleurs
        now = datetime.now(timezone.utc)
        async with async_session_factory() as db:
            result = await db.execute(
                sql_update(User)
                .where(User.monthly_reloads_reset_at.is_not(None))
                .where(User.monthly_reloads_reset_at <= now)
                .values(
                    monthly_reloads=0,
                    monthly_reloads_reset_at=_next_month_reset(now),
                )
            )
            await db.commit()
            logger.info("Reset monthly reloads for %d users", result.rowcount)
    ```
  - Fichier : `collega_backend/app/workers/settings.py:6-17`
  - Ajouter dans `cron_jobs` :
    ```python
    cron(reset_monthly_reloads, hour=0, minute=5),  # 00:05 UTC, après cleanup_ocr_text (minute=0)
    ```
  - **Import** : ajouter `from app.workers.cleanup_worker import reset_monthly_reloads` en haut de `settings.py`.
  - **CRITIQUE** : ne PAS factoriser `_next_month_reset` en breaking change (la fonction reste utilisée par `colleges.py`). Soit garder l'import direct, soit créer `app/core/time_utils.py` et migrer les deux usages.
  - **Décision recommandée** : créer `app/core/time_utils.py` avec `_next_month_reset` exporté publiquement, et mettre à jour `colleges.py:44-48` pour importer depuis ce module + faire de même dans `cleanup_worker.py`. Faible coût, supprime le import circulaire.

- [x] **T5 — Rate limit `/v1/search` par `user_id` (AC: #3)**
  - Fichier : `collega_backend/app/deps.py:57-84`
  - **Modifier la signature** de `get_current_user` pour accepter `request: Request` :
    ```python
    from fastapi import Request

    async def get_current_user(
        request: Request,
        authorization: str | None = Header(None),
        db: AsyncSession = Depends(get_db),
    ) -> User:
        # ... validation existante ...
        request.state.user_id = str(user.id)  # NEW: pour le rate limiter
        return user
    ```
  - **Vérifier** que `require_subscription` (qui dépend de `get_current_user`) n'est pas cassé — son retour est `User`, pas modifié par le request.state.
  - Fichier : `collega_backend/app/api/v1/search.py:17-20`
  - **Remplacer** le décorateur :
    ```python
    def _user_id_key(request: Request) -> str:
        return f"user:{getattr(request.state, 'user_id', 'anon')}"

    @router.get("/search")
    @limiter.limit("30/minute", key_func=_user_id_key)
    async def search(
        request: Request,
        # ... reste inchangé ...
    ):
    ```
  - **CRITIQUE — ordre `slowapi`** : le décorateur `@limiter.limit` doit s'évaluer **après** que `get_current_user` ait peuplé `request.state.user_id`. `slowapi` exécute son check AVANT les dépendances FastAPI → fallback `'anon'` couvre le cas où l'auth échoue (mais `require_subscription` rejettera avant de toucher l'endpoint, donc en pratique on est OK). **Vérifier** en dev avec un curl sans token : doit retourner 401 du auth, pas 429.
  - **NE PAS** modifier le `Limiter` global (`app/core/limiter.py:14`) — il reste sur `_get_client_ip` pour les autres routes (`/login`, `/account`, etc.).
  - **NE PAS** ajouter le `key_func=user_id` sur les autres routes — `/login` doit rester par IP (anti brute-force pré-auth), `DELETE /account` par IP (anti-abus post-auth mais l'IP est suffisante).

### Frontend — JWT SSE refresh + timeout retry évaluation sémantique

- [x] **T6 — Refresh JWT avant reconnexion SSE (AC: #5)**
  - Fichier : `collega_app/lib/core/network/api_client.dart:75-96`
  - **Exposer** un wrapper public pour le refresh : ajouter une méthode `Future<bool> ensureFreshAccessToken()` qui appelle `_getRefresh()` (actuellement privé). Le `_getRefresh()` gère déjà les appels concurrents via `_isRefreshing`/`_refreshFuture` (lignes 75-79). Pas besoin de réimplémenter.
  - Pattern :
    ```dart
    /// Force un refresh de l'access_token (utilisé avant SSE reconnect).
    /// Retourne true si le token est valide ou a été rafraîchi avec succès.
    Future<bool> ensureFreshAccessToken() => _getRefresh();
    ```
  - Fichier : `collega_app/lib/features/colleges/colleges_import_providers.dart:_connectSse`
  - **Avant** la création de `SseClient`, appeler `await ref.read(apiClientProvider).ensureFreshAccessToken()`. Si retour `false`, ne pas tenter de connecter (le ForceLogout sera déjà déclenché par `ApiClient`).
  - Pattern :
    ```dart
    Future<void> _connectSse(String collegeId) async {
      await _sseSubscription?.cancel();
      
      // A6 : refresh défensif AVANT chaque (re)connexion SSE
      final refreshOk = await ref.read(apiClientProvider).ensureFreshAccessToken();
      if (!refreshOk) {
        AppLogger.warning('SSE refresh failed, aborting connect', tag: 'CollegeImportNotifier');
        return;
      }
      
      final storage = ref.read(secureStorageProvider);
      final token = await storage.read(key: 'access_token') ?? '';
      _sseClient = SseClient(backendBaseUrl, tokenProvider: () => token);
      
      _sseSubscription = _sseClient!
          .connect('/v1/colleges/$collegeId/stream')
          .listen(/* ... inchangé ... */);
    }
    ```
  - **CRITIQUE — pas de boucle de refresh sur 401 streaming** : le `SseClient.connect()` actuel propage les erreurs Dio via `rethrow` (sse_client.dart:53). Si un 401 survient EN COURS de streaming (très rare car SSE max 3h ≈ 6× plus que JWT 30min, on n'est jamais "en cours" sur un token expiré sauf décalage horloge), l'erreur remonte au listener `(onError)` du notifier qui peut déclencher un nouveau `_connectSse()` — qui refera un refresh. C'est OK, pas de boucle infinie car `_getRefresh()` gère les refreshes parallèles.
  - **NE PAS** modifier `SseClient` lui-même pour intercepter les 401 — le pattern actuel (un client SSE générique + un notifier qui orchestre les reconnexions) est plus testable et conforme à `Pattern #1` de la rétro MVP (architecture découplée).
  - **NE PAS** changer la signature de `tokenProvider: () => token` en async — la closure existante capture le token frais (re-lu juste avant) ce qui suffit pour 99% des cas (cold start, foreground après background). Pour le cas streaming > 30min, la reconnexion explicite est suffisante.

- [x] **T7 — Timeout 15s + retry 1× sur `evaluateSemantic` (AC: #6)**
  - Fichier : `collega_app/lib/features/drill/data/drill_repository.dart:85-100`
  - **Remplacer** l'appel Dio actuel par un appel borné avec retry explicite :
    ```dart
    Future<SemanticFeedback> evaluateSemantic(
        String cardId, String userAnswer) async {
      const int maxAttempts = 2; // 1 try + 1 retry
      DioException? lastError;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final response = await dio.post<Map<String, dynamic>>(
            '/v1/flash-cards/$cardId/evaluate-semantic',
            data: {'user_answer': userAnswer},
            options: Options(
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 10),
            ),
          );
          final raw = response.data;
          if (raw == null) throw Exception('empty evaluateSemantic response');
          final data = raw['data'] as Map<String, dynamic>?;
          if (data == null) throw Exception('malformed evaluateSemantic response');
          return SemanticFeedback(
            result: data['result'] as String? ?? 'incorrect',
            feedback: data['feedback'] as String? ?? '',
          );
        } on DioException catch (e) {
          lastError = e;
          // Retry uniquement sur timeout ou 5xx
          final isRetriable = e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionTimeout ||
              (e.response?.statusCode != null && e.response!.statusCode! >= 500);
          if (!isRetriable || attempt == maxAttempts) {
            rethrow;
          }
          AppLogger.warning(
            'evaluateSemantic retry $attempt/$maxAttempts: ${e.type}',
            tag: 'DrillRepository',
          );
        }
      }
      throw lastError ?? Exception('evaluateSemantic failed without exception');
    }
    ```
  - **NE PAS** modifier le `receiveTimeout` global dans `api_client.dart:32-33` (30s global) — c'est utilisé par d'autres endpoints (import PDF stream, regenerate Claude qui peut prendre 10s+). L'override local est plus sûr.
  - **NE PAS** retry sur 4xx (sauf 5xx serveur) — le code 422/400 indique une erreur côté client, pas la peine de retenter. Retry uniquement timeout + 5xx.
  - **Conserver** le fallback existant dans `drill_screen.dart:_handleDefinitionSubmit` (le `catch (_) → notifier.flip()`) — il reste le filet de sécurité après que les 2 tentatives échouent.

### Tests

- [x] **T8 — Tests backend (AC: #1, #2, #3, #4)**
  - Fichier : `collega_backend/tests/api/test_colleges_reimport.py` (UPDATE)
    - Ajouter 2 tests d'atomicité (utiliser `asyncio.gather` pour requêtes parallèles, mocker `db.execute` avec `side_effect` qui simule le RETURNING). Assertions :
      - Test A : 2 imports concurrents → 1 succès, 1 `409 COLLEGE_RELOAD_LIMIT`, jamais `reload_count > max`
      - Test B : succès college mais user limit atteint → `409 MONTHLY_RELOAD_LIMIT`, ET le `College.reload_count` n'est pas incrémenté (rollback vérifié)
  - Fichier **NEW** : `collega_backend/tests/workers/test_monthly_reset.py`
    - 1 test cron : user avec `monthly_reloads=3, reset_at=hier` → après `reset_monthly_reloads({})`, `monthly_reloads=0, reset_at=premier_du_mois_prochain`
    - 1 test : user avec `monthly_reloads_reset_at=null` → pas touché (filtre `is_not(None)`)
    - Pattern : mocker `async_session_factory` comme dans `test_cleanup_worker.py:18-30`
  - Fichier : `collega_backend/tests/api/test_search.py` (UPDATE)
    - 1 test : 2 users distincts, même IP simulée → l'un dépasse 30 req/min, l'autre passe (mocker `request.state.user_id` via dependency override de `get_current_user`)
    - **NE PAS** tester le rate limit réel (slowapi avec storage Redis) — trop fragile. Tester la fonction `_user_id_key` isolément + asserter qu'elle est passée au décorateur.
  - Fichier : `collega_backend/tests/api/test_colleges_reimport.py` (UPDATE)
    - 1 test contrainte UNIQUE : forcer `db.commit()` à raise `IntegrityError` (mocker `db.commit` avec `side_effect=IntegrityError(...)`) → assertion `409 JOB_IN_PROGRESS`. **CRITIQUE** : ce test ne vérifie pas la contrainte SQL réelle (mockée) mais le handling côté code. La vérification SQL réelle se fait en migration test (T1 idempotent).

- [x] **T9 — Tests Flutter (AC: #5, #6)**
  - Fichier : `collega_app/test/features/colleges/college_import_notifier_test.dart` (UPDATE)
    - 1 test : `reconnectIfActive` appelle `ensureFreshAccessToken()` AVANT `_connectSse`. Pattern : mocker `ApiClient` avec un fake qui asserte l'ordre d'appel (compteur + flag).
    - 1 test : `ensureFreshAccessToken` retourne `false` → `_connectSse` n'est pas appelé.
  - Fichier **NEW** : `collega_app/test/features/drill/drill_repository_test.dart` (UPDATE) ou nouveau fichier dédié `drill_repository_evaluate_semantic_test.dart`
    - 1 test : Dio mock retourne `DioException(type: receiveTimeout)` 1 fois puis succès → assertion `evaluateSemantic` retourne `SemanticFeedback`, 2 appels HTTP capturés
    - 1 test : Dio mock retourne `DioException(type: receiveTimeout)` 2 fois → assertion `DioException` rethrown après 2 tentatives
    - 1 test : Dio mock retourne `DioException(response: 422)` → 1 seul appel (pas de retry sur 4xx), rethrown immédiatement
  - Pattern à utiliser : `MockClient` Dio ou `DioAdapter` (vérifier si `http_mock_adapter` est dans pubspec, sinon utiliser le pattern fake repository déjà en place — extending `DrillRepository` et override `evaluateSemantic`).

---

## Périmètre & Contraintes

- **1 migration Alembic** (`012_atomic_quota_and_unique_processing.py`) — doit être idempotente (down ok, re-up ok).
- **Aucune nouvelle dépendance** Python (slowapi, ARQ, SQLAlchemy, Alembic déjà présents) ni Flutter (Dio, Riverpod, secure_storage déjà présents).
- **Aucun changement de contrat API** côté frontend : les codes erreur restent identiques (`409 COLLEGE_RELOAD_LIMIT`, `409 MONTHLY_RELOAD_LIMIT`, `409 JOB_IN_PROGRESS`). Pas de nouveau code 429.
- **Aucun changement de DB sur les users existants** : la migration crée un index unique mais ne touche aucune ligne. Le cron monthly reset agit sur les comptes existants (si `reset_at < now`) — c'est le comportement attendu.
- **Compatibilité prod** : le NAS prod (`/mnt/user/appdata/compose-stacks/collega/.env`) tourne déjà la migration 011. La migration 012 doit pouvoir s'appliquer en place sans downtime (UNIQUE INDEX peut être créé `CONCURRENTLY` si la table est grosse — mais avec ~1 testeuse, ce n'est pas nécessaire ; utiliser `op.create_index` standard).
- **Pas de modification de `card_generator.py`** au-delà du retrait du double-incrément (T3) — c'est un fichier critique du worker, on touche le minimum.
- **Pas de modification de `auth_providers.dart`** côté Flutter — seul `ApiClient` gagne une méthode publique `ensureFreshAccessToken()`.
- **Stories 6.2 (DELETE compte) et 7.1 (UX FlashCard) sont closes** — on ne casse aucun de leurs comportements. En particulier : `app_router.dart` redirect `/demo → /home` (Story 7.1) reste intouché.

---

## Dev Notes — Contexte Technique Exhaustif

### Diagnostic A1 (atomicité reload — état actuel)

**Code router actuel** (`app/api/v1/colleges.py:184-218`) :
```python
if college.status == "generation_complete":
    now = datetime.now(timezone.utc)
    is_month_reset = (
        current_user.monthly_reloads_reset_at is None
        or now >= current_user.monthly_reloads_reset_at
    )
    effective_monthly = 0 if is_month_reset else current_user.monthly_reloads

    if college.reload_count >= settings.reload_count_max:
        raise HTTPException(409, ...)  # read-then-check

    if effective_monthly >= settings.monthly_reloads_max:
        raise HTTPException(409, ...)  # read-then-check

    if is_month_reset:
        current_user.monthly_reloads = 0
        current_user.monthly_reloads_reset_at = _next_month_reset(now)
```

**Le bug** : 2 requêtes concurrentes lisent `college.reload_count = 1` (max=2), passent toutes les 2 le check `< 2`, créent toutes les 2 un `GenerationJob`, et coûtent **2× appels Claude**. Seul le worker `card_generator.py:107-121` tente d'incrémenter atomiquement plus tard — mais à ce moment-là, le mal est fait.

**Code worker actuel (déjà atomique mais trop tard)** (`app/services/generation/card_generator.py:107-121`) :
```python
if is_reimport and not job.hash_shared:
    # P7: incréments atomiques via UPDATE conditionnel — pas de race condition
    await db.execute(
        sa_update(College)
        .where(College.id == college_id)
        .where(College.reload_count < settings.reload_count_max)
        .values(reload_count=College.reload_count + 1)
    )
    await db.execute(
        sa_update(User)
        .where(User.id == job.user_id)
        .where(User.monthly_reloads < settings.monthly_reloads_max)
        .values(monthly_reloads=User.monthly_reloads + 1)
    )
```
Ce code reste atomique individuellement mais **arrive trop tard** : le job est déjà créé, l'OCR + Claude ont déjà tourné. Conclusion : il faut **déplacer** l'incrément atomique au moment du check, dans le router. Et le retirer du worker (sinon double-incrément).

### Diagnostic A3 (rate limit search — état actuel)

**Décorateur actuel** (`app/api/v1/search.py:17-20`) :
```python
@router.get("/search")
@limiter.limit("30/minute")
async def search(
    request: Request, ...
```

**Limiter global** (`app/core/limiter.py:7-14`) :
```python
def _get_client_ip(request: Request) -> str:
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    return request.client.host if request.client else "unknown"

limiter = Limiter(key_func=_get_client_ip, storage_uri=settings.redis_url)
```

**Le bug** : 2 utilisatrices sur le même Wi-Fi fac (NAT) partagent l'IP → l'une fait 30 recherches en 1 minute → l'autre reçoit 429. Solution `slowapi` : override du `key_func` au niveau du décorateur (`@limiter.limit("30/minute", key_func=callable)`). Le `callable` reçoit `request: Request`.

**Référence slowapi** : la signature [`Limiter.limit(limit_value, key_func=None, ...)`](https://slowapi.readthedocs.io/en/latest/) accepte explicitement un `key_func` per-route qui override le global. Pas de breaking change attendu.

### Diagnostic A4 (race OCR — état actuel)

**Modèle `GenerationJob`** (`app/models/generation_job.py:16-46`) :
```python
class GenerationJob(Base):
    __tablename__ = "generation_jobs"
    __table_args__ = (
        CheckConstraint("status IN ('pending', 'processing', 'ocr_complete', 'generation_complete', 'failed')",
                        name="ck_generation_jobs_status"),
    )
    # ... colonnes avec college_id ForeignKey(index=True)
```
**Aucune UNIQUE** sur `(college_id, status)`. Le pre-check SELECT (`colleges.py:172-181` et `admin.py:81-95`) est non-atomique.

**Migration cible** :
```sql
CREATE UNIQUE INDEX idx_one_active_job_per_college
ON generation_jobs (college_id)
WHERE status IN ('pending', 'processing', 'ocr_complete');
```
Le partial index PostgreSQL est exactement le bon outil : autorise N jobs `generation_complete` ou `failed` par college (historique), mais 1 seul actif.

**SQLAlchemy → exception** : un `INSERT` qui viole un UNIQUE INDEX lève `sqlalchemy.exc.IntegrityError`. Pattern de catch (déjà utilisé `colleges.py:164` pour `College` UNIQUE) :
```python
db.add(job)
try:
    await db.commit()
except IntegrityError:
    await db.rollback()
    pdf_file_path.unlink(missing_ok=True)
    raise HTTPException(409, detail={"code": "JOB_IN_PROGRESS", ...})
```

### Diagnostic A5 (monthly reset — état actuel)

**Reset lazy actuel** (`app/api/v1/colleges.py:186-189, 220-223`) :
- À chaque tentative de reimport, on vérifie `now >= monthly_reloads_reset_at` et on reset si oui.
- **Problème** : si la testeuse ne fait pas de reimport pendant 2 mois, ses compteurs restent à `monthly_reloads=3` jusqu'à sa prochaine tentative. Pas un bug fonctionnel (lazy=correct) mais : (1) les métriques admin (`GET /v1/admin/users`) montrent des compteurs faussement saturés, (2) si on ajoute un endpoint "quotas disponibles" il pourrait mentir.

**Cron quotidien défensif** = source de vérité même sans tentative d'import. La logique lazy reste en filet de sécurité (au cas où le cron rate une exécution).

**Pattern ARQ existant** (`app/workers/settings.py:6-17`) :
```python
WORKER_SETTINGS = {
    "redis_settings": redis_settings,
    "functions": [process_college_ocr, generate_college_cards],
    "cron_jobs": [
        cron(cleanup_ocr_text, minute=0),
        cron(send_daily_reminders, minute=0),  # ⚠️ même minute → étaler
    ],
    "max_jobs": 10,
    ...
}
```
Décision : ajouter `cron(reset_monthly_reloads, hour=0, minute=5)` — à 00:05 UTC, après le cleanup de minuit, AVANT le pic d'usage matinal (utilisatrices en Europe : 8h-22h locale ≈ 7h-21h UTC). Aucune collision avec les 2 crons existants qui tournent à `minute=0` toutes les heures.

### Diagnostic A6 (JWT SSE figé — état actuel)

**Code actuel `SseClient`** (`lib/core/network/sse_client.dart:8-74`) :
```dart
class SseClient {
  SseClient(this._baseUrl, {required String Function() tokenProvider})
      : _tokenProvider = tokenProvider,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(hours: 3),  // SSE max 3h
        ));

  Stream<Map<String, dynamic>> connect(String path) async* {
    // ...
    final response = await _dio.get<ResponseBody>(
      '$_baseUrl$path',
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Authorization': 'Bearer ${_tokenProvider()}',  // appelé 1× à la connexion
          ...
        },
      ),
      cancelToken: _cancelToken,
    );
```

**Code actuel `CollegeImportNotifier._connectSse`** (`lib/features/colleges/colleges_import_providers.dart:_connectSse`) :
```dart
Future<void> _connectSse(String collegeId) async {
  await _sseSubscription?.cancel();
  final storage = ref.read(secureStorageProvider);
  final token = await storage.read(key: 'access_token') ?? '';
  _sseClient = SseClient(backendBaseUrl, tokenProvider: () => token);
  // ...
}
```

**Le bug A6** : `token` est capturé une seule fois par la closure `() => token`. Si l'access_token expire pendant les 3h max de la connexion SSE, et qu'une reconnexion se produit, le code re-lit `secureStorage` → ✅ OK pour le cas reconnect explicite. **Mais** : si le token a expiré entre la connexion initiale et le moment où le user revient en foreground (déclenchant `reconnectIfActive`), le token re-lu dans `secureStorage` peut lui-même être expiré (refresh non encore tenté) → la connexion SSE échoue avec 401 backend, et le `ApiClient` (qui gère le refresh) n'est même pas dans la chaîne d'appel (SseClient utilise un Dio dédié sans intercepteur refresh).

**La fix** : déclencher explicitement un `ensureFreshAccessToken()` AVANT chaque tentative de connexion SSE. Le `ApiClient._getRefresh()` (lignes 75-79) gère déjà les appels concurrents via `_isRefreshing`/`_refreshFuture` → safe d'appeler à chaque reconnect, no-op si déjà à jour.

### Diagnostic A9 (timeout evaluateSemantic — état actuel)

**Code actuel** (`lib/features/drill/data/drill_repository.dart:85-100`) :
```dart
Future<SemanticFeedback> evaluateSemantic(
    String cardId, String userAnswer) async {
  final response = await dio.post<Map<String, dynamic>>(
    '/v1/flash-cards/$cardId/evaluate-semantic',
    data: {'user_answer': userAnswer},
  );
  // ...
}
```
**Pas d'`Options` custom** → utilise `receiveTimeout: 30s` global de `ApiClient`. C'est probablement suffisant (Claude 1-3s en pratique), mais sans retry, un seul hiccup réseau → fallback flip silencieux (l'utilisatrice voit la réponse sans feedback sémantique). Pas dramatique en UX mais frustrant en perception qualité.

**La fix** : timeout local explicite à 15s (borne supérieure claire, indépendante du global) + retry 1× sur timeout/5xx. Le fallback drill_screen.dart:100 reste le filet final.

### Pattern Slowapi key_func per-route (AC: #3)

Référence : slowapi 0.x — l'API `@limiter.limit("rate", key_func=callable)` accepte un override du `key_func` global. Le callable doit avoir la signature `(request: Request) -> str`.

**Pattern recommandé** :
```python
def _user_id_key(request: Request) -> str:
    """Key func: user_id si auth, sinon IP fallback."""
    user_id = getattr(request.state, 'user_id', None)
    if user_id:
        return f"user:{user_id}"
    return _get_client_ip(request)
```

**Pourquoi le fallback IP** : si `request.state.user_id` n'est pas set (auth a échoué AVANT le rate limit), on ne veut pas bloquer arbitrairement sur "anon" (un seul slot pour tous les non-authentifiés = global ratelimit). Le fallback IP préserve le comportement raisonnable.

### Pattern PostgreSQL Partial Unique Index (AC: #4)

Alembic supporte le `postgresql_where` argument :
```python
op.create_index(
    "idx_one_active_job_per_college",
    "generation_jobs",
    ["college_id"],
    unique=True,
    postgresql_where=sa.text("status IN ('pending', 'processing', 'ocr_complete')"),
)
```

**Compatibilité SQLite (tests)** : SQLite supporte aussi les partial indexes depuis 3.8.0 (2014). Donc les tests `pytest` avec SQLite in-memory devraient passer. Vérifier dans `conftest.py` que les migrations sont jouées au setup (cf. fixture `client`).

**Defensive cleanup pre-index** : si deux jobs `pending` coexistent en prod (mode actuel non-atomique), l'index ne pourra pas être créé. La migration doit nettoyer avant :
```python
op.execute("""
    DELETE FROM generation_jobs g1
    USING generation_jobs g2
    WHERE g1.id != g2.id
      AND g1.college_id = g2.college_id
      AND g1.status IN ('pending', 'processing', 'ocr_complete')
      AND g2.status IN ('pending', 'processing', 'ocr_complete')
      AND g1.created_at > g2.created_at;
""")
```
En prod actuel (1 testeuse, mono-utilisateur), ce DELETE devrait être no-op. Mais c'est défensif pour les envs partagés.

### Pattern ARQ cron avec async session (AC: #2)

Le worker `cleanup_worker.py:15-33` est le pattern de référence :
```python
async def cleanup_ocr_text(ctx: dict) -> None:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    async with async_session_factory() as db:
        # ... select + update ...
        await db.commit()
        logger.info("Cleaned OCR text from %d items", result.rowcount)
```

**À reproduire pour `reset_monthly_reloads`** :
- `async with async_session_factory() as db:` — nouvelle session, pas FastAPI dependency
- `await db.commit()` explicit
- `logger.info` pour traçabilité
- Pas de `try/except` (ARQ retry automatique via `retry_jobs=True, max_retries=3` cf. settings.py:13-14)

### Conventions de tests backend (cf. `conftest.py`, `test_colleges_reimport.py`)

- **Fixture `mock_db`** : `AsyncMock` avec méthodes `get`, `execute`, `add`, `commit`, `refresh`, `delete` (cf. conftest.py).
- **Fixture `client`** : injecte `mock_db` via `app.dependency_overrides[get_db]`.
- **Override `get_current_user`** : `app.dependency_overrides[get_current_user] = lambda: _make_user()` (pattern testfile L.34).
- **`mock_db.execute.side_effect`** : liste de `MagicMock(scalar_one_or_none=...)` pour chaîner les requêtes SQL successives (L.50-55).
- **Test parallèle** : `await asyncio.gather(client.post(...), client.post(...))` pour simuler la concurrence. Note : avec `mock_db` partagé, ce n'est pas une vraie concurrence DB — mais ça vérifie le code path. Pour les tests de race réels, utiliser pytest-asyncio + une vraie DB (postgres test container) si l'effort en vaut la peine ; sinon mock + assertion d'ordre d'appel suffit.

### Conventions de tests Flutter (cf. `auth_providers_test.dart`, `drill_repository_test.dart`)

- **Pattern `_FakeXxxRepository extends XxxRepository`** : héritage simple, override des méthodes utilisées. Pas de `mocktail` (pas dans pubspec.yaml).
- **Pattern `_FakeAuthNotifier`** : déjà utilisé Story 6.2 / 7.1 dans `profile_screen_test.dart` et `app_router_test.dart`.
- **Pour Dio mock** : pas de `http_mock_adapter` dans pubspec. Pattern actuel : `_FakeXxxRepository` qui override l'appel HTTP avec un fake Dio (ou un fake repository qui ne fait pas d'appel Dio). Si on veut vraiment tester Dio en timeout, on peut :
  - Créer un fake `Dio` qui lance `DioException(type: receiveTimeout, requestOptions: ...)` selon un compteur (`int callCount = 0; ... if (callCount < 1) throw timeout; else return success;`)
  - Injecter ce fake via le constructeur de `DrillRepository(dio: fakeDio)` (vérifier que le repo accepte un Dio injectable — sinon adapter le constructeur)

### Stack technique vérifiée

**Backend** (`requirements.txt` / `pyproject.toml`) :
- Python 3.11+ (FastAPI 0.110+)
- SQLAlchemy 2.x (async ORM, mapped_column)
- Alembic ~1.13
- slowapi ~0.1.9 (rate limiting)
- ARQ 0.25+ (worker async Redis)
- aioapns (push notifications, hors scope cette story)
- Pydantic v2 (BaseModel, validators)

**Frontend** (`pubspec.yaml`) :
- Flutter 3.6+
- `flutter_riverpod: ^2.6.1` / `riverpod_annotation: ^2.6.1`
- `dio: ^5.7.0`
- `go_router: ^14.6.3`
- `flutter_secure_storage: ^9.2.2`
- `drift: ^2.21.0`
- `shadcn_ui: ^0.19.0`
- Pas de package SSE externe — `SseClient` est custom

Aucune mise à jour de version requise pour cette story.

### Anti-patterns à éviter

- **NE PAS** mettre l'UPDATE atomique reload_count + monthly_reloads dans le worker `card_generator.py` (où il est aujourd'hui partiellement) — le job est créé AVANT, le coût Claude est déjà payé. La sémantique de la limite "tu ne peux pas relancer N fois" doit s'appliquer **au moment de la soumission**.
- **NE PAS** utiliser `429 RELOAD_LIMIT_REACHED` comme suggéré par l'epic — le code Flutter existant catch déjà les `409 COLLEGE_RELOAD_LIMIT` (cf. `college_reimport_test.dart`). Garder le contrat 409 pour ne pas casser l'UX (snackbar "Limite atteinte").
- **NE PAS** modifier le `Limiter` global pour passer en `key_func=user_id` — casse `/login` (pré-auth, pas de user_id) et `DELETE /account` (où on veut limiter par IP pour ralentir le brute force même post-auth).
- **NE PAS** ajouter `request.state.user_id` dans `require_subscription` au lieu de `get_current_user` — `require_subscription` dépend de `get_current_user`, donc la modif doit être au niveau le plus bas pour bénéficier à toutes les routes authentifiées.
- **NE PAS** factoriser `_next_month_reset` dans une classe ou un service avec injection — c'est une fonction pure utilitaire. Module `time_utils.py` suffit.
- **NE PAS** créer la migration sans le defensive cleanup pre-index — en prod actuelle (1 user) c'est probablement no-op, mais en dev partagé (CI, autres devs), des jobs orphelins peuvent exister et bloquer le `CREATE UNIQUE INDEX`.
- **NE PAS** modifier `SseClient.connect()` pour gérer le refresh interne — le pattern actuel (SseClient générique + notifier orchestrateur) est testable et conforme à Pattern #1 rétro MVP. Si on couplait SseClient à ApiClient, on perd la flexibilité (et on a un import circulaire potentiel).
- **NE PAS** changer `tokenProvider: () => token` en `tokenProvider: () async => ...` — la signature `String Function()` est synchrone et utilisée à l'intérieur d'`Options.headers`. Changer en async demanderait de réécrire la résolution des headers.
- **NE PAS** retry sur 4xx (sauf 5xx) dans `evaluateSemantic` — le 422 indique une malformation du body, retry ne corrigera pas. Seuls timeout + 5xx méritent le retry.
- **NE PAS** ajouter de retry sur les autres endpoints Dio en passant (search, colleges, etc.) — c'est hors scope, et chaque endpoint a sa propre tolérance. Concentrer le retry sur `evaluateSemantic` qui est connu pour avoir une latence Claude variable.
- **NE PAS** print()/debugPrint() en code prod (cf. architecture L.310 enforcement) — utiliser `AppLogger.warning(...)` / `logger.info(...)`.
- **NE PAS** créer de nouvelles dépendances Python (ex: `httpx-retry`, `tenacity`) — la logique de retry est triviale en boucle for/try.
- **NE PAS** modifier `app_router.dart` (Flutter) — Story 7.1 vient juste de stabiliser le redirect `/demo`, ne pas y toucher.

---

## Previous Story Intelligence — Learnings 6.x et 7.1

- **Story 6.2 (`auth_providers.dart`, `AppDatabase.deleteEverything()`)** : pattern de catch + rollback Flutter pour les opérations multi-étapes. Réutilisable pour les retries dans `evaluateSemantic`. Le pattern Riverpod `_FakeAuthNotifier` (dans `profile_screen_test.dart`) reste la référence pour mocker `authProvider`/`ApiClient`.
- **Story 7.1 (FlashCard `_handleTap`)** : le pattern `_localExitResult` (copie locale du widget state pour didUpdateWidget) n'est pas applicable ici, mais la **discipline des early returns** (`if (refreshOk == false) return;`) est à reproduire — pas de side-effects silencieux.
- **Rétro MVP § Pattern #2 (async correctness)** : tous les bugs A1-A10 sont des manifestations du même thème : **opérations distribuées sans atomicité ni source de vérité unique**. La fix doit toujours réduire le nombre de checkpoints fragiles, pas en ajouter. Exemple : déplacer l'incrément reload_count au router (1 checkpoint atomique) est mieux qu'ajouter un deuxième check ailleurs (2 checkpoints à synchroniser).
- **Rétro MVP § Pattern #4 (Riverpod state)** : éviter le `unawaited()` fire-and-forget pour le refresh SSE — `await ref.read(apiClientProvider).ensureFreshAccessToken()` retourne `Future<bool>` qu'on doit consommer.
- **Rétro MVP § Pattern #5 (SDK gotchas)** : `slowapi` 0.x — vérifier que `key_func` per-route est bien supporté. Si problème, fallback temporaire : créer 2 `Limiter` (un global par IP, un par user) et utiliser le bon selon l'endpoint. Mais l'override par décorateur est la voie standard.
- **Sécurité existante** (cf. mémoire `project_security.md` 2026-05-08) : `/register` 403 par design, `/login` `5/min`, `DELETE /account` `3/min`, `/regenerate` `10/hour`, `/notifications/*` `10/min` — toutes ces routes **doivent rester par IP** (pas par user_id). Seul `/search` change.

---

## Git Intelligence — Commits récents pertinents

```
8b2c131 feat(story-7.1): corrections UX FlashCard & Router
7361a30 chore(sprint): MVP retro 2026-05-19 — epics 1→6 done + Epic 7 ouvert
45f736a fix(colleges): augmente la limite d'import PDF à 500 MB
502a0cd feat(epic-6): Story 6.2 — suppression de compte & conformité RGPD
2baa87d feat(epic-6): Story 6.1 — écran profil & préférences de révision
```

- **`8b2c131` (Story 7.1)** : aucun chevauchement de fichiers avec cette story (router/widget Flutter uniquement). Conflit attendu : 0.
- **`45f736a`** : a touché `colleges.py` (la constante `_MAX_PDF_SIZE = 500 MB`). Cette story va modifier la même fonction `import_college_pdf` — **lire le diff avant pour comprendre la structure actuelle**, mais sans interférence avec les quotas (la limite PDF est orthogonale à reload_count).
- **`502a0cd` (Story 6.2)** : a touché `auth_providers.dart` et `app_router.dart`. Cette story ajoute une méthode publique `ensureFreshAccessToken()` à `ApiClient` — pas de conflit avec la logique logout/redirect de 6.2.

Aucun WIP en cours sur ces fichiers (`git status` clean à l'ouverture).

---

## Project Context Reference

- **Stack backend** : Python 3.11 / FastAPI / SQLAlchemy 2 async / Alembic / ARQ workers / slowapi rate limit / PostgreSQL prod, SQLite tests.
- **Stack mobile** : Flutter 3.6+ / Riverpod 2.6 / GoRouter 14.6 / Dio 5.7 / shadcn_ui 0.19 / Drift 2.21 / flutter_secure_storage 9.2.
- **Conventions backend** : snake_case partout, dependency injection FastAPI (`Depends`), Pydantic BaseModel pour schemas, `{ "data": ... } / { "error": ... }` wrapper sur tous les endpoints, `logger.info/warning/error` (pas de `print`).
- **Conventions Flutter** : feature-first (`features/[domain]/{data,domain,presentation,widgets}`), AsyncNotifier pour state async, `AppLogger.warning(..., tag: 'ClassName')` (pas de `print`).
- **Architecture découplée** (Pattern #1 rétro) : préserver l'abstraction `NotificationService`, `SimilarityChecker`, `SseClient` — ne pas coupler ces composants à des dépendances spécifiques.
- **NAS prod** : `.env` déjà configuré sur `/mnt/user/appdata/compose-stacks/collega/.env` — **NE PAS** écraser ce fichier (mémoire `project_nas_env.md`).

---

## Latest Tech Information

- **slowapi 0.1.9+** : l'API `@limiter.limit("rate", key_func=callable)` est stable depuis 2022. Pas de breaking change attendu. Doc : https://slowapi.readthedocs.io/en/latest/#per-route-limits
- **SQLAlchemy 2 async + `.returning()`** : disponible depuis 2.0 (2023). Pattern `update(...).returning(Column)` renvoie un `Result` dont on extrait `.scalar_one_or_none()`. Aucun problème sur PostgreSQL ; sur SQLite tests, `RETURNING` est supporté depuis 3.35.0 (2021).
- **ARQ 0.25+** : `cron()` accepte `hour=0, minute=5` pour 00:05 UTC chaque jour. Pas de breaking change.
- **PostgreSQL partial index** : feature stable depuis PG 8.0 (2005). Aucune contrainte de version.
- **Dio 5.7** : `Options(receiveTimeout: ...)` per-request override le `BaseOptions` du Dio parent. Pattern stable depuis 5.x.
- **flutter_apns_only / aioapns** : hors scope cette story (Story 7.4 traitera A10).

---

## References

### Epic & spec
- Story 7.2 epic spec : `_bmad-output/planning-artifacts/epics-v1.1.md` L.142-196
- Items source A1, A3, A4, A5, A6, A9 : `_bmad-output/implementation-artifacts/epic-mvp-retro-2026-05-19.md` § 4 (table priorisée beta)
- PRD MVP (FRs inchangés) : `_bmad-output/planning-artifacts/prd.md`
- Architecture : `_bmad-output/planning-artifacts/architecture.md`

### Backend Python
- Router import (à modifier) : `collega_backend/app/api/v1/colleges.py:133-310` (fonction `import_college_pdf`)
- Router admin (race OCR) : `collega_backend/app/api/v1/admin.py:73-159` (fonction `process_college`)
- Router search (rate limit) : `collega_backend/app/api/v1/search.py:17-28`
- Dep auth : `collega_backend/app/deps.py:57-84` (`get_current_user` à modifier)
- Limiter global : `collega_backend/app/core/limiter.py:7-14`
- Modèle College : `collega_backend/app/models/college.py:43` (`reload_count`)
- Modèle User : `collega_backend/app/models/user.py:30-34` (`monthly_reloads`, `monthly_reloads_reset_at`)
- Modèle GenerationJob : `collega_backend/app/models/generation_job.py:16-61`
- Config quotas : `collega_backend/app/core/config.py:14-15` (`reload_count_max`, `monthly_reloads_max`)
- Worker cleanup (pattern) : `collega_backend/app/workers/cleanup_worker.py:15-33`
- Worker settings ARQ : `collega_backend/app/workers/settings.py:6-17`
- Service worker actuel (incrément à retirer) : `collega_backend/app/services/generation/card_generator.py:97-121`
- Migrations Alembic : `collega_backend/alembic/versions/` (dernière = 011 ; nouvelle = 012)
- Migration `_next_month_reset` : `collega_backend/app/api/v1/colleges.py:44-48` (à factoriser dans `app/core/time_utils.py`)

### Frontend Flutter
- ApiClient + refresh : `collega_app/lib/core/network/api_client.dart:13-96` (méthode `_getRefresh` à exposer en `ensureFreshAccessToken`)
- SseClient : `collega_app/lib/core/network/sse_client.dart:8-74`
- CollegeImportNotifier : `collega_app/lib/features/colleges/colleges_import_providers.dart` (méthodes `_connectSse`, `reconnectIfActive`)
- DrillRepository : `collega_app/lib/features/drill/data/drill_repository.dart:85-100` (méthode `evaluateSemantic`)
- DrillScreen fallback : `collega_app/lib/features/drill/presentation/drill_screen.dart:93-104` (`_handleDefinitionSubmit`)
- AuthState : `collega_app/lib/features/auth/domain/auth_state.dart:54-78`

### Tests existants (patterns)
- `collega_backend/tests/api/test_colleges_reimport.py` (pattern dep override + mock_db.side_effect)
- `collega_backend/tests/api/test_search.py` (pattern test endpoint authentifié)
- `collega_backend/tests/workers/test_cleanup_worker.py` (pattern mock `async_session_factory`)
- `collega_backend/conftest.py` (fixtures `mock_db`, `client`)
- `collega_app/test/features/auth/auth_providers_test.dart` (pattern `_FakeAuthRepository`)
- `collega_app/test/features/colleges/college_import_notifier_test.dart` (pattern test notifier SSE)
- `collega_app/test/features/drill/drill_repository_test.dart` (pattern test repo Drift)
- `collega_app/test/features/profile/profile_screen_test.dart` (Story 6.2 — pattern `_FakeAuthNotifier`)
- `collega_app/test/core/router/app_router_test.dart` (Story 7.1 — pattern test router)

### Stories adjacentes
- Story 7.1 (UX FlashCard) : `_bmad-output/implementation-artifacts/7-1-corrections-ux-flashcard-router.md`
- Story 6.2 (DELETE compte) : `_bmad-output/implementation-artifacts/6-2-suppression-compte-conformite-rgpd.md`
- Story 6.1 (Profil) : `_bmad-output/implementation-artifacts/6-1-ecran-profil-preferences.md`
- Story 3.2 (SSE) : `_bmad-output/implementation-artifacts/3-2-import-pdf-progression-ocr-temps-reel.md`
- Story 3.4 (Quotas) : `_bmad-output/implementation-artifacts/3-4-hash-sharing-limites-reimport.md`

---

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) — `claude-opus-4-7[1m]`

### Debug Log References

- 29 tests backend ciblés (test_colleges_reimport, test_monthly_reset, test_search, test_card_generator, test_cleanup_worker) → **29 passed**.
- Suite backend complète : 230 passed, 1 skipped, **9 failures pré-existantes non liées à la story** (8× `passlib`/`bcrypt` incompatible Python 3.14 sur `test_auth.py`, 1× `test_register_token_ok` 422 préexistant). Vérifié via `git stash` sur HEAD propre — les mêmes failures sont reproduites avant tout changement.
- Tests Flutter ciblés (college_import_notifier + drill_repository) → **17 passed** (warnings drift "multiple databases" inoffensifs, déjà présents avant cette story).
- Suite Flutter ciblée drill + colleges (82 tests) → **All tests passed!**
- Suite Flutter complète : 170 passed, 6 failures pré-existantes non liées à la story (3× `home/home_screen_test.dart` HomeReady, 2× `home/home_notifier_test.dart` HomeReady, 1× `search/search_notifier_test.dart` onQueryChanged loading). Ces tests touchent uniquement `lib/features/home/` et `lib/features/search/` — dossiers non modifiés. Seul `search_providers.dart` dépend d'`ApiClient`, mais le test échoue avec `Expected: true, Actual: false` sur un timing isLoading (race async dans le test, pas un effet de l'ajout pur de `ensureFreshAccessToken()`).

### Completion Notes List

**Architecture livrée :**

- **AC #1 (atomicité quotas)** — Refactor `import_college_pdf` (`app/api/v1/colleges.py:179-237`) : remplacement du read-then-check par 2 `UPDATE … WHERE … < max … RETURNING column`. Ordre critique : College avant User. Si User RETURNING None → `await db.rollback()` explicite annule l'incrément College fait juste avant. L'incrément doublon dans `card_generator.py:107-121` a été retiré (avec ses imports devenus inutiles `College`, `User`, `settings`, `sa_update`).
- **AC #2 (cron monthly reset)** — Fonction `reset_monthly_reloads` ajoutée dans `cleanup_worker.py` avec un seul UPDATE batch sur les users dont la fenêtre est échue. Cron `hour=0, minute=5` dans `settings.py` (décalé de minuit pour éviter la collision avec `cleanup_ocr_text` à `minute=0`). `_next_month_reset` factorisé dans `app/core/time_utils.py` pour éviter l'import circulaire entre router et worker.
- **AC #3 (rate limit `/search` par user_id)** — `get_current_user` (`app/deps.py:67-114`) accepte désormais `request: Request` en premier paramètre et peuple `request.state.user_id = str(user.id)`. `/v1/search` utilise `@limiter.limit("30/minute", key_func=_user_id_key)` avec fallback IP si `request.state.user_id` est absent. Le `Limiter` global est inchangé (préserve les comportements `/login`, `/account`, `/regenerate`, `/notifications/*`).
- **AC #4 (race OCR)** — Migration `012_atomic_quota_and_unique_processing.py` : defensive cleanup pre-index (supprime les éventuels doublons actifs antérieurs en gardant le plus ancien), puis `CREATE UNIQUE INDEX … (college_id) WHERE status IN ('pending','processing','ocr_complete')`. Catch `IntegrityError` ajouté aux `commit()` de `colleges.py:import_college_pdf` et `admin.py:process_college` → 409 `JOB_IN_PROGRESS` (UX identique au pre-check existant).
- **AC #5 (refresh JWT avant SSE)** — Méthode publique `ApiClient.ensureFreshAccessToken()` (wrapper de `_getRefresh()` pour réutiliser le verrou `_isRefreshing`). `CollegeImportNotifier._connectSse` appelle `await ref.read(apiClientProvider).ensureFreshAccessToken()` avant chaque connexion SSE ; si `false`, log warning et early-return (le force-logout est déjà câblé via l'intercepteur Dio).
- **AC #6 (timeout/retry evaluateSemantic)** — Boucle `for (attempt = 1; attempt <= maxAttempts; attempt++)` dans `drill_repository.dart:evaluateSemantic` avec `Options(receiveTimeout: 15s, sendTimeout: 10s)` local. Retry seulement sur `receiveTimeout`, `connectionTimeout`, et 5xx ; 4xx (422 inclus) rethrow immédiat. Le fallback `drill_screen.dart` (`catch (_) → notifier.flip()`) reste le filet ultime.

**Décisions techniques notables :**

- **Compatibilité tests** — Pour `_user_id_key`, le test `_user_id_key_fallback_ip_si_pas_de_user` utilise `del request.state.user_id` pour reproduire l'absence — Slowapi expose la même fonction publiquement via le décorateur, donc test direct + fallback. Pas d'instrumentation Redis.
- **Compatibilité prod** — `op.create_index(..., postgresql_where=..., sqlite_where=...)` permet à la migration de tourner en CI (SQLite) ET en prod (PostgreSQL).
- **No-op architecture** — Aucune nouvelle dépendance Python/Flutter ajoutée. Pas de changement de contrat API (codes `409 COLLEGE_RELOAD_LIMIT`, `MONTHLY_RELOAD_LIMIT`, `JOB_IN_PROGRESS` préservés).
- **NAS prod préservé** — Aucune modification de `.env` ; la migration 012 peut être appliquée par `alembic upgrade head` sans downtime.

**Risques connus / suite :**

- Les 9 failures pré-existantes (bcrypt/passlib + APNS register 422) ne sont pas adressées dans cette story (hors scope hardening async). Reportées à la story OP-2 (validation IAP/sandbox) ou à un nettoyage d'environnement Python séparé.
- Si la migration 012 est appliquée sur un environnement où plusieurs jobs `pending` coexistent, le defensive cleanup les déduplique en gardant le plus ancien (logué en WARNING). En prod actuelle (1 testeuse), ce cleanup est attendu no-op.

### File List

**Nouveaux fichiers (Created)**
- `collega_backend/alembic/versions/012_atomic_quota_and_unique_processing.py`
- `collega_backend/app/core/time_utils.py`
- `collega_backend/tests/workers/test_monthly_reset.py`

**Fichiers modifiés (Modified)**
- `collega_backend/app/api/v1/colleges.py` — atomicité quotas + catch IntegrityError + factorisation `_next_month_reset`
- `collega_backend/app/api/v1/admin.py` — catch IntegrityError sur process_college
- `collega_backend/app/api/v1/search.py` — décorateur `key_func=_user_id_key`
- `collega_backend/app/deps.py` — `get_current_user(request: Request, …)` peuple `request.state.user_id`
- `collega_backend/app/services/generation/card_generator.py` — retrait du double-incrément
- `collega_backend/app/workers/cleanup_worker.py` — nouvelle fonction `reset_monthly_reloads`
- `collega_backend/app/workers/settings.py` — cron `reset_monthly_reloads` 00:05 UTC
- `collega_backend/tests/api/test_colleges_reimport.py` — tests adaptés au pattern UPDATE+RETURNING + nouveau test IntegrityError
- `collega_backend/tests/api/test_search.py` — tests `_user_id_key`
- `collega_app/lib/core/network/api_client.dart` — exposition `ensureFreshAccessToken()`
- `collega_app/lib/features/colleges/colleges_import_providers.dart` — refresh JWT avant `_connectSse`
- `collega_app/lib/features/drill/data/drill_repository.dart` — timeout 15s + retry 1× sur evaluateSemantic
- `collega_app/test/features/colleges/college_import_notifier_test.dart` — tests SSE refresh
- `collega_app/test/features/drill/drill_repository_test.dart` — tests Dio scripted adapter timeout/retry/4xx

### Change Log

- 2026-05-20 — feat(story-7.2) : hardening async backend (A1 atomicité quotas, A3 rate limit user, A4 race OCR, A5 cron monthly reset, A6 refresh JWT SSE, A9 timeout/retry evaluateSemantic).
- 2026-05-22 — code review multi-layer (Blind Hunter + Edge Case Hunter + Acceptance Auditor) : voir section *Review Findings* ci-dessous.

### Review Findings

_Code review effectuée le 2026-05-22 via `bmad-code-review` (3 layers : Blind Hunter, Edge Case Hunter, Acceptance Auditor). Vérifications croisées effectuées dans le code source pour éliminer les faux positifs (notamment `expire_on_commit=False`, absence de `SlowAPIMiddleware`, comportement réel de `_tryRefresh()`)._

**Acceptance Auditor verdict** : PASS-with-gaps mineurs — 5/6 AC en full pass, AC4 partial (admin.py:111 pre-check incomplet), 13/13 anti-patterns respectés, 10/10 contraintes respectées.

#### Décisions résolues (devenues patches)

- [x] [Review][Decision-Resolved] Régression hash-sharing — **Décision : compenser dans le worker (a posteriori)**. Voir patch P10 ci-dessous.
- [x] [Review][Decision-Resolved] Double-reset cron + lazy reset frontière mois — **Décision : patch cron ignorer fenêtres juste expirées (< 1h)**. Voir patch P11 ci-dessous.

#### Patches (fixables sans décision)

- [x] [Review][Patch] `_connectSse` early-return silencieux laisse l'UI bloquée en `ImportStreaming` [colleges_import_providers.dart:94-101] — si `ensureFreshAccessToken()` retourne `false`, on `return` sans transition d'état. Le commentaire "force logout est déjà câblé" est faux : `onForceLogout` est seulement câblé à l'intercepteur 401 (`api_client.dart:67`), pas à un échec de `_tryRefresh`. **Fix** : `state = AsyncValue.data(ImportError(message: 'session_expired'))` avant le `return`.
- [x] [Review][Patch] Migration 012 cleanup ne tie-break pas sur `id` [012_atomic_quota_and_unique_processing.py:33-43] — deux doublons avec `created_at` strictement identique survivent → CREATE UNIQUE INDEX échoue. **Fix** : `OR (g1.created_at = g2.created_at AND g1.id > g2.id)`.
- [x] [Review][Patch] `evaluateSemantic` ignore `DioExceptionType.connectionError` et n'a pas de backoff [drill_repository.dart:106-110] — blip réseau cellulaire → fallback immédiat sans retry. **Fix** : ajouter `connectionError` à `isRetriable` + `await Future.delayed(Duration(milliseconds: 500))` entre tentatives.
- [x] [Review][Patch] Race notifier disposé pendant `await ensureFreshAccessToken()` [colleges_import_providers.dart:94-105] — si le notifier est disposé pendant l'await refresh (user navigate), le code crée un nouveau `SseClient` jamais nettoyé. **Fix** : `if (!ref.mounted) return;` après l'await.
- [x] [Review][Patch] `admin.py` pre-check oublie `ocr_complete` [admin.py:111] — l'index partial couvre `('pending','processing','ocr_complete')` mais le pre-check admin saute `ocr_complete`. Filet IntegrityError attrape, mais incohérent avec `colleges.py:171`. **Fix** : aligner sur `["pending","processing","ocr_complete"]`.
- [x] [Review][Patch] `next_month_reset` ne valide pas `now.tzinfo is not None` [time_utils.py:7-17] — datetime naive renvoie naive sans warning. **Fix** : `assert now.tzinfo is not None`.
- [x] [Review][Patch] Test `test_search_decorator_utilise_user_id_key` ne teste rien d'utile [test_search.py:184] — vérifie juste que `_user_id_key` est callable. **Fix** : remplacer par un test d'introspection du décorateur slowapi OU supprimer.
- [x] [Review][Patch] `_user_id_key` fallback IP sans préfixe namespace [search.py:23,27] — risque collision théorique avec un user_id contenant `user:` + debug Redis difficile. **Fix** : `return f"ip:{_get_client_ip(request)}"`.
- [x] [Review][Patch] Import privé `_get_client_ip` (convention violée) [search.py:10 + limiter.py:7] — couplage fragile. **Fix** : promouvoir `_get_client_ip → get_client_ip` dans `limiter.py`.
- [x] [Review][Patch] **(P10 / ex-Décision 1)** Compenser le quota côté worker si `hash_shared=True` [card_generator.py] — restaurer la sémantique "reimport gratuit ne compte pas". **Fix** : après détection `hash_shared=True` dans le worker, décrémenter atomiquement `College.reload_count` et `User.monthly_reloads` (UPDATE conditionnel `WHERE reload_count > 0` + `WHERE monthly_reloads > 0` pour éviter underflow).
- [x] [Review][Patch] **(P11 / ex-Décision 2)** Cron `reset_monthly_reloads` skip les fenêtres juste expirées (< 1h) [cleanup_worker.py:54-66] — empêche le double-reset à la frontière du mois. **Fix** : remplacer `.where(User.monthly_reloads_reset_at <= now)` par `.where(User.monthly_reloads_reset_at <= now - timedelta(hours=1))`.

#### Deferred (pré-existant ou hors scope)

- [x] [Review][Defer] Migration 012 sans `IF NOT EXISTS` — convention Alembic acceptable via cycle up/down — deferred, design call.
- [x] [Review][Defer] Test AC2 e2e replay reimports manquant — gap couverture, comportement validé par mocks.
- [x] [Review][Defer] Mois sautés du cron sans log d'audit [cleanup_worker.py] — edge case rare, non-correctness.
- [x] [Review][Defer] `_ScriptedAdapter` abstraction Dio fragile [drill_repository_test.dart] — qualité test, non-bug.
- [x] [Review][Defer] Mock `side_effect` ordonné fragile [test_colleges_reimport.py] — refactor test coûteux pour gain marginal.
- [x] [Review][Defer] Rate limit bypass partiel sur 401 tokens invalides [deps.py + search.py] — pré-existant (le `Limiter` global tombe en fallback IP avant Depends), hors scope hardening async.

#### Dismissed (faux positifs / pas un bug)

Findings écartés après vérification du code source (11 au total) :
- **Quota incrémenté avant validation PDF / commit** — vérifié : `get_db` ferme la session sans commit sur exception → atomic UPDATEs non persistés. Pas de bug.
- **slowapi évalue avant Depends** — vérifié : pas de `SlowAPIMiddleware` dans `main.py` → décorateur appelle `_user_id_key` APRÈS `get_current_user`. AC #3 fonctionne en runtime.
- **SSE token snapshot capture String immuable** — design documenté dans spec L.266-268 (reconnexion explicite + refresh défensif suffisent).
- **`ensureFreshAccessToken` no-op si token valide** — `_tryRefresh()` appelle toujours `/v1/auth/refresh` (vrai refresh serveur).
- **`FakeApiClient` instancie `FlutterSecureStorage` réel** — constructeur sans I/O.
- **`db.rollback()` détache `current_user`** — `expire_on_commit=False` → attributs en mémoire restent valides.
- **`rollback` annule également le lazy reset persisté** — vérifié : le rollback (branche MONTHLY_RELOAD_LIMIT) n'est atteignable QUE si `is_month_reset=False` (sinon `monthly_reloads=0` après flush et l'atomic UPDATE réussit). Pas de scénario où lazy reset flushé coïncide avec rollback.
- **`lastError` non peuplé pour exceptions non-Dio** — dead code, exception non-Dio propage directement.
- **`sendTimeout` sans retry** — design (upload coûteux).
- **`reset_monthly_reloads` log même si rowcount=0** — nit ops.
- **`builtins.open` patché trop large** [test_colleges_reimport.py] — pattern courant, fonctionne en pratique.
