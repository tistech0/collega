#!/bin/bash
# collega-health — surveille l'API Collega chaque minute (User Scripts, cron « * * * * * »).
#
# Deux chemins, sondés sur GET /health (qui vérifie aussi Postgres et Redis) :
#   - LAN    : via Nginx Proxy Manager (IP LAN du NAS), le chemin de l'app à la maison ;
#   - public : via Cloudflare (tunnel + Access, service token), le chemin hors LAN.
#
# Alerte Telegram (notify Unraid) DÈS qu'un chemin tombe — un 2e essai 10 s plus tard
# évite l'alerte sur un redémarrage de quelques secondes — puis UN message au retour.
# Rien entre les deux, et rien dans le récap du matin.
#
# Source versionnée : collega_backend/ops/nas/collega-health.sh (copiée dans
# /boot/config/plugins/user.scripts/scripts/collega-health/script).
# Secrets : /boot/config/secrets/collega_cf_access (CF_ACCESS_CLIENT_ID / _SECRET).

HOST=collegatest.matthislesur.com
LAN_IP=192.168.1.10
STATE_DIR=/tmp/collega-health
SECRETS=/boot/config/secrets/collega_cf_access
RETRY_DELAY=10

notify() { /usr/local/emhttp/webGui/scripts/notify -e "Collega" -s "$1" -d "$2" -i "$3" >/dev/null 2>&1; }

mkdir -p "$STATE_DIR"

# Imprime « code|détail » pour un chemin (lan|public).
probe() {
  local ip out code body
  if [ "$1" = lan ]; then
    ip=$LAN_IP
    out=$(curl -s --max-time 10 --resolve "$HOST:443:$ip" -w '\n%{http_code}' "https://$HOST/health")
  else
    ip=$(dig +short +time=3 +tries=1 @1.1.1.1 "$HOST" | grep -E '^[0-9.]+$' | head -1)
    [ -z "$ip" ] && { echo "000|DNS public injoignable"; return; }
    # Le service token passe par stdin (-K -) : jamais en argument visible dans `ps`.
    out=$(tr -d '\r' < "$SECRETS" | sed -n \
            -e 's/^CF_ACCESS_CLIENT_ID=\(.*\)$/header = "CF-Access-Client-Id: \1"/p' \
            -e 's/^CF_ACCESS_CLIENT_SECRET=\(.*\)$/header = "CF-Access-Client-Secret: \1"/p' |
          curl -s -K - --max-time 10 --resolve "$HOST:443:$ip" -w '\n%{http_code}' "https://$HOST/health")
  fi
  code=${out##*$'\n'}
  body=${out%$'\n'*}
  case "$code" in
    200) echo "200|ok" ;;
    503) echo "503|$(echo "$body" | grep -o '"db":"[a-z]*","redis":"[a-z]*"' | tr -d '"')" ;;
    302) echo "302|bloqué par Cloudflare Access (service token refusé ?)" ;;
    000) echo "000|pas de réponse (API, NPM ou tunnel arrêté ?)" ;;
    *)   echo "$code|réponse inattendue" ;;
  esac
}

check() {
  local r
  r=$(probe "$1")
  if [ "${r%%|*}" != 200 ]; then
    sleep "$RETRY_DELAY"
    r=$(probe "$1")
  fi
  echo "$r"
}

label() { [ "$1" = lan ] && echo "LAN (NPM)" || echo "public (Cloudflare)"; }

down=""; up=""
for path in lan public; do
  r=$(check "$path")
  code=${r%%|*}; detail=${r#*|}
  prev=$(cat "$STATE_DIR/$path" 2>/dev/null || echo ok)
  if [ "$code" = 200 ]; then
    [ "$prev" != ok ] && up+="$(label "$path") rétabli. "
    echo ok > "$STATE_DIR/$path"
  else
    [ "$prev" = ok ] && down+="$(label "$path") : HTTP $code, $detail. "
    echo ko > "$STATE_DIR/$path"
  fi
  echo "$(date '+%F %T') $path $code $detail"
done

[ -n "$down" ] && notify "Collega : API en panne" "${down}Logs : docker logs collega-api-1" "alert"
# Niveau alert aussi pour le retour : l'agent Telegram du NAS ne pousse tout de suite
# que les `alert` et met `normal`/`warning` en file pour le récap de 08:00.
[ -n "$up" ] && notify "Collega : API rétablie" "$up" "alert"
exit 0
