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

- **PDF endommagé signalé comme « vide »** (constaté le 2026-09-23 sur `ANAPATH 4e.pdf`, fichier réellement corrompu : `startxref` qui pointe au milieu de données compressées) : l'import l'accepte (seuls les magic bytes sont vérifiés) puis l'OCR échoue avec « PDF is empty or unreadable (0 pages) ». Traité au chantier 1 : refus immédiat 422 `PDF_DAMAGED`. Réparation automatique (qpdf/pikepdf) : plus tard, éventuellement.

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

## Chantiers (0 et 1 faits ; suite validée le 2026-09-24 : 3 → 5 → 2 → 4)

Chantiers 2 à 5 **spécifiés le 2026-09-24** (specs `chantier-2-securite-spec.md`, `chantier-3-outillage-dev-spec.md`, `chantier-4-couts-claude-spec.md`, `chantier-5-refacto-spec.md`) ; implémentation autonome selon `refonte-back-infra-handoff.md`.

0. ✅ **Corrections rapides d'exploitation — FAIT le 2026-09-23** (branche `feat/chantier-0-exploitation`, image `2083f55`) : `/health` vérifie Postgres + Redis (503 sinon) ; healthchecks compose api (`/health`) et worker (`arq --check`, clé toutes les 60 s) ; worker après `migrate` ; logs Python horodatés + rotation sur 3 fichiers ; `openapi_url=None` en prod ; `max_tries=3` ; limites mémoire (worker 4 Go, api 1 Go) ; compose du dépôt = compose du NAS ; `ENVIRONMENT=production` dans le `.env` du NAS ; cloudflared + NPM en `restart unless-stopped` (live + modèles Unraid) ; supervision `collega-health` chaque minute (LAN + Cloudflare, alerte Telegram immédiate + message au retour, testée par une coupure Redis réelle) ; restauration prouvée dans un Postgres jetable + `docs/restore.md` ; dépôt Docker Hub privé, NAS connecté par jeton lecture seule (pull anonyme → 401). Reste hors chantier : clé APNs (notifications push jamais actives en prod).
1. ✅ **Fiabilité des imports — IMPLÉMENTÉ ET DÉPLOYÉ le 2026-09-23** (branche `feat/chantier-1-fiabilite-imports`, image `0e76425`, migration 018 ; spec `chantier-1-fiabilite-imports-spec.md`, plan `chantier-1-fiabilite-imports-plan.md`) : contenu par empreinte (pages, textes d'items, générations d'origine partagées), brouillon puis bascule transactionnelle (réimport incrémental : seuls les items modifiés sont régénérés, fiches et progression des autres conservées), reprise sans repayer Claude, statut collège = contenu / statut job = import, `fail_job` centralisé (quota rendu), cron des imports bloqués, SSE sans session retenue, 422 `PDF_DAMAGED`, purges (contenu non référencé, PDF, suppression de compte), régénération sans limite de temps, `alembic check` vide, garde-fou « mauvais PDF ». Revue de code indépendante : 2 critiques + 2 hautes + 4 moyennes corrigées. 3 collèges de prod remplis (66/66 items). Validé sur iPhone et fusionné dans `main` (d1b05da).
2. **Sécurité** (story 7.10 revue) — clé client `CF-Connecting-IP`/proxy de confiance, limites admin/refresh/drill par user, fail-open Redis, révocation (`token_version`) + reset mot de passe admin, `/admin` derrière Access OTP, webhook ordonné, `privacy.md` alignée, PyJWT/bcrypt direct.
3. ✅ **Outils de développement — FAIT ET DÉPLOYÉ le 2026-09-24** (branche `feat/refonte-back-infra`, image `7a2f3ef`, plan `chantier-3-outillage-dev-plan.md`) : Python 3.11 + `poetry.lock` (versions de l'image de prod), ruff 0 erreur, mypy 0 erreur sur `app/core`+`app/services`, CI GitHub Actions (backend + app, goldens tagués `golden` hors CI Linux), `scripts/deploy.sh` (image par commit, dump, `IMAGE_TAG`, retour arrière testé), image multi-stage non root 385 Mo, Redis avec mot de passe, README/CLAUDE.md/runbooks, ménage (Caddy, install.md, seed_dev). Écart : `gh` local ne voit pas le dépôt (compte CrazyGrower) → `deploy.sh --force` et CI rejouée en local (act, conteneur Flutter). Spec d'origine : tests indépendants de Redis, `poetry.lock` + Python 3.11 local, ruff, CI GitHub (ruff, pytest, `alembic check`), script de déploiement (tag sha, dump pré-migration, refus si tests rouges), compose prod versionné, README/CLAUDE.md dev, docs corrigées, fichiers morts.
4. **Génération des fiches (qualité et coûts)** — élargi après la revue qualité des 504 fiches de prod (couverture du rang A 3/10, découpage des items cassé) : Sonnet 5, prompt p2 (0-40 fiches, rang A d'abord, type cas clinique), correction du découpage, génération parallèle, comptage complet des tokens, allègement de l'entrée, vidage du contenu puis réimport. Pas de Batch API.
5. **Refactorisation** — `services/imports.py` unique (admin + utilisateur), découpage `colleges/` et `admin/`, `AppError` + handlers, pool ARQ partagé. **Nettoyage admin** : suppression de la partie testeur web (`/tester`, `/v1/tester/*`, identifiants testeur, tests) ; l'API des pouces de l'app (`POST /v1/flash-cards/{id}/feedback`) est conservée ; les vues admin « feedback » et « pertinence » lisent `flash_cards.user_feedback` ; table `tester_feedbacks` exportée en CSV puis supprimée.

**Après ce chantier back/infra (côté app)** : pouces 👍/👎 pendant le drill, en plus de l'écran détail d'item.
