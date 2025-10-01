# ─────────────────────────────────────────────────────────────────────────────
# FILE: healthwatch.sh
# ─────────────────────────────────────────────────────────────────────────────
#!/bin/sh
set -eu

# timezone init (musl/BusyBox needs zoneinfo path)
LOCAL_TZ="${TZ:-}"
if [ -n "$LOCAL_TZ" ] && [ -e "/usr/share/zoneinfo/$LOCAL_TZ" ]; then
  ln -sf "/usr/share/zoneinfo/$LOCAL_TZ" /etc/localtime
  echo "$LOCAL_TZ" > /etc/timezone || true
  export TZ=":/usr/share/zoneinfo/$LOCAL_TZ"
else
  export TZ=":/etc/localtime"
fi


# config
WI="${WATCH_INCLUDE:-}"
WE="${WATCH_EXCLUDE:-}"
NH="${NOTIFY_HEALTHY:-true}"
EH="${EMOJI_HEALTHY:-✅}"
EU="${EMOJI_UNHEALTHY:-🚨}"
ES="${EMOJI_STARTING:-⏳}"
EX="${EMOJI_UNKNOWN:-❔}"
WEBHOOK="${DISCORD_WEBHOOK_URL:-}"

# environment identifier (why: multi-host stacks share one channel)
ID="${ALERT_TAG:-}"
[ -z "$ID" ] && ID="$(docker info --format '{{.Name}}' 2>/dev/null || true)"
[ -z "$ID" ] && ID="$(hostname 2>/dev/null || echo unknown)"

echo "[healthwatch] start include='${WI}' exclude='${WE}' notify_healthy=${NH} tz=${TZ} id=${ID}"
[ -z "$WEBHOOK" ] && echo "[healthwatch] WARN: DISCORD_WEBHOOK_URL is empty; no alerts will be sent."

docker events --format '{{json .}}' --filter type=container --filter event=health_status \
| while read -r line; do
    status=$(echo "$line" | jq -r '.status')
    name=$(echo "$line"   | jq -r '.Actor.Attributes.name')
    image=$(echo "$line"  | jq -r '.Actor.Attributes.image')
    health=$(echo "$status" | awk -F": " '{print $2}')

    # include/exclude (empty include => allow all)
    if [ -n "$WI" ] && ! printf '%s' "$name" | grep -Eq "$WI"; then
      echo "[healthwatch] skip $name (no include match)"; continue
    fi
    if [ -n "$WE" ] && printf '%s' "$name" | grep -Eq "$WE"; then
      echo "[healthwatch] skip $name (exclude match)"; continue
    fi

    # suppression
    if [ "$health" = "healthy" ] && [ "$NH" != "true" ]; then
      echo "[healthwatch] $name healthy -> suppressed"; continue
    fi

    case "$health" in
      healthy)   emoji="$EH"; title="Container Healthy Again" ;;
      unhealthy) emoji="$EU"; title="Container Unhealthy" ;;
      starting)  emoji="$ES"; title="Container Health Starting" ;;
      *)         emoji="$EX"; title="Container Health Update" ;;
    esac

    ts=$(date +"%H:%M:%S %d/%m/%Y  %Z")
    content=$(printf '**%s %s**\n**Environment:** **%s**\n**Container:** `%s`\n**Image:** `%s`\n**Status:** `%s`\n**Time:** %s' \
                     "$emoji" "$title" "$ID" "$name" "$image" "$health" "$ts")

    [ -z "$WEBHOOK" ] && continue
    echo "[healthwatch] notify $name ($health) -> Discord"
    curl -sS --fail -X POST -H 'Content-Type: application/json' \
      -d "$(jq -n --arg content "$content" '{content: $content}')" \
      "$WEBHOOK" >/dev/null || echo "[healthwatch] ERROR: Discord POST failed for $name"
  done
