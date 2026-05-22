# Story 7.3 : Hardening RGPD Safe-Delete & Sécurité Config

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur**,
je veux que la suppression de compte soit **atomique côté client** (jamais d'état zombie où le backend a supprimé l'utilisateur mais que Flutter garde tokens/data, et symétriquement jamais de wipe local si le serveur n'a pas confirmé) et que la **configuration backend refuse de démarrer en prod** avec des credentials par défaut faibles,
afin de garantir la conformité RGPD (aucune donnée orpheline locale, aucun compte non purgé serveur) et d'**éliminer toute possibilité de déploiement prod avec `secret_key="change-me"` ou `claude_api_key=""`**.

**Items source :** A2 + dette infrastructure pré-prod (cf. `_bmad-output/planning-artifacts/epics-v1.1.md` L.199-248 et `_bmad-output/implementation-artifacts/epic-mvp-retro-2026-05-19.md` § 4 et § "dette infra").

---

## Acceptance Criteria

1. **AC1 — A2 (partie 1) : DELETE serveur échec → aucun wipe local, session intacte**
   - **Étant donné** un utilisateur authentifié qui clique "Supprimer définitivement" dans le dialog de confirmation de l'`_AppCard` (`profile_screen.dart:537`)
   - **Quand** la requête `DELETE /v1/auth/account` échoue (timeout Dio, `connectionError`, 5xx serveur, ou rate limit 429)
   - **Alors** :
     - **Aucune** méthode locale destructive n'est appelée : `Purchases.logOut()` non appelé, `AppDatabase.deleteEverything()` non appelé, `secureStorage` non vidé, `authProvider.state` non réinitialisé
     - Un `ShadToast.destructive` (overlay root, déjà câblé via `ShadApp.router` dans `app.dart`) s'affiche avec un message extrait via `_extractError(DioException)` (pattern existant) — exemples : "Erreur réseau, veuillez réessayer", "Cet email est déjà utilisé" (impossible ici), ou le `detail.message` retourné par le backend
     - L'utilisateur reste sur l'écran Profil, session intacte, et **peut retenter** en re-cliquant (la requête est resoumise — soumise au rate limit backend `@limiter.limit("3/minute")` déjà présent sur `auth.py:136`)
     - Le bouton "Supprimer mon compte" est réactivé (`_deleting=false`) après la réception de l'erreur

2. **AC2 — A2 (partie 2) : DELETE serveur 401 (token expiré) → ne wipe pas, propose action**
   - **Étant donné** un utilisateur dont l'access_token est expiré au moment du clic (cas iOS background prolongé)
   - **Quand** la requête `DELETE /v1/auth/account` revient `401` (le refresh est tenté par l'intercepteur `ApiClient` puis échoue car refresh_token expiré aussi) OU si `accessToken == null` dans `secureStorage`
   - **Alors** :
     - `auth_repository.dart::deleteAccount()` retourne `AuthState(errorMessage: 'Session expirée — reconnecte-toi avant de supprimer ton compte')` au lieu de l'`AuthState()` vide actuel
     - Aucun wipe local n'est exécuté
     - Le toast destructive affiche ce message
     - **Comportement attendu côté router** : l'intercepteur Dio (`api_client.dart:67`) catch déjà les 401 et tente un refresh ; si le refresh échoue, il déclenche `forceLogoutSignalProvider` → `AuthNotifier.build` listener reset `state = AsyncData(AuthState())` → guard reactive GoRouter redirige vers `/demo`. Dans ce cas, le toast destructive **peut ou peut ne pas** être visible (race entre toast affiché et redirect). **Acceptable** — le critère AC2 est que `auth_repository::deleteAccount` retourne un `errorMessage` non-vide et ne wipe rien lui-même ; l'expérience UI exacte dépend de la race avec le force logout existant.
     - Si l'intercepteur ne déclenche pas le force logout (cas `accessToken == null` lu directement par `deleteAccount` sans appel HTTP), l'utilisateur reste sur Profil ; il peut taper "Se déconnecter" puis se reconnecter manuellement

3. **AC3 — A2 (partie 3) : DELETE serveur succès → séquence ordonnée RC → Drift → storage → state**
   - **Étant donné** un utilisateur authentifié qui confirme la suppression
   - **Quand** la requête `DELETE /v1/auth/account` réussit (200)
   - **Alors** la séquence locale s'exécute dans cet ordre **exact** (orchestrée par `AuthNotifier.deleteAccount()`, plus par `AuthRepository`) :
     1. `Purchases.logOut()` (RevenueCat — fire-and-forget try/catch, **non bloquant**, log warning si échec via `AppLogger.warning(..., tag: 'AuthNotifier')`)
     2. `ref.read(databaseProvider).deleteEverything()` (Drift — wrap try/catch, log warning si échec, **continuer**)
     3. `ref.read(authRepositoryProvider).logout()` (vide `flutter_secure_storage` via `Future.wait` — pattern existant `auth_repository.dart:87-101`, wrap try/catch)
     4. `state = const AsyncData(AuthState())` — déclenche le redirect GoRouter vers `/demo` via la guard auth + redirect `/demo→/home` cassée par auth=null (cf. Story 7.1)
   - **Et** le toast `ShadToast` "Ton compte a été supprimé" s'affiche (overlay survit à la navigation)
   - **Et** si une étape locale (1–3) lève une exception, l'erreur est **loguée mais non remontée à l'UI** : le serveur a déjà supprimé le compte, l'utilisateur ne doit pas voir d'erreur pour un cleanup local imparfait — l'étape 4 (`state = AsyncData(AuthState())`) s'exécute **dans tous les cas** pour garantir la sortie de session

4. **AC4 — Validators Pydantic refusent les valeurs par défaut faibles en prod**
   - **Étant donné** le démarrage du backend avec `ENVIRONMENT=production` dans le `.env`
   - **Quand** `Settings()` est instancié dans `app/core/config.py`
   - **Alors** un `@model_validator(mode="after")` `_require_production_secrets` lève `ValueError` (qui devient `pydantic.ValidationError` → uvicorn exit 1) si **n'importe** lequel des cas suivants :
     - `claude_api_key == ""` ou ne commence pas par `sk-ant-`
     - `len(secret_key) < 32`
     - `secret_key` commence par `change-me` (insensible à la casse) ou contient `"in-production"` (les defaults `.env.example` actuels)
     - `admin_password` dans `{"", "change-me", "change-me-in-production"}`
     - `tester_password` dans `{"", "change-me", "change-me-in-production"}`
     - `revenuecat_webhook_secret == ""` ou égal à `"change-me-in-production"` (le `_require_webhook_secret` existant vérifie seulement le non-vide — étendre)
   - **Et** le message de l'erreur liste **toutes les variables fautives** d'un coup (pas une seule à la fois), formaté lisiblement pour l'opérateur (ex : `Production secrets invalid: SECRET_KEY (too short or default), ADMIN_PASSWORD (default value), CLAUDE_API_KEY (empty)`)

5. **AC5 — Mode `development` : validators relâchés (warning au lieu de raise)**
   - **Étant donné** `ENVIRONMENT=development` (ou `ENVIRONMENT` absent — default `"development"`)
   - **Quand** `Settings()` est instancié avec les mêmes valeurs faibles
   - **Alors** aucune exception n'est levée ; les violations sont **loguées en `WARNING`** via le logger module `app.core.config` (ex : `logger.warning("DEV mode: secret_key uses default — DO NOT deploy as-is")`)
   - **Et** le démarrage uvicorn continue normalement (UX dev local préservée)
   - **Et** les tests `pytest` (qui tournent en mode dev par défaut) ne sont pas cassés

6. **AC6 — `docker-compose.prod.yml` : ports DB/Redis non exposés sur l'host**
   - **Étant donné** le fichier `collega_backend/docker-compose.prod.yml`
   - **Quand** je l'inspecte
   - **Alors** les services `db` (PostgreSQL) et `redis` ne possèdent **aucune** section `ports:` (état déjà constaté actuellement — l'AC est de **vérifier** et de documenter dans `docs/deployment.md`, **pas** de modifier si déjà conforme)
   - **Et** seuls les services `api` (port `430:8000`) et `migrate` (sans ports) sont exposés ; pas de service `caddy` dans le compose.prod (le reverse proxy est géré au niveau Unraid externe — déjà documenté implicitement)
   - **Et** un commentaire YAML est ajouté en tête des sections `db` et `redis` : `# Pas de "ports:" — accès interne uniquement via le network collega_net`

7. **AC7 — Pré-vérification `.env` NAS prod conforme aux nouveaux validators**
   - **Étant donné** la mémoire projet `project_nas_env.md` indiquant que le `.env` prod existe sur `/mnt/user/appdata/compose-stacks/collega/.env` et **ne doit jamais être écrasé**
   - **Quand** la story est terminée et avant le merge du commit qui ajoute les validators
   - **Alors** une checklist manuelle dans le dev record confirme que le `.env` NAS est conforme :
     - `SECRET_KEY` est ≥ 32 caractères et **ne** commence pas par `change-me`
     - `ADMIN_PASSWORD` ≠ `change-me*`
     - `TESTER_PASSWORD` ≠ `change-me*`
     - `CLAUDE_API_KEY` commence par `sk-ant-`
     - `REVENUECAT_WEBHOOK_SECRET` ≠ `change-me-in-production` et non vide
     - `ENVIRONMENT=production` est présent (sinon l'ajouter — sans toucher aux autres lignes)
   - **Et** si une valeur n'est pas conforme, le Project Lead met à jour **uniquement la ligne fautive** via SSH/SMB sur le NAS, sans regénérer le fichier

---

## Tasks / Subtasks

### Backend — Validators Pydantic mode-aware

- [x] **T1 — Ajouter champ `environment` + validator prod strict dans `app/core/config.py` (AC: #4, #5)**
  - Fichier : `collega_backend/app/core/config.py` (modifier le fichier existant — 56 lignes actuellement)
  - **Ajouter en tête du fichier** :
    ```python
    import logging
    
    logger = logging.getLogger(__name__)
    ```
  - **Ajouter le champ `environment` dans `Settings`** (après `claude_api_key`, ligne 11) :
    ```python
    environment: str = "development"  # "development" | "production"
    ```
  - **Étendre le validator `_require_webhook_secret` existant (lignes 38-42)** pour rejeter aussi `"change-me-in-production"` en mode prod :
    ```python
    @model_validator(mode="after")
    def _require_webhook_secret(self) -> "Settings":
        if not self.revenuecat_webhook_secret:
            raise ValueError("revenuecat_webhook_secret must be set (non-empty)")
        return self
    ```
    → Laisser ce validator tel quel (il vérifie le non-vide pour tous les envs). La vérification anti-default sera dans le nouveau validator prod ci-dessous.
  - **Ajouter un nouveau validator `_validate_production_secrets`** (à insérer **après** `_require_distinct_tester_credentials`) :
    ```python
    @model_validator(mode="after")
    def _validate_production_secrets(self) -> "Settings":
        is_prod = self.environment.lower() == "production"

        issues: list[str] = []

        # SECRET_KEY
        if len(self.secret_key) < 32:
            issues.append("SECRET_KEY (must be ≥ 32 chars)")
        elif self.secret_key.lower().startswith("change-me") or "in-production" in self.secret_key.lower():
            issues.append("SECRET_KEY (default placeholder value)")

        # CLAUDE_API_KEY
        if not self.claude_api_key:
            issues.append("CLAUDE_API_KEY (empty)")
        elif not self.claude_api_key.startswith("sk-ant-"):
            issues.append("CLAUDE_API_KEY (invalid format — expected sk-ant-…)")

        # ADMIN_PASSWORD
        if self.admin_password in ("", "change-me", "change-me-in-production"):
            issues.append("ADMIN_PASSWORD (default placeholder value)")

        # TESTER_PASSWORD
        if self.tester_password in ("", "change-me", "change-me-in-production"):
            issues.append("TESTER_PASSWORD (default placeholder value)")

        # REVENUECAT_WEBHOOK_SECRET
        if self.revenuecat_webhook_secret == "change-me-in-production":
            issues.append("REVENUECAT_WEBHOOK_SECRET (default placeholder value)")

        if not issues:
            return self

        msg = f"Insecure config values: {', '.join(issues)}"
        if is_prod:
            raise ValueError(f"Production secrets invalid — {msg}. Refuse to start.")
        else:
            logger.warning("DEV mode: %s — DO NOT deploy as-is.", msg)

        return self
    ```
  - **CRITIQUE — ordre des validators** : Pydantic exécute les `@model_validator(mode="after")` dans l'ordre de définition. Le nouveau validator doit être **après** `_require_webhook_secret` (qui vérifie le non-vide brut). Cohabitation des 2 validators :
    - `_require_webhook_secret` (existant) : lève `ValueError` si `revenuecat_webhook_secret == ""` (vide), peu importe l'env. **À conserver tel quel.** En dev local, `.env.example` contient `REVENUECAT_WEBHOOK_SECRET=change-me-in-production` → non-vide → passe ce validator.
    - `_validate_production_secrets` (nouveau) : détecte les valeurs **placeholder** (`change-me*`, etc.) et lève en prod / log warning en dev. C'est la couche anti-default complémentaire.
    - Donc `revenuecat_webhook_secret == ""` → lève toujours (validator existant). `revenuecat_webhook_secret == "change-me-in-production"` → lève en prod (nouveau validator), warning en dev.
  - **NE PAS** lever `ValueError` en dev — uvicorn (`--reload`) crash en boucle et bloque le workflow dev. Le warning suffit.
  - **NE PAS** ajouter `pydantic.field_validator` sur des champs individuels — la logique mode-aware nécessite l'instance complète (`model_validator`).
  - **NE PAS** modifier `claude_api_key: str = ""` en `Field(...)` requis — garder le default pour que `.env.example` (sans clé réelle) soit utilisable en dev local.

- [x] **T2 — Tests unitaires des validators (AC: #4, #5)**
  - Fichier **NEW** : `collega_backend/tests/core/test_config_validators.py`
  - Pattern : importer `Settings` et `pydantic.ValidationError` ; instancier avec des kwargs explicites (pas via `.env`) pour bypasser le fichier `.env` local.
  - Tests requis :
    ```python
    import logging
    import pytest
    from pydantic import ValidationError
    from app.core.config import Settings


    def _base_settings_kwargs(**overrides):
        """Minimum valid settings; override individual fields per test."""
        base = dict(
            database_url="postgresql+asyncpg://test/test",
            redis_url="redis://test:6379/0",
            secret_key="a" * 32,  # exactement 32 chars, non-default
            claude_api_key="sk-ant-test1234567890",
            admin_password="strongpw",
            tester_password="testerpw",
            revenuecat_webhook_secret="real-secret",
        )
        base.update(overrides)
        return base


    class TestValidatorsProductionMode:
        def test_valid_production_settings_pass(self):
            s = Settings(environment="production", **_base_settings_kwargs())
            assert s.environment == "production"

        def test_short_secret_key_raises(self):
            with pytest.raises(ValidationError, match="SECRET_KEY"):
                Settings(environment="production", **_base_settings_kwargs(secret_key="short"))

        def test_default_secret_key_raises(self):
            with pytest.raises(ValidationError, match="SECRET_KEY"):
                Settings(
                    environment="production",
                    **_base_settings_kwargs(secret_key="change-me-in-production-use-at-least-32-chars"),
                )

        def test_empty_claude_key_raises(self):
            with pytest.raises(ValidationError, match="CLAUDE_API_KEY"):
                Settings(environment="production", **_base_settings_kwargs(claude_api_key=""))

        def test_malformed_claude_key_raises(self):
            with pytest.raises(ValidationError, match="CLAUDE_API_KEY"):
                Settings(environment="production", **_base_settings_kwargs(claude_api_key="not-a-real-key"))

        def test_default_admin_password_raises(self):
            with pytest.raises(ValidationError, match="ADMIN_PASSWORD"):
                Settings(environment="production", **_base_settings_kwargs(admin_password="change-me"))

        def test_default_tester_password_raises(self):
            with pytest.raises(ValidationError, match="TESTER_PASSWORD"):
                Settings(environment="production", **_base_settings_kwargs(tester_password="change-me-in-production"))

        def test_default_webhook_secret_raises(self):
            with pytest.raises(ValidationError, match="REVENUECAT_WEBHOOK_SECRET"):
                Settings(
                    environment="production",
                    **_base_settings_kwargs(revenuecat_webhook_secret="change-me-in-production"),
                )

        def test_multiple_issues_listed_in_message(self):
            with pytest.raises(ValidationError) as exc_info:
                Settings(
                    environment="production",
                    **_base_settings_kwargs(secret_key="short", admin_password="change-me"),
                )
            msg = str(exc_info.value)
            assert "SECRET_KEY" in msg and "ADMIN_PASSWORD" in msg


    class TestValidatorsDevelopmentMode:
        def test_weak_secrets_log_warning_no_raise(self, caplog):
            with caplog.at_level(logging.WARNING, logger="app.core.config"):
                Settings(
                    environment="development",
                    **_base_settings_kwargs(secret_key="short", admin_password="change-me"),
                )
            assert any("DEV mode" in record.message for record in caplog.records)

        def test_default_environment_is_development(self):
            # No env passed → default "development"
            s = Settings(**_base_settings_kwargs(secret_key="short"))
            assert s.environment == "development"
    ```
  - **CRITIQUE — `model_config`** : `Settings` lit `.env` par défaut (`model_config = SettingsConfigDict(env_file=".env", …)`). Pour les tests, les kwargs explicites prennent **précédence** sur `.env`. Mais si le repo dev a un `.env` avec `ENVIRONMENT=development`, les tests qui veulent forcer `environment="production"` doivent bien passer ce kwarg explicitement. La fixture `_base_settings_kwargs` est conçue pour ça.
  - **NE PAS** mocker le filesystem ou le `.env` — utiliser kwargs.
  - **Vérifier** dans `collega_backend/tests/` qu'aucun test existant n'appelle `Settings()` sans kwargs (qui pourrait charger un `.env` polluant en CI) — cf. `conftest.py`. Si oui, c'est un pattern legacy non-modifié par cette story.

- [x] **T3 — Mettre à jour `.env.example` pour refléter le nouveau champ `ENVIRONMENT` (AC: #4, #5)**
  - Fichier : `collega_backend/.env.example`
  - **Ajouter en tête du fichier** (avant `DATABASE_URL`) :
    ```env
    # development | production
    # En prod, des validators refusent les valeurs par défaut faibles (secret_key, admin_password, claude_api_key, etc.).
    ENVIRONMENT=development
    ```
  - **Conserver** toutes les autres lignes telles quelles (les placeholders `change-me-in-production` restent en dev pour signaler qu'il faut les changer — les validators les bloqueront automatiquement en prod).

### Infra — docker-compose.prod.yml

- [x] **T4 — Ajouter commentaires de sécurité dans `docker-compose.prod.yml` (AC: #6)**
  - Fichier : `collega_backend/docker-compose.prod.yml`
  - **État actuel** : les services `db` (ligne 47) et `redis` (ligne 64) n'exposent **déjà aucun** port sur l'host — la sécurité est déjà en place. La story consiste donc à **documenter** ce choix pour qu'il ne soit pas régressé par inadvertance.
  - **Ajouter un commentaire YAML** au début de chaque service :
    ```yaml
      db:
        image: postgres:16-alpine
        # NE PAS ajouter "ports:" — accès interne uniquement via le network collega_net.
        # L'API se connecte via DATABASE_URL=postgresql+asyncpg://postgres:...@db:5432/collega.
        volumes:
          - /mnt/user/appdata/collega/postgres:/var/lib/postgresql/data
        # …reste inchangé
    ```
    ```yaml
      redis:
        image: redis:7-alpine
        # NE PAS ajouter "ports:" — accès interne uniquement via le network collega_net.
        # L'API/worker se connectent via REDIS_URL=redis://redis:6379/0.
        volumes:
          - /mnt/user/appdata/collega/redis:/data
        # …reste inchangé
    ```
  - **NE PAS** modifier `docker-compose.yml` (dev) — il expose intentionnellement `5432` et `6379` pour faciliter les outils dev (TablePlus, RedisInsight). Ce fichier est local-only.

### Frontend Flutter — Safe-delete séquentiel

- [x] **T5 — Refactor `auth_repository.dart::deleteAccount()` pour ne plus wipe storage en interne (AC: #1, #2, #3)**
  - Fichier : `collega_app/lib/features/auth/data/auth_repository.dart` (méthode lignes 233-248)
  - **État actuel — à remplacer** :
    ```dart
    Future<AuthState> deleteAccount() async {
      try {
        final accessToken = await _storage.read(key: _kAccessToken);
        if (accessToken == null) return const AuthState();  // ❌ wipe implicite
        await _dio.delete<Map<String, dynamic>>(
          '/v1/auth/account',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
        await logout();  // ❌ wipe storage dans le repo
        return const AuthState();
      } on DioException catch (e) {
        return AuthState(errorMessage: _extractError(e));
      } catch (_) {
        return AuthState(errorMessage: 'Erreur lors de la suppression du compte');
      }
    }
    ```
  - **Nouveau code** :
    ```dart
    /// Supprime le compte côté backend. **Ne touche PAS** au storage / DB locaux ;
    /// l'orchestration locale est faite par [AuthNotifier.deleteAccount].
    ///
    /// Retours :
    /// - `AuthState()` (vide, sans errorMessage) → succès serveur (200)
    /// - `AuthState(errorMessage: ...)` → échec (toast destructive côté UI, AUCUN wipe local)
    Future<AuthState> deleteAccount() async {
      try {
        final accessToken = await _storage.read(key: _kAccessToken);
        if (accessToken == null) {
          return const AuthState(
            errorMessage: 'Session expirée — reconnecte-toi avant de supprimer ton compte',
          );
        }
        await _dio.delete<Map<String, dynamic>>(
          '/v1/auth/account',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
        return const AuthState();
      } on DioException catch (e) {
        AppLogger.warning('deleteAccount DioException: ${e.type}', tag: 'AuthRepository');
        return AuthState(errorMessage: _extractError(e));
      } catch (e) {
        AppLogger.error('deleteAccount unexpected error', tag: 'AuthRepository', error: e);
        return const AuthState(errorMessage: 'Erreur lors de la suppression du compte');
      }
    }
    ```
  - **CRITIQUE — suppression du `await logout()`** : c'était une fuite de responsabilité ; le wipe storage est désormais orchestré par `AuthNotifier`. Le `logout()` reste utilisé tel quel par `AuthNotifier.logout()` (ligne 50-55 de `auth_providers.dart`) — ne pas le modifier.
  - **CRITIQUE — comportement `accessToken == null`** : avant, retour silencieux `AuthState()` (qui ressemblait à un succès). Désormais, retour avec `errorMessage` explicite → toast destructive côté UI. C'est un **changement de contrat** des tests existants — voir T8.

- [x] **T6 — Refactor `auth_providers.dart::AuthNotifier.deleteAccount()` avec séquence ordonnée RC → Drift → storage → state (AC: #3)**
  - Fichier : `collega_app/lib/features/auth/auth_providers.dart` (méthode lignes 77-89)
  - **État actuel — à remplacer** :
    ```dart
    Future<String?> deleteAccount() async {
      final result = await ref.read(authRepositoryProvider).deleteAccount();
      if (result.errorMessage != null) {
        return result.errorMessage;
      }
      try {
        await ref.read(databaseProvider).deleteEverything();
      } catch (_) {
        // Le compte est supprimé côté serveur — on réinitialise l'état quoi qu'il arrive
      }
      state = const AsyncData(AuthState());
      return null;
    }
    ```
  - **Nouveau code** :
    ```dart
    /// Supprime le compte (backend) puis exécute le wipe local **dans l'ordre** :
    ///   1. RevenueCat.logOut()  — fire-and-forget try/catch
    ///   2. AppDatabase.deleteEverything()  — try/catch (best-effort)
    ///   3. AuthRepository.logout() (vide flutter_secure_storage) — try/catch
    ///   4. state = AsyncData(AuthState())  — TOUJOURS exécuté en dernier
    ///
    /// Retourne `null` en succès, ou un message d'erreur si le DELETE serveur a échoué
    /// (auquel cas RIEN n'est wipé localement — la session reste intacte).
    Future<String?> deleteAccount() async {
      final result = await ref.read(authRepositoryProvider).deleteAccount();
      if (result.errorMessage != null) {
        AppLogger.warning(
          'deleteAccount: server refused — keeping local session intact (${result.errorMessage})',
          tag: 'AuthNotifier',
        );
        return result.errorMessage;
      }

      // Serveur OK → wipe local séquentiel, best-effort sur chaque étape.
      try {
        await Purchases.logOut();
      } catch (e) {
        AppLogger.warning('RevenueCat logOut failed during deleteAccount', tag: 'AuthNotifier', error: e);
      }

      try {
        await ref.read(databaseProvider).deleteEverything();
      } catch (e) {
        AppLogger.warning('Drift deleteEverything failed during deleteAccount', tag: 'AuthNotifier', error: e);
      }

      try {
        await ref.read(authRepositoryProvider).logout();
      } catch (e) {
        AppLogger.warning('secureStorage wipe failed during deleteAccount', tag: 'AuthNotifier', error: e);
      }

      // ⚠️ Toujours exécuté, même si une étape locale a échoué : le serveur a déjà
      // supprimé le compte, on doit sortir de la session pour éviter les appels 401 loop.
      state = const AsyncData(AuthState());
      return null;
    }
    ```
  - **CRITIQUE — ordre RC d'abord** : `Purchases.logOut()` doit s'exécuter **avant** le wipe de `secure_storage` car le SDK RC peut lire des identifiants persistés (Apple ID linking). Si on vide le storage avant, RC peut ne pas savoir quel utilisateur déconnecter.
  - **CRITIQUE — `state = ...` toujours en dernier** : si on plaçait cette ligne dans le `try` d'une étape locale et qu'elle échouait, la session resterait active → l'utilisateur verrait des écrans authentifiés avec data backend supprimée → 401 loop. Placer hors des `try/catch` garantit la sortie de session.
  - **Décision : NE PAS réutiliser le helper `_rcLogOut()` existant** (lignes 115-123 de `auth_providers.dart`). Il est implémenté en fire-and-forget via une closure auto-invoquée (`() async { ... }();`) qui retourne immédiatement sans attendre l'achèvement. Pour `deleteAccount` on veut **attendre** que RC termine avant le wipe Drift (pour avoir un ordre déterministe testable et pour qu'une exception RC ne pollue pas le wipe Drift). Faire un `await Purchases.logOut()` direct avec `try/catch` local, comme dans le pseudocode ci-dessus.
  - **NE PAS** ajouter `state = const AsyncLoading()` au début — l'UI gère son propre `_deleting=true` côté `_AppCardState` (`profile_screen.dart:563`) et n'a pas besoin que `authProvider` passe en loading.

- [x] **T7 — Optionnel : ajouter `mounted` guard supplémentaire dans `_handleDeleteAccount` (AC: #1, #3)**
  - Fichier : `collega_app/lib/features/profile/presentation/profile_screen.dart` (méthode `_handleDeleteAccount` lignes 537-583)
  - **État actuel** : les guards `if (!mounted) return;` sont déjà présents (ligne 561, 565, 576). **Rien à modifier** sauf si le dev review détecte une régression.
  - **Vérifier** :
    - Le toast destructive AC1/AC2 utilise bien `error` retourné par `deleteAccount()` → ✅ déjà présent ligne 568
    - Le toast succès AC3 s'affiche après le state reset → ✅ déjà présent ligne 577
  - **Marge d'amélioration optionnelle** (NICE-TO-HAVE, pas requis par AC) : extraire la longue description en constante de fichier pour la testabilité (ex : `_kDeleteDialogDescription`). À discuter en code review.

### Tests Flutter

- [x] **T8 — Mettre à jour `auth_repository_test.dart` pour le nouveau contrat `deleteAccount` (AC: #1, #2)**
  - Fichier : `collega_app/test/features/auth/auth_repository_test.dart` (à vérifier — s'il n'existe pas, créer)
  - **Tests requis** (utiliser le pattern Dio scripted adapter de `drill_repository_test.dart` Story 7.2, OU mock simple via `Dio` injecté) :
    ```dart
    testWidgets('deleteAccount: pas de token → errorMessage explicite, pas de wipe', (tester) async {
      final storage = _FakeSecureStorage(initial: {});  // pas d'access_token
      final repo = AuthRepository(dio: Dio(), storage: storage);
      final result = await repo.deleteAccount();
      expect(result.errorMessage, contains('Session expirée'));
      expect(storage.deletedKeys, isEmpty);  // logout() pas appelé
    });

    testWidgets('deleteAccount: 200 → AuthState vide sans errorMessage, storage intact', (tester) async {
      final storage = _FakeSecureStorage(initial: {'access_token': 'tok'});
      final dio = _ScriptedDio([_ScriptedResponse(statusCode: 200, data: {'data': {'message': 'Account deleted'}})]);
      final repo = AuthRepository(dio: dio, storage: storage);
      final result = await repo.deleteAccount();
      expect(result.errorMessage, isNull);
      expect(storage.deletedKeys, isEmpty);  // ⚠️ le wipe est délégué au Notifier maintenant
    });

    testWidgets('deleteAccount: timeout Dio → errorMessage, storage intact', (tester) async {
      final storage = _FakeSecureStorage(initial: {'access_token': 'tok'});
      final dio = _ScriptedDio([_ScriptedException(DioExceptionType.receiveTimeout)]);
      final repo = AuthRepository(dio: dio, storage: storage);
      final result = await repo.deleteAccount();
      expect(result.errorMessage, isNotNull);
      expect(storage.deletedKeys, isEmpty);
    });

    testWidgets('deleteAccount: 500 → errorMessage extrait, storage intact', (tester) async {
      final storage = _FakeSecureStorage(initial: {'access_token': 'tok'});
      final dio = _ScriptedDio([
        _ScriptedResponse(statusCode: 500, data: {'detail': {'message': 'DB down'}}),
      ]);
      final repo = AuthRepository(dio: dio, storage: storage);
      final result = await repo.deleteAccount();
      expect(result.errorMessage, isNotNull);
      expect(storage.deletedKeys, isEmpty);
    });
    ```
  - **Vérifier** d'abord si `_FakeSecureStorage` existe déjà dans le repo de tests Flutter (pattern Story 6.2 / 2.3). Sinon, créer un fake inline simple :
    ```dart
    class _FakeSecureStorage implements FlutterSecureStorage {
      _FakeSecureStorage({Map<String, String>? initial}) : _store = {...?initial};
      final Map<String, String> _store;
      final List<String> deletedKeys = [];
      @override
      Future<String?> read({required String key, ...}) async => _store[key];
      @override
      Future<void> delete({required String key, ...}) async {
        deletedKeys.add(key);
        _store.remove(key);
      }
      // …mock minimal des autres méthodes utilisées
    }
    ```
  - **CRITIQUE — pattern Dio scripted** : réutiliser le `_ScriptedAdapter` de `drill_repository_test.dart` (Story 7.2) — pattern déjà introduit et validé par le code review. Pas besoin de réinventer.
  - **CRITIQUE — pas de tests sur le wipe interne** : avant Story 7.3, `auth_repository.test.dart::deleteAccount` (si existant) testait probablement que `logout()` était appelé en interne. Ces assertions **doivent être retirées** — le wipe est désormais externe.

- [x] **T9 — Ajouter test orchestration `auth_providers_test.dart::deleteAccount` (AC: #3)**
  - Fichier : `collega_app/test/features/auth/auth_providers_test.dart` (à vérifier — s'il n'existe pas, créer)
  - **Pattern** : utiliser un `ProviderContainer` avec `overrides` pour fournir des fakes de `authRepositoryProvider` et `databaseProvider`.
  - **Tests requis** :
    ```dart
    test('deleteAccount: serveur OK → séquence RC → Drift → storage → state', () async {
      final callOrder = <String>[];
      final fakeRepo = _FakeAuthRepository(
        onDeleteAccount: () async {
          callOrder.add('repo.deleteAccount');
          return const AuthState();  // succès
        },
        onLogout: () async {
          callOrder.add('repo.logout');
        },
      );
      final fakeDb = _FakeAppDatabase(
        onDeleteEverything: () async {
          callOrder.add('db.deleteEverything');
        },
      );
      // Stub Purchases.logOut() via la classe statique (mockable via package_info_plus pattern ou test override)
      // Si Purchases n'est pas mockable simplement, utiliser un wrapper Provider injectable.

      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepo),
        databaseProvider.overrideWithValue(fakeDb),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      await container.read(authProvider.future);  // initial build
      final error = await notifier.deleteAccount();

      expect(error, isNull);
      expect(callOrder, ['repo.deleteAccount', 'db.deleteEverything', 'repo.logout']);
      //                              ^ RC.logOut absent du callOrder si non-mockable — sinon vérifier l'ordre complet
      expect(container.read(authProvider).valueOrNull, equals(const AuthState()));
    });

    test('deleteAccount: serveur KO → aucun wipe, errorMessage propagé', () async {
      final callOrder = <String>[];
      final fakeRepo = _FakeAuthRepository(
        onDeleteAccount: () async {
          callOrder.add('repo.deleteAccount');
          return const AuthState(errorMessage: 'Erreur réseau');
        },
        onLogout: () async => callOrder.add('repo.logout'),
      );
      final fakeDb = _FakeAppDatabase(
        onDeleteEverything: () async => callOrder.add('db.deleteEverything'),
      );

      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepo),
        databaseProvider.overrideWithValue(fakeDb),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      await container.read(authProvider.future);
      final error = await notifier.deleteAccount();

      expect(error, 'Erreur réseau');
      expect(callOrder, ['repo.deleteAccount']);  // pas de wipe
      // state ne doit PAS avoir été reset — l'utilisateur initial doit rester en place
      // (selon ce que `_FakeAuthRepository.build()` a retourné via authProvider.build)
    });
    ```
  - **CRITIQUE — RevenueCat mockable** : `Purchases.logOut()` est un appel statique difficile à mocker sans wrapper. **Décision** :
    - **Option A** (recommandée si effort faible) : créer un `purchasesServiceProvider` qui wrappe `Purchases.logOut()`, et l'override dans les tests pour vérifier l'appel + l'ordre. Ajustement à propager à `_rcLogIn` / `_rcLogOut` aussi (refactor mineur).
    - **Option B** (pragmatique) : ne PAS asserter sur l'appel RC dans les tests Notifier ; se contenter d'asserter que les autres étapes s'exécutent dans l'ordre. Vérifier l'appel RC manuellement à l'exécution de l'app. **Choisir B si Option A demande > 1h** — focus sur la correction du bug A2, pas sur la testabilité RC.
  - **NE PAS** créer de mocktail/mockito setup juste pour cette story — pattern actuel `_FakeXxxRepository extends` est suffisant.

- [x] **T10 — Mettre à jour `profile_screen_test.dart` pour le chemin d'erreur réseau (AC: #1)**
  - Fichier : `collega_app/test/features/profile/profile_screen_test.dart` (lignes 32-53 contiennent `_FakeAuthNotifier`)
  - **État actuel** : `_FakeAuthNotifier.deleteAccount()` retourne toujours `null` (succès) — ligne 52.
  - **Ajouter un test du chemin d'erreur** :
    ```dart
    class _FakeAuthNotifierWithError extends AuthNotifier {
      _FakeAuthNotifierWithError(this._authState, this._error);
      final AuthState _authState;
      final String _error;

      @override
      Future<AuthState> build() async => _authState;

      @override
      Future<String?> deleteAccount() async => _error;
      // …autres overrides comme dans _FakeAuthNotifier
    }

    testWidgets('chemin erreur : DELETE échoue → toast destructive, session intacte', (tester) async {
      await tester.pumpWidget(_buildScreen(
        authNotifier: _FakeAuthNotifierWithError(AuthState(user: _testUser), 'Erreur réseau'),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer mon compte', skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();
      expect(find.text('Erreur'), findsOneWidget);  // titre du toast destructive
      expect(find.text('Erreur réseau'), findsOneWidget);  // description du toast
      // Le toast "Ton compte a été supprimé" ne doit PAS apparaître
      expect(find.text('Ton compte a été supprimé'), findsNothing);
    });
    ```
  - **CRITIQUE** : vérifier que le helper `_buildScreen` accepte déjà un paramètre `authNotifier` injectable. Sinon, adapter le helper (pattern existant `authState:` ligne 313).
  - **NE PAS** changer le test existant `_FakeAuthNotifier.deleteAccount() async => null` — il couvre le happy path.

### Documentation & Validation

- [x] **T11 — Documenter le mode prod dans `docs/deployment.md` (AC: #6, #7)**
  - Fichier : `collega_backend/docs/deployment.md` (vérifier s'il existe — sinon créer le minimum nécessaire ; si oui, **ajouter une section**)
  - **Contenu minimum à ajouter** (section "Production secrets") :
    ```markdown
    ## Production secrets — validators stricts

    Le backend refuse de démarrer en `ENVIRONMENT=production` si :
    - `SECRET_KEY` < 32 chars OU commence par `change-me*`
    - `CLAUDE_API_KEY` vide OU ne commence pas par `sk-ant-`
    - `ADMIN_PASSWORD` / `TESTER_PASSWORD` valent `change-me*`
    - `REVENUECAT_WEBHOOK_SECRET` vaut `change-me-in-production`

    ### Vérifier le .env NAS prod
    SSH sur le NAS et inspecter `/mnt/user/appdata/compose-stacks/collega/.env` :
    \`\`\`bash
    ssh <user>@<nas> 'cat /mnt/user/appdata/compose-stacks/collega/.env | grep -E "^(SECRET_KEY|ADMIN_PASSWORD|TESTER_PASSWORD|CLAUDE_API_KEY|REVENUECAT_WEBHOOK_SECRET|ENVIRONMENT)="'
    \`\`\`

    ### Ports DB/Redis
    `docker-compose.prod.yml` n'expose **aucun port** sur l'host pour `db` et `redis` — accès interne uniquement via le bridge `collega_net`. NE PAS ajouter de `ports:` sans validation sécurité.
    ```
  - **NE PAS** créer une doc trop verbeuse — focus sur ce qui change avec la story.
  - **NE PAS** committer la valeur réelle des secrets dans la doc — uniquement les contraintes.

- [x] **T12 — Pré-vérification manuelle .env NAS prod (AC: #7)**
  - **Avant** de merger la PR (ou la branche) qui contient T1+T2 (validators), exécuter manuellement :
    ```bash
    # Sur le NAS (SSH ou SMB)
    cat /mnt/user/appdata/compose-stacks/collega/.env | grep -E "^(SECRET_KEY|ADMIN_PASSWORD|TESTER_PASSWORD|CLAUDE_API_KEY|REVENUECAT_WEBHOOK_SECRET|ENVIRONMENT)="
    ```
  - **Vérifier** chacune des contraintes AC#4. Si une valeur n'est pas conforme :
    - Mettre à jour **uniquement la ligne fautive** via `nano` sur le NAS (ou SMB write)
    - Ne **PAS** régénérer le fichier ni copier `.env.example` par-dessus
  - **Ajouter ENVIRONMENT=production** au .env NAS s'il n'y est pas (avant le merge, sinon le démarrage suivant restera en mode `development` → validators relâchés → aucun gain de sécurité).
  - **Logger** dans le dev record (Completion Notes) la commande exécutée et la confirmation que toutes les contraintes sont OK — sans coller les valeurs.

---

## Périmètre & Contraintes

- **Aucune migration Alembic** — cette story est purement code/config (pas de changement de schéma).
- **Aucune nouvelle dépendance Python ni Flutter** — `pydantic` (validators), `purchases_flutter` (RC.logOut), `flutter_riverpod`, `drift`, `flutter_secure_storage`, `dio` déjà présents.
- **Aucun changement de contrat API** — `DELETE /v1/auth/account` reste `200 OK + {data: {message: "Account deleted"}}` ; `@limiter.limit("3/minute")` déjà en place.
- **Compatibilité prod** — Le NAS `.env` actuel **ne doit pas être écrasé** (mémoire `project_nas_env.md`). T12 fait la pré-vérification manuelle.
- **Compatibilité dev** — Les validators relâchés en mode dev (warning au lieu de raise) garantissent que le workflow `docker compose -f docker-compose.yml up` continue de fonctionner avec `.env.example` non modifié.
- **Stories 6.2 + 7.1 + 7.2 sont closes et `done`** — on ne casse aucun de leurs comportements. En particulier :
  - Le rate limit `@limiter.limit("3/minute")` sur `DELETE /account` (ajouté en review 6.2) reste intact
  - Le redirect GoRouter `/demo → /home` (Story 7.1) reste intact
  - Les nouveaux validators Pydantic (T1) ne touchent à aucun champ utilisé par 7.2 (`reload_count_max`, `monthly_reloads_max`, `redis_url`, `database_url`)

---

## Dev Notes — Contexte Technique Exhaustif

### Diagnostic A2 (cascade DELETE Flutter — état actuel)

**Code `auth_repository.dart::deleteAccount()` ACTUEL (`lib/features/auth/data/auth_repository.dart:233-248`)** :

```dart
Future<AuthState> deleteAccount() async {
  try {
    final accessToken = await _storage.read(key: _kAccessToken);
    if (accessToken == null) return const AuthState();  // ❌ #1 bug latent
    await _dio.delete<Map<String, dynamic>>('/v1/auth/account', /* … */);
    await logout();  // ❌ #2 wipe storage avant que le Notifier puisse séquencer
    return const AuthState();
  } on DioException catch (e) {
    return AuthState(errorMessage: _extractError(e));
  } catch (_) {
    return AuthState(errorMessage: 'Erreur lors de la suppression du compte');
  }
}
```

**Bugs identifiés** :

1. `accessToken == null` retourne `AuthState()` vide **sans errorMessage** → côté UI, le Notifier croit que le DELETE a réussi → wipe local Drift + state reset → utilisateur "supprimé" alors que le compte serveur existe encore. **Asymétrie classique.**
2. `await logout()` (vide storage) est exécuté **dans le repo** avant que le Notifier ait pu orchestrer RC.logOut() / Drift.deleteEverything(). Pas de bug fonctionnel actuel (la session est terminée de toutes façons) MAIS empêche la séquence ordonnée RC → Drift → storage demandée par A2.

**Code `auth_providers.dart::deleteAccount()` ACTUEL (`lib/features/auth/auth_providers.dart:77-89`)** :

```dart
Future<String?> deleteAccount() async {
  final result = await ref.read(authRepositoryProvider).deleteAccount();
  if (result.errorMessage != null) return result.errorMessage;
  try {
    await ref.read(databaseProvider).deleteEverything();  // ❌ pas de log
  } catch (_) { /* … */ }
  state = const AsyncData(AuthState());
  return null;
}
```

**Manques identifiés** :

3. **Pas d'appel à `Purchases.logOut()`** — l'utilisateur RC reste linked à l'Apple ID via son user_id supprimé serveur. Le SDK RC continuera de signaler les achats à un user_id inexistant côté backend. Identifié en Review Findings 6.2 comme "deferred, hors scope spec" → **à corriger maintenant** (scope explicite 7.3).
4. **Pas de log warning** si une étape locale échoue silencieusement (`catch (_)`) → debug difficile en cas de bug intermittent.

### Diagnostic dette infra — validators config

**État actuel `app/core/config.py`** (56 lignes) :

```python
class Settings(BaseSettings):
    secret_key: str
    claude_api_key: str = ""
    admin_password: str = "change-me"
    tester_password: str = "change-me"
    revenuecat_webhook_secret: str = ""

    @model_validator(mode="after")
    def _require_webhook_secret(self) -> "Settings":
        if not self.revenuecat_webhook_secret:
            raise ValueError("revenuecat_webhook_secret must be set (non-empty)")
        return self

    @model_validator(mode="after")
    def _require_distinct_tester_credentials(self) -> "Settings":
        # …vérifie que tester ≠ admin (cohérence)
```

**Risque actuel** : si un opérateur déploie en prod sans changer `.env` (oubli humain), le backend démarre avec :
- `secret_key="change-me-in-production-use-at-least-32-chars"` → JWT signés avec une clé devinable → attaque de signature
- `admin_password="change-me-in-production"` → interface admin accessible en clair
- `claude_api_key=""` → tous les appels Claude crashent silencieusement

Le validator `_require_webhook_secret` actuel vérifie seulement le **non-vide** — il accepte `"change-me-in-production"`.

**État actuel `.env.example`** :

```env
SECRET_KEY=change-me-in-production-use-at-least-32-chars
CLAUDE_API_KEY=sk-ant-api03-...
ADMIN_PASSWORD=change-me-in-production
TESTER_PASSWORD=change-me-in-production
REVENUECAT_WEBHOOK_SECRET=change-me-in-production
```

Tous les placeholders contiennent `"change-me"` ou `"in-production"` → pattern facile à détecter dans un validator.

### Diagnostic infrastructure — ports DB/Redis prod

**État actuel `docker-compose.prod.yml`** (87 lignes) :

```yaml
db:
  image: postgres:16-alpine
  volumes: [...]
  environment: { POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB }
  healthcheck: ...
  networks: [collega_net]
  restart: unless-stopped
  # ✅ Pas de "ports:" → accès interne uniquement

redis:
  image: redis:7-alpine
  volumes: [...]
  healthcheck: ...
  networks: [collega_net]
  restart: unless-stopped
  # ✅ Pas de "ports:" → accès interne uniquement

api:
  ports: ["430:8000"]  # exposé sur 430 host → Caddy unraid externe reverse-proxy vers 430
```

**Conclusion** : la sécurité est **déjà** en place. La story 7.3 ajoute juste **des commentaires** pour empêcher une régression silencieuse (un dev qui ajouterait `ports: 5432:5432` "pour debug" sans réfléchir).

Le `docker-compose.yml` dev (différent du prod) expose `5432` et `6379` — c'est intentionnel pour les outils dev locaux (TablePlus, RedisInsight). **Ne pas y toucher.**

### Architecture des fichiers modifiés

```
collega_backend/
├── app/
│   └── core/
│       └── config.py                       # UPDATE (T1: validators)
├── tests/
│   └── core/
│       └── test_config_validators.py       # NEW (T2: 12 tests)
├── docker-compose.prod.yml                 # UPDATE (T4: commentaires sécurité)
├── .env.example                            # UPDATE (T3: ENVIRONMENT field)
└── docs/
    └── deployment.md                       # UPDATE or NEW (T11: section secrets)

collega_app/
├── lib/
│   └── features/
│       └── auth/
│           ├── data/auth_repository.dart   # UPDATE (T5: refactor deleteAccount)
│           └── auth_providers.dart         # UPDATE (T6: séquence ordonnée)
└── test/
    └── features/
        ├── auth/
        │   ├── auth_repository_test.dart   # UPDATE or NEW (T8: 4 tests)
        │   └── auth_providers_test.dart    # UPDATE or NEW (T9: 2 tests)
        └── profile/
            └── profile_screen_test.dart    # UPDATE (T10: 1 test chemin erreur)
```

### Pattern Pydantic `@model_validator(mode="after")` + log conditionnel

Référence : pydantic v2 — `model_validator` peut retourner `self` ou lever une exception. **Le retour est obligatoire** (sinon `None` remplace l'instance).

**Pattern mode-aware** :

```python
@model_validator(mode="after")
def _validate_production_secrets(self) -> "Settings":
    is_prod = self.environment.lower() == "production"
    issues = self._collect_issues()  # liste de strings descriptives
    if not issues:
        return self
    msg = f"Insecure config: {', '.join(issues)}"
    if is_prod:
        raise ValueError(f"Production secrets invalid — {msg}")
    logger.warning("DEV mode: %s — DO NOT deploy as-is.", msg)
    return self
```

**Garantie** : `pydantic.ValidationError` (sous-classe de `ValueError` enveloppée par Pydantic) propagée au `Settings()` final dans `app/main.py` → uvicorn affiche le traceback puis exit 1. Aucun code applicatif n'est exécuté → pas de risque de fuite de credentials par défaut.

### Pattern Flutter : séquence ordonnée best-effort

Référence : Story 6.2 `Dev Notes — Flow de suppression complet` (ligne 358-378) — pattern initial.

**Différence Story 7.3** : déplacement du wipe storage du repo vers le notifier, et ajout RC.logOut en début de séquence.

**Garantie** : chaque étape locale est **best-effort** (try/catch + log warning), mais `state = AsyncData(AuthState())` est **toujours** exécuté → l'utilisateur est garanti de sortir de la session (pas de zombie state). Le redirect GoRouter `/demo` est déclenché par le listener `forceLogoutSignalProvider` ou par la guard reactive sur `authProvider` (cf. `app_router.dart`).

### Pattern test Riverpod avec ProviderContainer + overrides

Référence : `auth_providers_test.dart` (si existant) ou `college_import_notifier_test.dart` (Story 7.2) — pattern établi.

**Squelette** :

```dart
test('description', () async {
  final container = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(fakeRepo),
    databaseProvider.overrideWithValue(fakeDb),
  ]);
  addTearDown(container.dispose);

  final notifier = container.read(authProvider.notifier);
  await container.read(authProvider.future);  // attendre le build initial
  
  // Exercer la méthode
  final result = await notifier.deleteAccount();
  
  // Asserter
  expect(result, ...);
});
```

**Pas de `mocktail`** — patterns `_FakeAuthRepository extends AuthRepository` suffisent.

### Stack technique vérifiée

**Backend** (`pyproject.toml` / `requirements.txt`) :
- Python 3.11+
- FastAPI 0.110+
- Pydantic v2 (`model_validator`, `BaseSettings`)
- `pydantic-settings` (pour `SettingsConfigDict(env_file=...)`)
- `logging` stdlib (pas de `loguru` ou autre)

**Frontend** (`pubspec.yaml`) :
- Flutter 3.6+
- `flutter_riverpod: ^2.6.1`
- `dio: ^5.7.0`
- `flutter_secure_storage: ^9.2.2`
- `drift: ^2.21.0`
- `purchases_flutter` (RevenueCat SDK — déjà importé dans `auth_providers.dart:2`)
- `shadcn_ui: ^0.19.0` (toasts)

Aucune mise à jour de version requise pour cette story.

### Anti-patterns à éviter

- **NE PAS** retourner `AuthState()` vide quand `accessToken == null` dans `deleteAccount` — c'est ambigu (succès silencieux ou erreur ?). Toujours fournir un `errorMessage` explicite quand le DELETE serveur n'a pas eu lieu.
- **NE PAS** vider `secure_storage` à l'intérieur d'`AuthRepository.deleteAccount()` — c'est une fuite de responsabilité. Le repo fait des appels HTTP ; le notifier orchestre.
- **NE PAS** appeler `Purchases.logOut()` en fire-and-forget pour cette story spécifique — on veut **attendre** l'achèvement avant le wipe Drift pour avoir un ordre déterministe testable. (Le pattern `_rcLogOut()` existant fire-and-forget est OK pour le logout normal mais inadapté ici.)
- **NE PAS** placer `state = AsyncData(AuthState())` dans le `try` d'une étape locale — si l'étape échoue, l'utilisateur ne sort jamais de sa session → boucle 401 sur les autres écrans qui appellent l'API.
- **NE PAS** ajouter de `pydantic.field_validator` sur des champs individuels en mode-aware — la logique nécessite l'instance complète pour lire `self.environment` ; `model_validator` est obligatoire.
- **NE PAS** lever `ValueError` en mode dev — uvicorn `--reload` boucle en crash et bloque le workflow. Warning suffit.
- **NE PAS** modifier `.env` directement sur le NAS via `scp` ou `rsync` qui écraseraient le fichier complet — utiliser un éditeur en place (nano, vi) ligne par ligne (mémoire `project_nas_env.md`).
- **NE PAS** modifier `docker-compose.yml` (dev) — il expose intentionnellement les ports DB/Redis pour les outils dev.
- **NE PAS** créer une migration Alembic — cette story est 100% code/config, pas de schéma.
- **NE PAS** ajouter de `print()` / `debugPrint()` — utiliser `AppLogger.warning(..., tag: 'ClassName')` côté Flutter et `logger.warning(...)` côté Python (cf. architecture L.310 enforcement).
- **NE PAS** réutiliser le helper `_rcLogOut()` privé existant dans `auth_providers.dart` — sa nature fire-and-forget non-bloquante (closure auto-invoquée) empêche les tests de vérifier l'ordre des appels. Faire un `await Purchases.logOut()` direct avec try/catch local.

---

## Previous Story Intelligence — Learnings 6.x et 7.x

### Story 6.2 (suppression de compte — feature initiale)

- **Pattern Drift `deleteEverything()`** : implémenté manuellement dans `app_database.dart:55-63` via `transaction()` + `delete(table).go()` sur les 5 tables. Pas une méthode built-in Drift comme indiqué initialement.
- **Pattern `_FakeAuthNotifier`** dans `profile_screen_test.dart` — toujours utilisé. La fixture Story 7.3 l'étend avec un fake qui retourne une erreur (T10).
- **Review Findings 6.2 résolus** : `mounted` guard avant toast succès, exception non-Dio capturée, état réinitialisé même si Drift échoue. **Tous applicables ici** — vérifier qu'aucune régression n'est introduite par le refactor.
- **Review Findings 6.2 deferred** : "Absence de `RevenueCat.logOut()` lors de la suppression — deferred, hors scope spec" — **maintenant adressé en T6**.
- **Review Findings 6.2 deferred** : "JWT toujours valide après suppression du compte — limitation architecturale pré-existante" — **toujours deferred**. Pas de scope ici. (cf. item A7 fermé épisode 7).

### Story 7.1 (UX FlashCard & Router)

- **Redirect `/demo → /home` pour user authentifié** : implémenté dans `app_router.dart` — **ne pas y toucher**. La sortie de session via `state = AsyncData(AuthState())` déclenche la guard reactive qui redirige `/profile → /demo` (utilisateur déloggé).
- **Pattern `_localExitResult` (FlashCard)** : non applicable ici.

### Story 7.2 (Hardening async backend)

- **Pattern Dio scripted adapter** (`drill_repository_test.dart`) — réutilisable pour T8 (`auth_repository_test.dart`). Évite `mocktail`.
- **Pattern `_FakeAuthRepository extends AuthRepository`** — applicable pour T9 (`auth_providers_test.dart`).
- **Pattern `ProviderContainer` + overrides** — applicable pour T9.
- **9 failures pré-existantes bcrypt/passlib** non liées à la story — **toujours présentes**. Ne pas chercher à les corriger ici. Story 7.3 ne touche pas `auth.py` côté backend (le DELETE endpoint reste tel quel).
- **Rate limit `@limiter.limit("3/minute")` sur `DELETE /account`** — ajouté en code review 6.2, vérifié intact en 7.2 (`auth.py:136`). À conserver.

### Rétro MVP 2026-05-19 — Pattern #2 async correctness

> "tous les bugs A1-A10 sont des manifestations du même thème : opérations distribuées sans atomicité ni source de vérité unique. La fix doit toujours réduire le nombre de checkpoints fragiles, pas en ajouter." (cité de Story 7.2 dev notes)

**Application à 7.3** : la séquence DELETE serveur → RC → Drift → storage → state a un seul checkpoint atomique (le 200 du serveur). Tout ce qui suit est best-effort local, mais **avant** ce checkpoint, rien n'est touché localement. C'est exactement le pattern préconisé : **soit tout le serveur a réussi, soit rien n'est commencé localement**.

### Rétro MVP — Pattern #5 SDK gotchas

> "RevenueCat webhook timing async + pattern polling `/auth/me`" (cf. `docs/sdk-gotchas.md` créé en Story 7.4 — non encore présent à cette date 2026-05-22).

**Application à 7.3** : `Purchases.logOut()` peut être asynchrone et lent. On l'`await` quand même pour avoir un ordre déterministe, mais on `catch` toute exception pour ne pas bloquer la séquence si le SDK lague.

---

## Git Intelligence — Commits récents pertinents

```
8b2c131 feat(story-7.1): corrections UX FlashCard & Router         # router/widget Flutter, pas de chevauchement
7361a30 chore(sprint): MVP retro 2026-05-19 — epics 1→6 done       # documentation
45f736a fix(colleges): augmente la limite d'import PDF à 500 MB    # colleges.py, pas de chevauchement
502a0cd feat(epic-6): Story 6.2 — suppression de compte (RGPD)     # auth_providers.dart, auth_repository.dart ⚠️ overlap
2baa87d feat(epic-6): Story 6.1 — écran profil & préférences       # profile_screen.dart, pattern AppCard
```

**Branche actuelle** : `main` (status git montré au système : modifications non-commitées de Story 7.2). La Story 7.2 vient juste d'être mergée avec patches code review appliqués. **Avant de commencer 7.3** : vérifier que `git status` est propre et que les fichiers Story 7.2 (notamment `auth_repository.dart`, `auth_providers.dart`) sont au state final post-review.

**Conflit attendu** : modéré sur `auth_repository.dart` (Story 7.2 a touché ce fichier ? — vérifier). Si oui, faire un `git diff HEAD~5 -- collega_app/lib/features/auth/data/auth_repository.dart` pour comprendre les modifications récentes avant le refactor T5.

---

## Project Context Reference

- **Stack backend** : Python 3.11 / FastAPI / SQLAlchemy 2 async / Alembic / ARQ workers / slowapi rate limit / PostgreSQL prod / SQLite tests / Pydantic v2 + pydantic-settings.
- **Stack mobile** : Flutter 3.6+ / Riverpod 2.6 / GoRouter 14.6 / Dio 5.7 / shadcn_ui 0.19 / Drift 2.21 / flutter_secure_storage 9.2 / purchases_flutter (RC).
- **Conventions backend** : `snake_case`, dependency injection FastAPI (`Depends`), Pydantic BaseModel pour schemas, wrappers `{ "data": ... }` / `{ "error": ... }`, `logger.info/warning/error` (pas de `print`).
- **Conventions Flutter** : feature-first (`features/[domain]/{data,domain,presentation,widgets}`), AsyncNotifier pour state async, `AppLogger.warning(..., tag: 'ClassName')` (pas de `print`).
- **Architecture découplée** (Pattern #1 rétro) : préserver l'abstraction `AuthRepository` (HTTP only), `AppDatabase` (Drift only), `AuthNotifier` (orchestration). Ne pas coupler le repo à Drift ni au SDK RC.
- **NAS prod** : `.env` sur `/mnt/user/appdata/compose-stacks/collega/.env` — **NE JAMAIS écraser**, modifier en place ligne par ligne (mémoire `project_nas_env.md`).
- **Sécurité existante** (mémoire `project_security.md`) : `/register` 403 par design, `/login` 5/min, `DELETE /account` 3/min, `/regenerate` 10/hour, `/notifications/*` 10/min — toutes ces routes **doivent rester** par IP (pas par user_id).

---

## Latest Tech Information

- **Pydantic v2.6+** : `@model_validator(mode="after")` est stable et largement utilisé en prod. Documentation : https://docs.pydantic.dev/latest/concepts/validators/#model-validators. Le validator est exécuté **après** la création de l'instance, donc tous les `self.xxx` sont accessibles.
- **`pydantic-settings 2.x`** : `SettingsConfigDict(env_file=".env", extra="ignore")` lit les variables d'env via dotenv. Les kwargs explicites (utilisés en tests T2) **prennent précédence** sur le `.env`.
- **Flutter `purchases_flutter`** : `Purchases.logOut()` est `static Future<LogInResult> logOut()` — peut throw une `PlatformException` si non initialisé. Wrap try/catch est obligatoire.
- **Dio 5.7 `DioExceptionType.connectionError`** : ajouté en 5.4 pour distinguer les erreurs réseau pures des timeouts. Utile si on veut affiner le message d'erreur dans T5 — mais le `_extractError(e)` actuel délègue au statusCode ou au fallback "Erreur réseau, veuillez réessayer" qui est suffisant.
- **Drift 2.21 `transaction()`** : utilisé dans `deleteEverything()`. Atomique au niveau SQLite : soit toutes les tables sont vidées, soit aucune (en cas d'exception milieu transaction). Pas d'inquiétude particulière.
- **Flutter Riverpod 2.6 `AsyncNotifier`** : `state = const AsyncData(AuthState())` déclenche `ref.listen(authProvider, ...)` partout (notamment `app_router.dart` redirect). Le `ref.read` est synchrone — ne pas mettre d'`await` avant cette ligne dans T6 (déjà respecté).

---

## References

### Epic & spec

- **Story 7.3 epic spec** : `_bmad-output/planning-artifacts/epics-v1.1.md` L.199-248 (incl. tasks T1-T7 epic)
- **Items source A2 + dette infra** : `_bmad-output/implementation-artifacts/epic-mvp-retro-2026-05-19.md` § 4 (A2) et § "dette infra"
- **PRD MVP (FRs inchangés)** : `_bmad-output/planning-artifacts/prd.md`
- **Architecture (sections security + infra)** : `_bmad-output/planning-artifacts/architecture.md` L.131-198

### Backend Python

- **Config Settings** : `collega_backend/app/core/config.py:1-56` (T1 modifie ce fichier)
- **Auth endpoint DELETE** : `collega_backend/app/api/v1/auth.py:135-144` (lecture seule — non modifié)
- **Main app startup** : `collega_backend/app/main.py:23-26` (lifespan — `Settings()` est instancié en module-level via `from app.core.config import settings`)
- **.env example** : `collega_backend/.env.example` (T3 modifie)
- **Docker-compose prod** : `collega_backend/docker-compose.prod.yml` (T4 commentaires)
- **Docker-compose dev** : `collega_backend/docker-compose.yml` (NE PAS modifier)
- **Tests pattern config** : aucun test existant pour `config.py` actuellement → T2 crée le premier
- **Tests conftest** : `collega_backend/tests/conftest.py` (fixtures `mock_db`, `client`)

### Frontend Flutter

- **AuthRepository** : `collega_app/lib/features/auth/data/auth_repository.dart` (T5 modifie `deleteAccount` L.233-248)
- **AuthNotifier** : `collega_app/lib/features/auth/auth_providers.dart` (T6 modifie `deleteAccount` L.77-89)
- **AppDatabase + deleteEverything** : `collega_app/lib/core/database/app_database.dart:55-78`
- **ProfileScreen `_AppCard`** : `collega_app/lib/features/profile/presentation/profile_screen.dart:525-625` (T10 ajoute test, code non modifié)
- **AuthState** : `collega_app/lib/features/auth/domain/auth_state.dart` (modèle inchangé)
- **AppLogger** : `collega_app/lib/core/utils/logger.dart` (pattern existant)
- **GoRouter app_router** : `collega_app/lib/core/router/app_router.dart` (NE PAS modifier — utilisé par redirect post-state-reset)

### Tests existants (patterns)

- `collega_backend/tests/api/test_auth.py` : pattern test endpoint DELETE (TestDeleteAccount classe Story 6.2)
- `collega_app/test/features/profile/profile_screen_test.dart` : pattern `_FakeAuthNotifier` + `_buildScreen` helper
- `collega_app/test/features/colleges/college_import_notifier_test.dart` : pattern ProviderContainer + overrides (Story 7.2)
- `collega_app/test/features/drill/drill_repository_test.dart` : pattern `_ScriptedAdapter` Dio (Story 7.2)

### Stories adjacentes

- **Story 6.2 (DELETE compte initial)** : `_bmad-output/implementation-artifacts/6-2-suppression-compte-conformite-rgpd.md`
- **Story 6.1 (Profil + AppCard placeholder)** : `_bmad-output/implementation-artifacts/6-1-ecran-profil-preferences.md`
- **Story 7.1 (Router redirect)** : `_bmad-output/implementation-artifacts/7-1-corrections-ux-flashcard-router.md`
- **Story 7.2 (Hardening async)** : `_bmad-output/implementation-artifacts/7-2-hardening-async-backend.md`

### Documentation

- `_bmad-output/implementation-artifacts/epic-mvp-retro-2026-05-19.md` (rétro MVP)
- `_bmad-output/implementation-artifacts/deferred-work.md` (items différés)
- `_bmad-output/planning-artifacts/epics.md` (epics MVP originaux)
- `_bmad-output/planning-artifacts/epics-v1.1.md` (epic 7 hardening)

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context) — bmad-dev-story workflow

### Debug Log References

- Backend pytest `tests/core/test_config_validators.py` : 12/12 passent en local
  (Python 3.14 / pydantic-settings v2). Suite complète backend : 242 passed,
  9 failed bcrypt/passlib pré-existants (cf. Story 7.2 dev notes), 1 skipped.
- Frontend `flutter test test/features/auth/auth_repository_test.dart` : 5/5 OK.
- Frontend `flutter test test/features/auth/auth_providers_test.dart` : 8/8 OK
  (5 tests pré-existants + 3 nouveaux Story 7.3).
- Frontend `flutter test test/features/profile/profile_screen_test.dart` : 15/15 OK
  (14 tests pré-existants + 1 nouveau Story 7.3 T10).
- `dart analyze lib/features/auth lib/features/profile test/features/auth test/features/profile`
  → No issues found.

### Completion Notes List

- **T1 — Validators Pydantic** : champ `environment` (default `development`) +
  `_validate_production_secrets` ajouté. Raise `ValueError` en prod, log warning
  en dev. Message liste **toutes** les violations d'un coup (cf. AC4).
- **T2 — Tests validators** : 12 tests `tests/core/test_config_validators.py`,
  utilise `Settings(_env_file=None, **kwargs)` pour bypasser le `.env` local
  (sinon le `secret_key="test-secret-key-for-pytest-only"` de `conftest.py`
  pollue les fixtures).
- **T3 — `.env.example`** : ajout `ENVIRONMENT=development` en tête avec
  commentaire d'explication des validators.
- **T4 — `docker-compose.prod.yml`** : commentaires YAML ajoutés sur `db` et
  `redis` ("NE PAS ajouter `ports:` — accès interne uniquement"). Pas de
  modification fonctionnelle (les ports étaient déjà absents).
- **T5 — `auth_repository.dart::deleteAccount`** : suppression du `await
  logout()` interne. `accessToken == null` retourne désormais un `errorMessage`
  explicite ("Session expirée…") au lieu d'un `AuthState()` vide silencieux.
- **T6 — `auth_providers.dart::deleteAccount`** : séquence ordonnée
  `RC.logOut → Drift.deleteEverything → repo.logout → state reset`, chaque
  étape locale en `try/catch` best-effort (log warning, pas de remontée UI).
  `state = AsyncData(AuthState())` exécuté hors des `try` pour garantir la
  sortie de session même en cas d'échec local.
- **T7 — Profile screen** : aucune modification (les `mounted` guards
  lignes 561/565/576 sont déjà en place — vérifié).
- **T8 — Tests `auth_repository_test.dart`** (NEW) : 5 tests couvrant token
  null, 200 OK, timeout, 500, connectionError. Pattern `_ScriptedAdapter` Dio
  réutilisé depuis Story 7.2 + `_FakeSecureStorage` qui trace `deletedKeys`
  (vérifie l'absence de wipe en cas d'erreur ou de succès — wipe désormais externe).
- **T9 — Tests `auth_providers_test.dart`** : 3 nouveaux tests (séquence OK,
  serveur KO sans wipe, Drift échoue mais state reset). `_FakeAuthRepository`
  étendu avec `onDeleteAccount` / `onLogout` callbacks pour tracer l'ordre.
  `_SpyAppDatabase extends AppDatabase.forTesting(NativeDatabase.memory())`
  trace `deleteEverything`. **Option B retenue pour RC** (cf. spec T9) : pas
  d'assertion sur `Purchases.logOut()` dans le callOrder car appel statique
  non-injectable ; le canal RC est mocké pour éviter `MissingPluginException`.
- **T10 — Test `profile_screen_test.dart`** : 1 nouveau test "chemin erreur"
  via paramètre optionnel `deleteError` ajouté à `_FakeAuthNotifier` et au
  helper `_buildScreen`. Vérifie toast destructive + absence du toast succès.
- **T11 — `docs/deployment.md`** (NEW) : section "Production secrets" listant
  les contraintes des validators, commande SSH non-destructive pour vérifier
  le `.env` NAS, et table récapitulative des services prod (ports DB/Redis
  internes uniquement).
- **T12 — Pré-vérification `.env` NAS prod** : confirmé conforme par le
  Project Lead (`jerome.lesur@astraga.fr`) le 2026-05-22 avant merge.
  Toutes les contraintes AC#7 OK (sans coller les valeurs ici).

**Décisions techniques notables :**
- RC `Option B` (pas de wrapper provider) : moins de churn, on accepte la
  perte de testabilité de l'appel `Purchases.logOut()` qui est statique. Le
  comportement réel est vérifiable manuellement en exécution sur device.
- Tests validators : `_env_file=None` (Pydantic Settings ≥ 2.x) bypass le
  `.env` local qui contient des valeurs `change-me*` polluantes.
- `_SpyAppDatabase` ajoute `addTearDown(db.close)` à chaque test pour éviter
  les warnings Drift "multiple instances".

**Risques résiduels non couverts (out-of-scope) :**
- 9 failures `bcrypt/passlib` Python 3.14 dans le backend — héritage du sprint
  précédent (Story 7.2), à traiter dans un sprint maintenance dédié.
- JWT toujours valide après suppression du compte — limitation architecturale
  pré-existante (Story 6.2 deferred / item A7 fermé). Hors scope.

### File List

**Backend (collega_backend/)**
- `app/core/config.py` — UPDATE : champ `environment` + validator `_validate_production_secrets` + logger
- `.env.example` — UPDATE : `ENVIRONMENT=development` en tête avec commentaire
- `docker-compose.prod.yml` — UPDATE : commentaires sécurité sur `db` et `redis`
- `tests/core/__init__.py` — NEW (package init)
- `tests/core/test_config_validators.py` — NEW : 12 tests prod/dev mode
- `docs/deployment.md` — NEW : section "Production secrets" + ports DB/Redis

**Frontend (collega_app/)**
- `lib/features/auth/data/auth_repository.dart` — UPDATE : `deleteAccount`
  refactor (plus de `await logout()` interne, errorMessage explicite si token null)
- `lib/features/auth/auth_providers.dart` — UPDATE : `deleteAccount` séquence
  ordonnée `RC → Drift → storage → state`, log warnings
- `test/features/auth/auth_repository_test.dart` — NEW : 5 tests + `_FakeSecureStorage` + `_ScriptedAdapter`
- `test/features/auth/auth_providers_test.dart` — UPDATE : `_FakeAuthRepository`
  étendu (`onDeleteAccount`/`onLogout`) + `_SpyAppDatabase` + 3 nouveaux tests `deleteAccount`
- `test/features/profile/profile_screen_test.dart` — UPDATE : `_FakeAuthNotifier`
  + `_buildScreen` acceptent `deleteError` + nouveau test "chemin erreur DELETE"

**Documentation projet (_bmad-output/)**
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — UPDATE : story `in-progress` → `review`
- `_bmad-output/implementation-artifacts/7-3-hardening-rgpd-safe-delete-config.md` — UPDATE : status, dev record

### Change Log

| Date       | Auteur        | Changement                                                                       |
|------------|---------------|----------------------------------------------------------------------------------|
| 2026-05-22 | Dev Agent     | T1-T4 backend : validators Pydantic mode-aware, `.env.example`, docker-compose commentaires |
| 2026-05-22 | Dev Agent     | T5-T6 frontend : refactor safe-delete (repo → notifier orchestration, séquence RC → Drift → storage → state) |
| 2026-05-22 | Dev Agent     | T8-T10 tests : 9 nouveaux tests (5 repo + 3 notifier + 1 widget chemin erreur)   |
| 2026-05-22 | Dev Agent     | T11 doc : `docs/deployment.md` section production secrets                        |
| 2026-05-22 | Project Lead  | T12 : pré-vérification `.env` NAS prod conforme                                  |
| 2026-05-22 | Dev Agent     | Status story → review                                                            |
| 2026-05-22 | Code Review   | 16 patches appliqués (validators strip+listes fermées, timeouts RC/Drift, réentrance, log msg, type-arg Dio, RC tests order). Status → done |

### Review Findings

Code review adversarial 2026-05-22 (3 reviewers parallèles : Blind Hunter, Edge Case Hunter, Acceptance Auditor).
Bilan : 0 decision-needed, 16 patch, 3 defer, 3 dismiss. Acceptance Auditor : aucune déviation AC/Tasks (conformité totale spec).

**Patches à appliquer**

_Backend — validators `app/core/config.py`_

- [x] [Review][Patch] `environment.lower()` sans `.strip()` — `ENVIRONMENT=" production "` traité comme dev → secrets faibles tolérés en prod réelle. **Critical.** [`collega_backend/app/core/config.py:63`]
- [x] [Review][Patch] SECRET_KEY : `"in-production" in self.secret_key.lower()` rejette des secrets légitimes contenant cette substring. Remplacer par une liste close ou un check anchored. [`collega_backend/app/core/config.py:70-73`]
- [x] [Review][Patch] SECRET_KEY : `startswith("change-me")` peut rejeter un secret légitime préfixé `change-me-…`. Adopter le pattern equality-list comme admin/tester. [`collega_backend/app/core/config.py:71`]
- [x] [Review][Patch] `if/elif` masque la double-violation SECRET_KEY (taille + placeholder) — l'opérateur corrige une erreur à la fois ; utiliser deux `if` indépendants. [`collega_backend/app/core/config.py:68-74`]
- [x] [Review][Patch] `CLAUDE_API_KEY="sk-ant-"` (préfixe nu, 7 chars) accepté en prod — ajouter une longueur minimale réaliste (≥ 20 chars). [`collega_backend/app/core/config.py:79`]
- [x] [Review][Patch] Whitespace non strippé sur `admin_password`/`tester_password`/`secret_key`/`webhook_secret` — `" "` ou `"change-me "` passent l'égalité stricte. Strip avant compare. [`collega_backend/app/core/config.py:83,87,92`]
- [x] [Review][Patch] Typo `ENVIRONMENT` (`prod`/`PROD`/`prd`) silencieusement traitée comme dev → fail-open. Émettre un `logger.warning` si la valeur n'est pas dans `{"development", "production"}`. [`collega_backend/app/core/config.py:63`]
- [x] [Review][Patch] `revenuecat_webhook_secret` coverage gap — seul `"change-me-in-production"` détecté ; `"change-me"` (sans suffixe) passe. Aligner sur la tuple-list admin/tester. [`collega_backend/app/core/config.py:92`]

_Backend — tests_

- [x] [Review][Patch] Test `_extractError(500)` n'asserte que `isNotNull` — pas de verrou sur la branche extraction `detail.message`. Asserter le contenu attendu. [`collega_app/test/features/auth/auth_repository_test.dart` (test status 500)]

_Frontend — `auth_providers.dart` + `auth_repository.dart`_

- [x] [Review][Patch] `_dio.delete<Map<String, dynamic>>` peut throw si le body 200 n'est pas JSON (proxy/CDN renvoyant HTML) → catch générique → état zombie (compte supprimé serveur, session locale intacte → 401 loop). Retirer le paramètre de type ou traiter type-errors après 2xx comme succès. [`collega_app/lib/features/auth/data/auth_repository.dart:247-251`]
- [x] [Review][Patch] Log « keeping local session intact » trompeur lors d'une race force-logout interceptor — la session est déjà partiellement vidée. Reformuler en « server DELETE refused — session may be force-logged by interceptor ». [`collega_app/lib/features/auth/auth_providers.dart:88-91`]
- [x] [Review][Patch] Double-tap « Supprimer définitivement » → 2e tap lit `accessToken == null` → toast « Session expirée » trompeur alors que la suppression a réussi. Verrouiller la réentrance au niveau Notifier (flag `_deleting` ou Completer). [`collega_app/lib/features/auth/auth_providers.dart:85` + `lib/features/profile/presentation/profile_screen.dart:537`]
- [x] [Review][Patch] Aucun timeout sur `Purchases.logOut()` ni `database.deleteEverything()` — un RC down ou un lock Drift bloque le wipe → state reset jamais exécuté → spinner infini. Ajouter `.timeout(const Duration(seconds: 5))` + catch `TimeoutException`. [`collega_app/lib/features/auth/auth_providers.dart:97-109`]
- [x] [Review][Patch] Pas de guard `ref.mounted` avant `state = AsyncData(AuthState())` — si le widget est démonté pendant les awaits, l'assignation lève `StateError("disposed")`. [`collega_app/lib/features/auth/auth_providers.dart:120`]

_Frontend — tests_

- [x] [Review][Patch] `Purchases.logOut()` non asserté — le mock channel renvoie `null` sans tracer l'appel ; supprimer la ligne ne casse aucun test. Remplacer le handler par un capteur de méthodes appelées et asserter l'ordre `logOut → deleteEverything → logout`. [`collega_app/test/features/auth/auth_providers_test.dart:95-99,183-205`]

_Documentation_

- [x] [Review][Patch] `.env.example` — le commentaire en tête omet `TESTER_PASSWORD` et `REVENUECAT_WEBHOOK_SECRET` dans la liste des variables bloquantes en prod. [`collega_backend/.env.example:1-4`]

**Differés (pre-existing / hors scope 7.3)**

- [x] [Review][Defer] Logger possiblement non configuré au moment de `Settings()` (instanciation module-level avant que uvicorn monte ses handlers) — warning dev peut être avalé. Pre-existing pattern startup. [`collega_backend/app/core/config.py:105`] — deferred, pre-existing
- [x] [Review][Defer] `ShadToaster.of(context)` peut throw si force-logout déclenche un redirect `/demo` pendant l'await — pattern UI pré-existant. [`collega_app/lib/features/profile/presentation/profile_screen.dart:569,577`] — deferred, pre-existing
- [x] [Review][Defer] Commentaires sécurité `docker-compose.prod.yml` non enforceables par CI — un futur dev peut ajouter `ports:` malgré le commentaire. Ajouter un step CI grep si un pipeline est monté. [`collega_backend/docker-compose.prod.yml`] — deferred, pre-existing

**Dismissed (non écrits dans deferred-work)**

- SECRET_KEY entropy nulle (`"aaaa…32"`) — hors scope spec.
- Race toast destructive vs redirect `/demo` (force-logout 401) — explicitement accepté par AC2.
- `const FlutterSecureStorage()` en test — sans effet : le mock channel `plugins.it_nomads.com/flutter_secure_storage` est installé (`auth_providers_test.dart:101-104`).

**Mentions positives (Acceptance Auditor)**

- Test bonus « Drift échoue mais state quand même reset » (`auth_providers_test.dart` L.262-295) — couvre explicitement l'invariant AC3 « state TOUJOURS exécuté en dernier ».
- `_env_file=None` dans les tests config — sécurise contre la pollution `.env` CI mentionnée comme risque L.256 de la spec.
