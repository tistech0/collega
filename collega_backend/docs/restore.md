# Restaurer Collega (base, PDF, `.env`)

Ce qu'il y a à restaurer et où le trouver. Sauvegarde : `backup-nas` (User Script, chaque nuit à 03:30) → dump de cluster, instantanés kopia, réplication chiffrée vers Cloudflare R2.

| Élément | Source de sauvegarde | Perte maximale (RPO) |
|---|---|---|
| Postgres (comptes, collèges, fiches, jobs) | `/mnt/user/nas-backup/dumps/collega-db-1.sql.gz` (array, protégé par la parité) + kopia `/dumps` + R2 | depuis 03:30 |
| PDF importés | kopia `/source/collega/pdfs` (= `/mnt/user/appdata/collega/pdfs`) + R2 | depuis 03:30 |
| `.env` de prod | kopia `/source/compose-stacks/collega/.env` + R2 | dernière modification |
| `docker-compose.yml` | le dépôt : `collega_backend/docker-compose.prod.yml` | — |
| Redis (file ARQ, uploads en cours) | non sauvegardé : volatil, les imports en cours sont à relancer | — |

Le mot de passe kopia et les identifiants R2 sont sur la clé USB (`/boot/config/secrets/kopia_password`, `r2_credentials`). **Si la clé USB est perdue avec le NAS, R2 est illisible** : en garder une copie ailleurs (gestionnaire de mots de passe).

## Vérifier un dump sans toucher à la prod (testé le 2026-09-23)

À faire après tout changement de schéma important, ou pour se rassurer. Conteneur jetable sur un réseau interne, supprimé à la fin.

```sh
ssh nas
docker network create --internal collega-restore-net
docker run -d --name collega-restore-test --network collega-restore-net --network-alias db \
  -e POSTGRES_HOST_AUTH_METHOD=trust postgres:16-alpine
docker exec collega-restore-test pg_isready -U postgres   # attendre « accepting connections »
zcat /mnt/user/nas-backup/dumps/collega-db-1.sql.gz | docker exec -i collega-restore-test psql -U postgres -q -o /dev/null
docker exec collega-restore-test psql -U postgres -d collega -Atc \
  "select count(*) from users; select count(*) from colleges; select count(*) from flash_cards"
# Depuis le chantier 1 (migration 018) : contenu par empreinte, dans le même dump.
docker exec collega-restore-test psql -U postgres -d collega -Atc \
  "select count(*) from ocr_pages; select count(*) from item_texts; select count(*) from item_generations"
# Le code de l'app sur la base restaurée (migrations comprises) :
docker run --rm --network collega-restore-net \
  -e DATABASE_URL=postgresql+asyncpg://postgres@db:5432/collega -e REDIS_URL=redis://localhost:6379/0 \
  -e SECRET_KEY=restore-test-only-0123456789abcdefghijkl -e CLAUDE_API_KEY=x -e ADMIN_USERNAME=a \
  -e ADMIN_PASSWORD=b -e REVENUECAT_WEBHOOK_SECRET=c \
  tistech0/collega-backend:latest alembic upgrade head
docker rm -f collega-restore-test && docker network rm collega-restore-net
```

Résultat attendu, et ce qui est normal :
- **exactement 2 erreurs** au rejeu : `current user cannot be dropped` et `role "postgres" already exists`. Le dump est un `pg_dumpall --clean` qui tente de recréer le rôle `postgres` ; sans conséquence. (Ce sont les « 2 erreurs de rejeu » du journal `backup-verify`.)
- le dump restaure aussi le **mot de passe de prod** du rôle `postgres` : c'est pour cela que le conteneur jetable est en `trust`.
- (Dumps antérieurs à la migration 018) `items.ocr_text` était vidé 24 h après l'import par l'ancienne purge `cleanup_ocr_text` : pas une perte. Depuis le chantier 1, le texte est conservé (`ocr_pages`, `item_texts`) et le dump grossit avec les collèges.
- la version Alembic du dump peut être en retard sur le code si une migration a été déployée dans la journée : `alembic upgrade head` (service `migrate`) la rattrape.

Résultat du 2026-09-23 : 4 utilisateurs, 2 collèges, 44 items, 341 fiches restaurés ; migrations 015 → 017 appliquées sans erreur.

## Restaurer la prod (procédure, jamais exécutée en réel)

1. **Arrêter ce qui écrit** : `cd /mnt/user/appdata/compose-stacks/collega && docker compose stop api worker`.
2. **`.env`** (s'il est perdu) : le restaurer depuis kopia (`docker exec kopia kopia snapshot list /source`, puis `docker exec kopia kopia restore <id-instantané>/compose-stacks/collega/.env /backups/collega.env` et le recopier depuis le volume `/backups`). Ne jamais repartir de `.env.nas.example`.
3. **Base** : `docker compose up -d db`, puis
   `zcat /mnt/user/nas-backup/dumps/collega-db-1.sql.gz | docker exec -i collega-db-1 psql -U postgres -q -o /dev/null`
   (le dump supprime et recrée la base `collega` ; 2 erreurs attendues, voir plus haut). Si le disque est perdu, reprendre le dump depuis kopia `/dumps` ou R2.
4. **PDF** : `docker exec kopia kopia restore <id-instantané>/collega/pdfs /source/collega/pdfs` (les PDF ne servent qu'aux imports en cours et à l'admin ; les fiches sont en base).
5. **Relancer** : `docker compose up -d` (le service `migrate` rattrape le schéma), attendre `healthy` sur api et worker, vérifier `/health`.
6. **Après coup** : les imports qui étaient en cours restent en `processing`/`ocr_complete` → les arrêter depuis la console admin (Stop), l'utilisatrice relance.
