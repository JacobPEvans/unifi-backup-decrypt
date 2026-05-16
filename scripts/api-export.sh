#!/usr/bin/env bash
#
# api-export.sh — Export UniFi Network controller config as JSON via the API.
#
# Alternative to backup-file decryption for UniFi OS appliances (UDW, UDM, UDM-Pro,
# Cloud Gateway) whose .unifi backup format is not decryptable by any community tool.
#
# Usage:
#   UNIFI_USER=admin UNIFI_PASS='...' ./api-export.sh \
#     --host https://10.0.1.1 --site default --output-dir ./exports
#
# Requires: curl, jq. Self-signed certs accepted (controller is on internal network).

set -euo pipefail

HOST=""
SITE="default"
OUTPUT_DIR="./exports"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)       HOST="$2"; shift 2 ;;
    --site)       SITE="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help)
      grep -E '^# ' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

: "${HOST:?--host required (e.g. https://10.0.1.1)}"
: "${UNIFI_USER:?env UNIFI_USER required}"
: "${UNIFI_PASS:?env UNIFI_PASS required}"

mkdir -p "$OUTPUT_DIR"
COOKIE_JAR=$(mktemp); trap 'rm -f "$COOKIE_JAR"' EXIT

login_response=$(curl -ksS -c "$COOKIE_JAR" -X POST \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg u "$UNIFI_USER" --arg p "$UNIFI_PASS" '{username:$u,password:$p}')" \
  -D - -o /dev/null \
  "${HOST%/}/api/auth/login")

CSRF=$(printf '%s' "$login_response" | awk 'BEGIN{IGNORECASE=1} /^x-csrf-token:/ {sub(/\r$/,"",$2); print $2; exit}')
[[ -z "$CSRF" ]] && { echo "Login failed: no CSRF token in response" >&2; exit 1; }

api_get() {
  curl -ksS -b "$COOKIE_JAR" -H "X-CSRF-Token: $CSRF" \
    "${HOST%/}/proxy/network/api/s/${SITE}/$1" | jq -S .
}

declare -A endpoints=(
  [networks.json]="rest/networkconf"
  [firewall-rules.json]="rest/firewallrule"
  [devices.json]="stat/device"
  [wireless.json]="rest/wlanconf"
  [wan-config.json]="get/setting"
)

for filename in "${!endpoints[@]}"; do
  endpoint="${endpoints[$filename]}"
  echo "→ $endpoint  ->  $OUTPUT_DIR/$filename"
  api_get "$endpoint" > "$OUTPUT_DIR/$filename"
done

echo "Done. Wrote ${#endpoints[@]} files to $OUTPUT_DIR/"
