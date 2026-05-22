# Déploiement — collega_backend

## Production secrets — validators stricts (Story 7.3)

Le backend refuse de démarrer en `ENVIRONMENT=production` si l'une des conditions
suivantes est violée (cf. `app/core/config.py::_validate_production_secrets`) :

- `SECRET_KEY` fait moins de 32 caractères **OU** commence par `change-me*` **OU**
  contient `in-production` (placeholders du `.env.example`).
- `CLAUDE_API_KEY` est vide **OU** ne commence pas par `sk-ant-`.
- `ADMIN_PASSWORD` vaut `change-me` ou `change-me-in-production`.
- `TESTER_PASSWORD` vaut `change-me` ou `change-me-in-production`.
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
ssh <user>@<nas> 'grep -E "^(ENVIRONMENT|SECRET_KEY|ADMIN_PASSWORD|TESTER_PASSWORD|CLAUDE_API_KEY|REVENUECAT_WEBHOOK_SECRET)=" /mnt/user/appdata/compose-stacks/collega/.env'
```

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

Le `docker-compose.yml` (dev) expose intentionnellement `5432` et `6379` pour
les outils dev locaux (TablePlus, RedisInsight). Cette divergence est voulue.

## Service map (prod)

| Service  | Image                                | Ports exposés    | Réseau         |
|----------|--------------------------------------|------------------|----------------|
| `api`    | `tistech0/collega-backend:latest`    | `430:8000` (host) | `collega_net` |
| `worker` | `tistech0/collega-backend:latest`    | aucun            | `collega_net` |
| `migrate`| `tistech0/collega-backend:latest`    | aucun (one-shot) | `collega_net` |
| `db`     | `postgres:16-alpine`                 | **aucun**        | `collega_net` |
| `redis`  | `redis:7-alpine`                     | **aucun**        | `collega_net` |

Le reverse proxy (HTTPS, certificats) est géré au niveau Unraid externe et n'est
pas dans le `docker-compose.prod.yml`.

## CGU + Politique de confidentialité (Story 7.4 — FR40)

**Option retenue : B — bundle Flutter.** Les textes légaux sont embarqués dans
l'app via `collega_app/assets/legal/` et rendus en runtime par `flutter_markdown`
sur l'écran `LegalScreen` (`collega_app/lib/features/legal/presentation/legal_screen.dart`).

Les **fichiers sources** (versionnés dans Git) :

- `collega_app/assets/legal/cgu.md` — Conditions générales d'utilisation
- `collega_app/assets/legal/privacy.md` — Politique de confidentialité

Aucune route backend, aucune dépendance internet ; aucune configuration Caddy
externe nécessaire pour ces écrans. La navigation Flutter passe par les routes
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

Responsable de la dernière révision : Lesurmatthis (2026-05-22).
