#!/usr/bin/env bash
#
# cloud-export.sh — Export UniFi config snapshot via the UI Cloud Site Manager API.
#
# Auth: X-API-KEY header against https://api.ui.com/ea/. Get a key from
# https://account.ui.com/ → Site Manager → API Keys.
#
# Use this when you have a UI cloud API key but not a local controller admin
# user/password — common for UniFi OS appliances (UDW, UDM, UDM-Pro, Cloud
# Gateway, etc.) where the easiest credential to obtain is a cloud API key.
#
# Cloud API gives device inventory, host details (incl. reportedState), and
# ISP/WAN telemetry. It does NOT return VLAN/firewall/WLAN config — for those,
# use scripts/api-export.sh with local controller credentials.
#
# Usage:
#   UNIFI_API_KEY='...' ./cloud-export.sh --output-dir ./exports
#
# Requires: curl, jq.

set -euo pipefail

OUTPUT_DIR="./exports"
BASE_URL="https://api.ui.com/ea"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --base-url)   BASE_URL="$2"; shift 2 ;;
    -h|--help)
      grep -E '^# ' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

: "${UNIFI_API_KEY:?env UNIFI_API_KEY required}"
mkdir -p "$OUTPUT_DIR"

api_get() {
  curl -sS -H "X-API-KEY: $UNIFI_API_KEY" -H 'Accept: application/json' \
    "${BASE_URL%/}/$1" | jq -S .
}

echo "→ sites              -> $OUTPUT_DIR/sites.json"
api_get "sites" > "$OUTPUT_DIR/sites.json"

echo "→ hosts              -> $OUTPUT_DIR/hosts.json"
api_get "hosts" > "$OUTPUT_DIR/hosts.json"

mapfile -t HOST_IDS < <(jq -r '.data[].id' "$OUTPUT_DIR/hosts.json")

echo "→ host detail        -> $OUTPUT_DIR/host-details.json"
jq -n --argjson hosts '[]' '$hosts' > "$OUTPUT_DIR/host-details.json"
for id in "${HOST_IDS[@]}"; do
  detail=$(api_get "hosts/$id")
  tmp=$(mktemp)
  jq --argjson new "$detail" '. + [$new]' "$OUTPUT_DIR/host-details.json" > "$tmp"
  mv "$tmp" "$OUTPUT_DIR/host-details.json"
done

echo "→ devices            -> $OUTPUT_DIR/devices.json"
query=""
for id in "${HOST_IDS[@]}"; do query+="hostIds[]=${id}&"; done
api_get "devices?${query%&}" > "$OUTPUT_DIR/devices.json"

echo "→ isp-metrics (5m)   -> $OUTPUT_DIR/isp-metrics.json"
api_get "isp-metrics/5m" > "$OUTPUT_DIR/isp-metrics.json"

echo "→ sd-wan-configs     -> $OUTPUT_DIR/sd-wan-configs.json"
api_get "sd-wan-configs" > "$OUTPUT_DIR/sd-wan-configs.json"

echo "Done. Wrote 6 files to $OUTPUT_DIR/"
