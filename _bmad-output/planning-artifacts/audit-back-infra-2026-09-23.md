# Audit back + infra Collega — 2026-09-23

Audit en lecture seule (5 axes : sécurité, fiabilité, code/archi, infra/exploitation, perf/coûts) de `collega_backend/` et de la prod NAS, sur `main` 560e503. Chaque constat cite sa preuve (fichier:ligne ou commande) ; « non vérifié » quand ce n'était pas possible.

Bilan : pas de faille d'accès inter-utilisatrices (chaque route vérifie le propriétaire), sauvegardes nocturnes sérieuses. Les vrais risques beta sont la fiabilité des imports, l'absence de supervision et des limites de débit contournables.

## Constats majeurs

| # | Constat | Preuve | Effort |
|---|---|---|---|
| 1 | Un réimport supprime items + fiches à la fin de l'OCR (`ON DELETE CASCADE`) avant la génération ; si la génération échoue ou est stoppée, `College.status` n'est jamais passé à `failed` → fiches perdues, SSE qui tourne 3 h, `/items` et `/cards` en 409 | `ocr_worker.py:218`, `generation_worker.py:69-73`, `admin.py:737`, `colleges.py:694` | S / M |
| 2 | Jobs bloqués pour toujours (timeout ARQ = `CancelledError` non attrapé, Redis qui perd la file, `commit` sans `rollback` dans l'OCR) ; aucun cron de purge → 409 `JOB_IN_PROGRESS` jusqu'au Stop admin | `generation_worker.py:66`, `ocr_worker.py:64-70`, `workers/settings.py:73-78` | M |
| 3 | Aucune supervision : Uptime Kuma absent, `/health` ne teste ni DB ni Redis, pas de healthcheck api/worker ; le récap Telegram 08:00 ne voit que l'état Docker | `health.py:6-8`, NAS `docker ps` | S |
| 4 | Chaque stream SSE garde sa session `get_db` (connexion « idle in transaction ») jusqu'à 3 h → ~15 streams par processus saturent le pool (5+10) ; cause backend de l'incident de septembre, seule l'app avait été corrigée | `colleges.py:629`, `deps.py:107`, `database.py:11-12` | S |
| 5 | Limite de débit indexée sur le 1er élément de `X-Forwarded-For` (falsifiable) ; aucune limite sur l'auth admin/tester ni `/refresh` ; service token CF compilé dans l'IPA | `core/limiter.py:7-11`, `deps.py:18-64`, `auth.py:59` | S / M |
| 6 | Les PDF ne sont jamais supprimés (ni fin de job, ni suppression de compte, ni `incoming_*` orphelins) — contredit `privacy.md` (« suppression complète ») ; disque qui se remplit | `admin.py:796` seul `unlink`, `auth.py:150-159`, `cleanup_worker.py` | S |
| 7 | `alembic check` échoue : index/contraintes anti-course (`idx_one_active_job_per_college`, `uq_colleges_user_ref_id`, index FTS…) absents des modèles → une migration autogénérée les supprimerait | `alembic check` sur Postgres 16 jetable | S |

## Autres constats

**Exploitation**
- Prod sans `ENVIRONMENT=production` (`grep -c` = 0 dans le `.env` du NAS) → validateurs de prod en simple warning (`config.py:141-145`).
- `CloudflaredTunnel` et `Nginx-Proxy-Manager-Official` en `restart=no`.
- Aucune config logging Python (root à WARNING, `logger.info` perdus, pas d'horodatage) ; logs Docker `max-file:1` perdus à chaque `up -d`.
- Restauration jamais prouvée sur vraies données (`backup-verify` : « 2 erreurs de rejeu », dump 416 Ko → 64 Ko inexpliqué) ; RPO 24 h, Postgres sur NVMe cache sans redondance.
- Image Docker Hub `tistech0/collega-backend` **publique** (code + prompts, 734 pulls), en root, mono-stage, 523 Mo ; compose sur `:latest` (rollback non outillé) ; worker sans `depends_on: migrate`.
- Compose du dépôt ≠ prod (port `430:8000` retiré sur le NAS le 14/08) ; `install.md`, `Caddyfile*` obsolètes ; `docs/deployment.md` faux sur le validateur `SECRET_KEY`.
- Aucune limite mémoire/CPU ; Redis sans mot de passe (non exposé) et RDB seul.

- **Notifications push jamais actives en prod** (découvert au déploiement du chantier 0) : aucune variable `APNS_*` dans le `.env` du NAS → `NullNotificationService` au démarrage de l'API et du worker ; ni rappel quotidien ni « import terminé » ne partent. Il faut une clé `.p8` Apple (Key ID, Team ID) créée par l'utilisateur, puis `APNS_KEY_PATH` monté dans les conteneurs et `APNS_USE_SANDBOX=false` pour les builds TestFlight/App Store.

**Coûts Claude**
- `"max_retries": 3` ignoré par ARQ (`settings.py:85`) → `max_tries=5` par défaut ; la génération (une transaction pour tous les appels, `card_generator.py:84-226`) repart de zéro à chaque relance/redéploiement → Claude repayé.
- Import typique ≈ 1,15 € estimé (0,7–1,6), 80 % en entrée (tout le texte OCR de l'item, `item_detector.py:307`). Leviers : Batch API (−50 %), génération parallèle (Semaphore 4-5, ×3-5 plus rapide), allègement de l'entrée, évaluation Haiku 4.5 (qualité médicale à valider). Chiffre réel à lire dans `generation_jobs.input_tokens/output_tokens`.
- Tokens des jobs en échec/annulés/relancés et de `regenerate`/`evaluate-semantic` non comptés → console admin sous-estime.
- `/evaluate-semantic` sans limite ni `max_length` ; `user_note` sans `max_length`.

**Fonctionnalités cassées**
- Régénérer une fiche échoue au-delà de 24 h (`cleanup_ocr_text` vide `ocr_text`, `claude_client.py:162-166` → 503).
- Hash-sharing : copie l'état courant des fiches du collège source (régénérées, `user_note`, supprimées) ; ne marche pas pour un réimport du même PDF (fiches déjà supprimées) ; calculé après l'OCR.

**Sécurité (hors tableau)**
- Jetons non révocables (refresh 30 j non renouvelé), pas de reset mot de passe ni de désactivation de compte.
- Redis coupé → `POST /login` en 500 (slowapi sans `swallow_errors`).
- `/openapi.json` public (liste les routes admin).
- Route tester : identifiant partagé qui lit les fiches de toutes les utilisatrices.
- Webhook RevenueCat : pas d'ordre ni d'idempotence (un `EXPIRATION` rejoué peut désabonner après un `RENEWAL`).
- `privacy.md` inexacte (token APNs non supprimé au logout, pas de limite sur refresh, logs).
- python-jose 3.5.0 (CVE 2024 corrigées depuis 3.4.0 mais peu maintenu), passlib 1.7.4 non maintenu ; `pip-audit` non lancé.

**Développement**
- Tests instables : compteurs slowapi dans le Redis local partagé → 3 à 8 `429 == 200` dès le 2e lancement.
- Pas de CI, pas de ruff/mypy (369 erreurs ruff sur un jeu raisonnable), pas de `poetry.lock`, venv Python 3.14 vs image 3.11, `pytest-cov`/alembic/asyncpg absents du venv.
- `colleges.py` (869 l.) et `admin.py` (972 l.) mélangent routes, métier et SQL ; pipeline d'import dupliqué admin/utilisateur (écarts de comportement) ; `create_pool` ARQ recréé à chaque requête ; format d'erreur non homogène (429 slowapi, 422 natif, 25 routes sans `response_model`).
- Mocks `side_effect` qui figent l'ordre des requêtes (23), harnais SQLite réel peu utilisé.

**Points solides** : contrôles de propriétaire partout, quotas atomiques (`UPDATE … RETURNING`) + index unique partiel, reprise OCR page par page, upload par morceaux atomique, `compare_digest`, validateurs de prod stricts, index FK et GIN en place, sauvegarde `backup-nas` (dump + kopia + R2 chiffré) avec `backup-check` / `backup-verify`, DB et Redis non exposés, 481 tests en ~5 s.

## Chantiers (ordre validé : 0 → 1, 3 en parallèle, puis 2, 4, 5)

0. **Corrections rapides d'exploitation** — `ENVIRONMENT=production`, restart `unless-stopped` cloudflared + NPM, supervision (Uptime Kuma ou healthchecks externe + Telegram), `/health` profond + healthchecks compose, logging Python + `max-file: 3`, `openapi_url=None`, dépôt Docker Hub privé, `max_tries`, test de restauration réel + runbook.
1. **Fiabilité des imports** (bloquant beta) — réimport atomique (bascule ancien/nouveau contenu), `College.status=failed`, cron de purge des jobs bloqués, libérer la session SSE, génération commitée par item + reprise, purge des PDF (fin de job, compte supprimé, orphelins), alignement modèles/migrations (`alembic check`), régénération > 24 h, hash-sharing depuis le job source et avant l'OCR.
2. **Sécurité** (story 7.10 revue) — clé client `CF-Connecting-IP`/proxy de confiance, limites admin/refresh/drill par user, fail-open Redis, révocation (`token_version`) + reset mot de passe admin, `/admin` derrière Access OTP, webhook ordonné, `privacy.md` alignée, PyJWT/bcrypt direct.
3. **Outils de développement** — tests indépendants de Redis, `poetry.lock` + Python 3.11 local, ruff, CI GitHub (ruff, pytest, `alembic check`), script de déploiement (tag sha, dump pré-migration, refus si tests rouges), compose prod versionné, README/CLAUDE.md dev, docs corrigées, fichiers morts.
4. **Coûts et performances** — mesurer le coût réel, génération parallèle, comptage complet des tokens, allègement de l'entrée, Batch API, évaluation Haiku.
5. **Refactorisation** — `services/imports.py` unique (admin + utilisateur), découpage `colleges/` et `admin/`, `AppError` + handlers, pool ARQ partagé. **Nettoyage admin** : suppression de la partie testeur web (`/tester`, `/v1/tester/*`, identifiants testeur, tests) ; l'API des pouces de l'app (`POST /v1/flash-cards/{id}/feedback`) est conservée ; les vues admin « feedback » et « pertinence » lisent `flash_cards.user_feedback` ; table `tester_feedbacks` exportée en CSV puis supprimée.

**Après ce chantier back/infra (côté app)** : pouces 👍/👎 pendant le drill, en plus de l'écran détail d'item.
