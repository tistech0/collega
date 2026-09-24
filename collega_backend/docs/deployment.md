# Déploiement — collega_backend

## Déployer : `scripts/deploy.sh` (chantier 3)

Depuis le Mac, OrbStack lancé (`orb start`), commit poussé :

```sh
./collega_backend/scripts/deploy.sh            # HEAD
./collega_backend/scripts/deploy.sh <sha>      # un commit précis (retour arrière)
./collega_backend/scripts/deploy.sh --force …  # passe outre une CI non verte / illisible (avertissement)
```

Le script :
1. refuse si `collega_backend/` a des modifications non commitées ou si le commit n'est pas poussé ;
2. refuse si la CI `ci.yml` n'est pas verte sur ce commit (`gh run list`, il faut un `gh` connecté à un compte qui voit `tistech0/collega`) ;
3. construit `tistech0/collega-backend:<sha>` (linux/amd64) depuis un worktree du commit, vérifie que `app/main.py` de l'image est celui du commit et que l'app s'importe, pousse l'image (plus de tag `latest`) ;
4. sur le NAS (`ssh nas`, `/mnt/user/appdata/compose-stacks/collega`) : attend qu'aucun import ne tourne (clés `arq:in-progress:*`, `arq:queue`, jobs actifs en base ; 30 min max puis abandon sans rien modifier), fait un dump `pg_dumpall` dans `/mnt/user/appdata/collega/backups/collega_pre_<sha>_<date>.sql.gz`, valide puis installe le `docker-compose.prod.yml` du commit (ancien sauvegardé en `docker-compose.yml.bak-<date>`), écrit `IMAGE_TAG=<sha>` dans le `.env` (seule ligne modifiée, `.env.bak-<date>` avant), `docker compose pull` + `up -d` ;
5. attend `healthy` sur api et worker (3 min), affiche les logs de `collega-migrate-1` et `/health`.

**Retour arrière** : `deploy.sh <sha précédent>` (le script l'affiche en cas d'échec). Si une migration a changé le schéma entre les deux, restaurer aussi le dump pré-déploiement ([`restore.md`](restore.md)) : l'ancienne image ne connaît pas le nouveau schéma.

### Particularités de la prod

- **Image non root** (uid 1000 `collega`) : le dossier bind des PDF `/mnt/user/appdata/collega/pdfs` appartient à `1000:1000` (`chown -R 1000:1000`, fait au déploiement du chantier 3). À refaire si le dossier est recréé.
- **Redis protégé** : `REDIS_PASSWORD` dans le `.env` du NAS ; le compose passe `--requirepass`, surcharge `REDIS_URL` pour migrate/api/worker et pose `REDISCLI_AUTH` dans le conteneur redis (donc `docker exec collega-redis-1 redis-cli …` fonctionne sans mot de passe en argument).
- `IMAGE_TAG` est obligatoire (le compose refuse de démarrer sans).
- **Migration 019 (chantier 5)** : elle supprime la table `tester_feedbacks` (testeur web retiré). L'exporter **avant** le déploiement qui l'embarque (le conteneur `collega-migrate-1` l'applique au `up -d`). L'image en service ne contient pas encore le script : il est passé sur l'entrée standard, puis le CSV est rapatrié dans `_bmad-output/implementation-artifacts/exports/` :
  ```sh
  ssh nas 'docker exec -i collega-api-1 python - --out /tmp/collega_pdfs' < collega_backend/scripts/export_tester_feedbacks.py
  ```
  (Avec une image qui contient le script : `docker exec collega-api-1 python scripts/export_tester_feedbacks.py --out /tmp/collega_pdfs`.) Le fichier `tester_feedbacks_<AAAAMMJJ>.csv` atterrit dans le dossier des PDF du NAS. Les variables `TESTER_*` du `.env` du NAS sont désormais ignorées et restent en place.
- Vérifier une config de prod sans afficher de secret : `docker exec -e ENVIRONMENT=production collega-api-1 python -c "from app.core.config import Settings; Settings()"`.

## Production secrets — validators stricts (Story 7.3)

Le backend refuse de démarrer en `ENVIRONMENT=production` si l'une des conditions
suivantes est violée (cf. `app/core/config.py::_validate_production_secrets`) :

- `SECRET_KEY` fait moins de 32 caractères **OU** est égale à l'un des placeholders
  connus (`change-me`, `change-me-in-production`… : égalité stricte, liste dans
  `_PLACEHOLDER_SECRET_KEYS`).
- `CLAUDE_API_KEY` est vide **OU** ne commence pas par `sk-ant-`.
- `ADMIN_PASSWORD` vaut `change-me` ou `change-me-in-production`.
- `REVENUECAT_WEBHOOK_SECRET` vaut `change-me-in-production`
  (le non-vide est aussi vérifié par `_require_webhook_secret`).

Le message `ValidationError` liste **toutes** les variables fautives d'un coup,
ex. : `Production secrets invalid — Insecure config values: SECRET_KEY (must be ≥ 32 chars), ADMIN_PASSWORD (default placeholder value). Refuse to start.`

En `ENVIRONMENT=development` (default), les mêmes violations émettent un
`logger.warning("DEV mode: ...")` mais le démarrage continue.

### Vérifier le `.env` NAS prod

Le fichier `.env` prod se trouve sur
`/mnt/user/appdata/compose-stacks/collega/.env` et **ne doit jamais être
écrasé** (mémoire `project_nas_env.md`). Vérification non-destructive :

```bash
ssh nas 'grep -oE "^(ENVIRONMENT|SECRET_KEY|ADMIN_PASSWORD|CLAUDE_API_KEY|REVENUECAT_WEBHOOK_SECRET|REDIS_PASSWORD|IMAGE_TAG)=" /mnt/user/appdata/compose-stacks/collega/.env'
```

(`-o` : n'affiche que les noms des variables présentes, jamais les valeurs.)

Pour mettre à jour une valeur fautive : éditer **uniquement la ligne concernée**
via `nano` / `vi` sur le NAS — ne pas régénérer le fichier complet ni copier
`.env.example` par-dessus.

## Ports DB / Redis — accès interne uniquement

`docker-compose.prod.yml` n'expose **aucun port** sur l'host pour `db`
(PostgreSQL) et `redis` — accès interne uniquement via le bridge `collega_net`.
Un commentaire YAML en tête de chaque service rappelle cette contrainte.

**Ne PAS ajouter de section `ports:` à ces services** sans validation sécurité :
exposer la DB ou Redis sur l'host les rend accessibles depuis le réseau Unraid
sans authentification supplémentaire.

Le `docker-compose.yml` (dev) expose `5432` et `6379` sur `127.0.0.1` seulement,
pour les outils dev locaux (TablePlus, RedisInsight).

## Service map (prod)

| Service  | Image                                | Ports exposés    | Réseau         |
|----------|--------------------------------------|------------------|----------------|
| `api`    | `tistech0/collega-backend:${IMAGE_TAG}` | aucun (NPM via `collega_net`) | `collega_net` |
| `worker` | `tistech0/collega-backend:${IMAGE_TAG}` | aucun            | `collega_net` |
| `migrate`| `tistech0/collega-backend:${IMAGE_TAG}` | aucun (one-shot) | `collega_net` |
| `db`     | `postgres:16-alpine`                 | **aucun**        | `collega_net` |
| `redis`  | `redis:7-alpine`                     | **aucun**        | `collega_net` |

Le reverse proxy est Nginx Proxy Manager (proxy host 53) sur le NAS, joint par le
réseau `collega_net` ; le chemin public passe par le tunnel Cloudflare + Access. Il
n'est pas dans le `docker-compose.prod.yml`.

## CGU + Politique de confidentialité (Story 7.4 — FR40)

**Option retenue : B — bundle Flutter.** Les textes légaux sont embarqués dans
l'app via `collega_app/assets/legal/` et rendus en runtime par `flutter_markdown`
sur l'écran `LegalScreen` (`collega_app/lib/features/legal/presentation/legal_screen.dart`).

Les **fichiers sources** (versionnés dans Git) :

- `collega_app/assets/legal/cgu.md` — Conditions générales d'utilisation
- `collega_app/assets/legal/privacy.md` — Politique de confidentialité

Aucune route backend, aucune dépendance internet pour ces écrans. La navigation Flutter passe par les routes
`/legal/cgu` et `/legal/privacy` (cf. `app_router.dart`), déclenchées depuis
`_AppCard` dans l'écran Profil.

### Procédure de mise à jour

1. Modifier `collega_app/assets/legal/cgu.md` ou `privacy.md` localement.
2. Incrémenter la ligne `**Version : YYYY-MM-DD**` en tête du fichier modifié.
3. Tester localement avec `flutter test` puis `flutter run` sur device.
4. Commit + push + nouvelle release IPA (TestFlight ou App Store) — **les CGU
   sont dans le bundle, donc nécessitent un redéploiement de l'app pour être
   visibles par les utilisatrices**.
5. En cas de changement de finalité de traitement (RGPD), prévoir un écran
   d'acceptation explicite au prochain lancement (consentement renouvelé).

### Notification utilisateurs en cas de modification substantielle

Procédure recommandée si la modification touche une finalité, un sous-traitant
ou une donnée nouvelle collectée :

- envoyer un push APNs ciblé via `daily_reminder_worker` ad-hoc, OU
- ajouter une modale au démarrage de l'app (à intégrer dans `app_router.dart`
  pour les comptes existants).

Responsable de la dernière révision : Matthis Lesur (2026-05-22).

## Upload par morceaux (Story 7.11)

- Cloudflare limite chaque requête à 100 MB : au-delà de 90 MB l'app passe par
  `POST /v1/colleges/{ref_id}/import/init` → `PUT /v1/colleges/import/{upload_id}/parts/{n}`
  (morceaux de 25 MB) → `POST /v1/colleges/import/{upload_id}/complete`.
- Les morceaux sont écrits dans `${PDF_STORAGE_PATH}/uploads/{upload_id}/` sur le volume
  `pdf_storage` (partagé api/worker). Pic disque ≈ 2 × taille du PDF pendant `complete`
  (morceaux + fichier assemblé), puis les morceaux sont purgés.
- État en Redis (`upload:{id}` hash + `upload:{id}:parts` set, TTL 24 h). Le cron
  `cleanup_stale_uploads` (worker, toutes les heures à xx:30) purge les dossiers orphelins
  (sans clé Redis ou > 24 h).
- Vérification après déploiement : `scripts/chunked_upload.py` (voir docstring), avec
  `--cloudflare-ip` + `--env-file ../collega_app/.env.local` pour reproduire le chemin hors LAN.
  Couper le script en cours de route puis relancer avec `--resume <upload_id>` vérifie la reprise.
