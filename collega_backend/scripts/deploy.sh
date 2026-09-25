#!/usr/bin/env bash
# Déploie le backend Collega sur le NAS (chantier 3).
#
#   ./scripts/deploy.sh [--force] [<sha>]      (défaut : HEAD)
#
# 1. refuse si collega_backend/ a des modifications non commitées (déploiement de HEAD)
#    ou si le commit n'est pas poussé ;
# 2. refuse si la CI (ci.yml) n'est pas verte sur ce commit — `--force` passe outre
#    (avertissement) ; `gh` doit voir le dépôt tistech0/collega ;
# 3. construit l'image linux/amd64 depuis un worktree du commit (jamais depuis
#    l'arbre de travail), la contrôle, la pousse sous tistech0/collega-backend:<sha> ;
# 4. sur le NAS : attend qu'aucun import ne tourne (30 min max), dump pg_dumpall,
#    installe le compose du commit, écrit IMAGE_TAG=<sha> dans le .env (cette seule
#    ligne ; sauvegarde avant), `docker compose pull` + `up -d` ;
# 5. attend api et worker `healthy` (3 min max), affiche les logs de migration et /health.
#
# Retour arrière (affiché en cas d'échec) : si une migration a changé le schéma, arrêter
# api/worker et restaurer d'abord le dump (docs/restore.md), PUIS ./scripts/deploy.sh <sha
# précédent> — l'image existante est réutilisée, jamais reconstruite.
set -euo pipefail

REPO=tistech0/collega
IMAGE=tistech0/collega-backend
NAS=nas
STACK_DIR=/mnt/user/appdata/compose-stacks/collega
BACKUP_DIR=/mnt/user/appdata/collega/backups
WAIT_IDLE_MAX_S=1800
WAIT_HEALTHY_MAX_S=180

die() { echo "❌ $*" >&2; exit 1; }
info() { echo "▶ $*"; }

FORCE=0
REF=HEAD
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    -*) die "option inconnue : $arg" ;;
    *) REF=$arg ;;
  esac
done

ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$ROOT"

FULL_SHA=$(git rev-parse --verify "$REF^{commit}" 2>/dev/null) || die "commit introuvable : $REF"
SHA=${FULL_SHA:0:7}

# ── 1. Arbre propre et commit poussé ───────────────────────────────────────────
if [[ "$FULL_SHA" == "$(git rev-parse HEAD)" && -n "$(git status --porcelain -- collega_backend)" ]]; then
  die "collega_backend/ a des modifications non commitées : commiter (et pousser) avant de déployer."
fi
git fetch -q origin
[[ -n "$(git branch -r --contains "$FULL_SHA")" ]] || die "le commit $SHA n'est sur aucune branche distante : git push d'abord."

# ── 2. CI verte ─────────────────────────────────────────────────────────────────
ci=$(gh run list --repo "$REPO" --commit "$FULL_SHA" --workflow ci.yml --json status,conclusion \
       -q '.[0] // empty | "\(.status)/\(.conclusion)"' 2>/dev/null) || ci="inaccessible"
[[ -z "$ci" ]] && ci="absente"
if [[ "$ci" != "completed/success" ]]; then
  msg="CI de $SHA : $ci (attendu completed/success)."
  [[ "$ci" == "inaccessible" ]] && msg+=" gh ne voit pas $REPO : gh auth login avec un compte qui y a accès."
  if [[ $FORCE -eq 1 ]]; then
    echo "⚠️  $msg Déploiement forcé (--force)." >&2
  else
    die "$msg Relancer avec --force pour passer outre."
  fi
fi

# ── 3. Image ────────────────────────────────────────────────────────────────────
WT=$(mktemp -d)
cleanup() { git worktree remove --force "$WT" >/dev/null 2>&1 || rm -rf "$WT"; }
trap cleanup EXIT
git worktree add -q --detach "$WT" "$FULL_SHA"

# Image déjà publiée (retour arrière, redéploiement) : on redéploie CETTE image, jamais une reconstruction.
if docker manifest inspect "$IMAGE:$SHA" >/dev/null 2>&1; then
  info "$IMAGE:$SHA existe déjà sur Docker Hub : réutilisée telle quelle"
  docker pull -q --platform linux/amd64 "$IMAGE:$SHA" >/dev/null
  PUSH=0
else
  info "Construction de $IMAGE:$SHA (linux/amd64)"
  docker build -q --platform linux/amd64 -t "$IMAGE:$SHA" "$WT/collega_backend" >/dev/null
  PUSH=1
fi

info "Contrôle de l'image"
expected=$(git show "$FULL_SHA:collega_backend/app/main.py" | shasum -a 256 | cut -d' ' -f1)
actual=$(docker run --rm --platform linux/amd64 --entrypoint sh "$IMAGE:$SHA" -c 'sha256sum /app/app/main.py' | cut -d' ' -f1)
[[ "$expected" == "$actual" ]] || die "app/main.py de l'image ne correspond pas au commit $SHA."
docker run --rm --platform linux/amd64 \
  -e ENVIRONMENT=development -e DATABASE_URL=postgresql+asyncpg://u:p@h/db -e REDIS_URL=redis://h:6379/0 \
  -e SECRET_KEY=controle-image -e CLAUDE_API_KEY=x -e ADMIN_PASSWORD=x -e REVENUECAT_WEBHOOK_SECRET=x \
  --entrypoint python "$IMAGE:$SHA" -c "import app.main, app.workers.settings" >/dev/null 2>&1 \
  || die "l'application ne s'importe pas dans l'image $SHA."

if [[ $PUSH -eq 1 ]]; then
  info "Envoi de $IMAGE:$SHA"
  docker push -q "$IMAGE:$SHA" >/dev/null
fi

# ── 4. NAS ──────────────────────────────────────────────────────────────────────
info "Compose du commit envoyé sur le NAS"
git show "$FULL_SHA:collega_backend/docker-compose.prod.yml" | ssh "$NAS" "cat > $STACK_DIR/docker-compose.yml.new"

# Dernière image déployée AVEC SUCCÈS (fichier écrit en fin de déploiement réussi ;
# repli sur IMAGE_TAG du .env pour le premier passage).
PREV=$(ssh "$NAS" "cat $STACK_DIR/.last_deployed 2>/dev/null || sed -n 's/^IMAGE_TAG=//p' $STACK_DIR/.env | tail -1")

# Le script distant reçoit ses paramètres en arguments ; il n'affiche aucun secret.
set +e
ssh "$NAS" bash -s -- "$SHA" "$STACK_DIR" "$BACKUP_DIR" "$WAIT_IDLE_MAX_S" "$WAIT_HEALTHY_MAX_S" <<'REMOTE'
set -euo pipefail
SHA=$1; STACK_DIR=$2; BACKUP_DIR=$3; WAIT_IDLE_MAX_S=$4; WAIT_HEALTHY_MAX_S=$5
cd "$STACK_DIR"
stamp=$(date +%Y%m%d-%H%M%S)

# Chaque compteur doit être lu avec certitude : une erreur (conteneur absent, NOAUTH,
# psql en échec) n'est JAMAIS prise pour « rien en cours ».
busy() {
  local scan inprog queued active
  scan=$(docker exec collega-redis-1 redis-cli --scan --pattern 'arq:in-progress:*') || return 1
  if grep -qiE 'NOAUTH|ERR|WRONGPASS' <<<"$scan"; then return 1; fi
  inprog=$(grep -c . <<<"$scan" || true)
  queued=$(docker exec collega-redis-1 redis-cli zcard arq:queue) || return 1
  [[ "$queued" =~ ^[0-9]+$ ]] || return 1
  active=$(docker exec collega-db-1 psql -U postgres -d collega -tAc \
    "SELECT count(*) FROM generation_jobs WHERE status IN ('pending','processing','ocr_complete')") || return 1
  [[ "$active" =~ ^[0-9]+$ ]] || return 1
  echo "$inprog $queued $active"
}
waited=0
while :; do
  if ! state=$(busy); then
    echo "❌ Impossible de vérifier qu'aucun import ne tourne (Redis ou Postgres illisible) : abandon, rien n'a été modifié." >&2
    exit 3
  fi
  read -r inprog queued active <<<"$state"
  [[ "$inprog" == 0 && "$queued" == 0 && "$active" == 0 ]] && break
  if (( waited >= WAIT_IDLE_MAX_S )); then
    echo "❌ Import toujours en cours après $((WAIT_IDLE_MAX_S / 60)) min (arq en cours=$inprog, file=$queued, jobs actifs=$active) : abandon, rien n'a été modifié." >&2
    exit 3
  fi
  echo "… import en cours (arq en cours=$inprog, file=$queued, jobs actifs=$active), nouvel essai dans 30 s"
  sleep 30; waited=$((waited + 30))
done

dump="$BACKUP_DIR/collega_pre_${SHA}_${stamp}.sql.gz"
echo "▶ Dump $dump"
# --clean : le dump supprime et recrée la base au rejeu (même format que les dumps de nuit, docs/restore.md).
docker exec collega-db-1 pg_dumpall --clean -U postgres | gzip > "$dump" \
  || { echo "❌ Dump en échec : abandon, rien n'a été modifié." >&2; exit 3; }
[[ $(stat -c %s "$dump") -gt 1024 ]] || { echo "❌ Dump vide : abandon, rien n'a été modifié." >&2; exit 3; }

echo "▶ Compose et IMAGE_TAG=$SHA"
# Validation AVANT toute modification (variables manquantes comme REDIS_PASSWORD comprises).
IMAGE_TAG=$SHA docker compose -f docker-compose.yml.new config -q \
  || { echo "❌ Compose du commit invalide avec ce .env : rien n'a été modifié." >&2; exit 3; }
cp .env ".env.bak-$stamp"
# Les sauvegardes du .env contiennent des secrets : on n'en garde que les 5 dernières.
find . -maxdepth 1 -name '.env.bak-*' -printf '%T@ %p\n' | sort -rn | tail -n +6 | cut -d' ' -f2- | xargs -r rm -f
if ! cmp -s docker-compose.yml docker-compose.yml.new; then
  cp docker-compose.yml "docker-compose.yml.bak-$stamp"
fi
mv docker-compose.yml.new docker-compose.yml
if grep -q '^IMAGE_TAG=' .env; then
  sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$SHA/" .env
else
  [[ -n "$(tail -c1 .env)" ]] && echo >> .env
  echo "IMAGE_TAG=$SHA" >> .env
fi
docker compose config -q

echo "▶ docker compose pull / up"
docker compose pull -q migrate api worker
if ! docker compose up -d --remove-orphans; then
  echo "--- migrate ---" >&2; docker logs --tail 30 collega-migrate-1 >&2 2>&1 || true
  exit 5
fi

echo "▶ Attente de api et worker healthy"
waited=0
while :; do
  api=$(docker inspect -f '{{.State.Health.Status}}' collega-api-1 2>/dev/null || echo absent)
  worker=$(docker inspect -f '{{.State.Health.Status}}' collega-worker-1 2>/dev/null || echo absent)
  [[ "$api" == healthy && "$worker" == healthy ]] && break
  if (( waited >= WAIT_HEALTHY_MAX_S )); then
    echo "❌ api=$api worker=$worker après $WAIT_HEALTHY_MAX_S s" >&2
    echo "--- migrate ---" >&2; docker logs --tail 30 collega-migrate-1 >&2 2>&1 || true
    echo "--- api ---" >&2; docker logs --tail 30 collega-api-1 >&2 2>&1 || true
    exit 5
  fi
  sleep 5; waited=$((waited + 5))
done
echo "--- migrate (exit $(docker inspect -f '{{.State.ExitCode}}' collega-migrate-1)) ---"
docker logs --tail 10 collega-migrate-1 2>&1
echo "--- /health ---"
docker exec collega-api-1 python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/health', timeout=5).read().decode())"
echo "$SHA" > .last_deployed
echo "DUMP=$dump"
REMOTE
rc=$?
set -e

if [[ $rc -ne 0 ]]; then
  echo >&2
  echo "❌ Déploiement de $SHA en échec (code $rc)." >&2
  if [[ $rc -eq 3 ]]; then
    echo "   Rien n'a été modifié sur le NAS." >&2
  else
    echo "   Retour arrière, dans cet ordre :" >&2
    echo "   1. si une migration a tourné (logs de collega-migrate-1) : ssh nas 'cd $STACK_DIR && docker compose stop api worker'," >&2
    echo "      puis restaurer le dump $BACKUP_DIR/collega_pre_${SHA}_*.sql.gz (docs/restore.md, « Restaurer la prod ») ;" >&2
    if [[ -n "$PREV" ]]; then
      echo "   2. ./collega_backend/scripts/deploy.sh --force $PREV (image existante, pas de reconstruction)." >&2
    else
      echo "   2. restaurer $STACK_DIR/docker-compose.yml.bak-* et .env.bak-* du NAS, puis docker compose up -d." >&2
    fi
  fi
  exit "$rc"
fi
prev_label=${PREV:-"latest (avant le chantier 3)"}
echo "✅ $IMAGE:$SHA déployée (précédente : $prev_label)."
