#!/usr/bin/env bash
set -euo pipefail

# Derive repo info and token from git remote
REMOTE_URL=$(git remote get-url origin)
OWNER=$(printf "%s" "$REMOTE_URL" | sed -n 's#.*github.com/\([^/]*\)/.*#\1#p')
REPO=$(printf "%s" "$REMOTE_URL" | sed -n 's#.*github.com/[^/]*/\([^/.]*\).*#\1#p')
TOKEN=$(printf "%s" "$REMOTE_URL" | sed -n 's#https://x-access-token:\([^@]*\)@github.com/.*#\1#p')

if [ -z "${OWNER:-}" ] || [ -z "${REPO:-}" ]; then
  echo "Failed to parse owner/repo from remote URL" >&2
  exit 1
fi

if [ -z "${TOKEN:-}" ]; then
  echo "GitHub token not found in remote URL. Aborting to avoid unauthenticated calls." >&2
  exit 1
fi

API="https://api.github.com/repos/${OWNER}/${REPO}/issues"

create_issue() {
  local title="$1"
  local body="$2"
  # Minimal JSON assembly (single-line body)
  local json safe_title safe_body
  safe_title=${title//"/\\"}
  safe_body=${body//"/\\"}
  json=$(printf '{"title":"%s","body":"%s"}' "$safe_title" "$safe_body")
  curl -sS -X POST \
    -H "Authorization: token ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -d "$json" "$API" | grep -m1 '"html_url"' | sed -E 's/.*"html_url"\s*:\s*"([^"]+)".*/\1/'
}

echo "Creating FW issues on ${OWNER}/${REPO}..." >&2

create_issue "[FW][P0] E-Stop: single vs dual-channel logic and emergency shutdown actions" \
  "Fix single-channel logic in hal_estop (reset/update) and implement safety_manager_emergency_stop to cut relays and broadcast STOP; align pin macros across hal_common/hal_estop."

create_issue "[FW][P0] Modbus frame validation and buffer safety" \
  "Enforce byte count vs quantity, strict bounds checks, exception parsing; protect partial TX/RX and buffer limits in communication_manager and hal_rs485."

create_issue "[FW][P1] RS485 robustness and echo suppression" \
  "Implement echo suppression timing and looped write/read for partial IO; make settle-time dependent on baud and config."

create_issue "[FW][P1] Module scan unification and registry thread-safety" \
  "Unify scan ranges (1..247) with debounce/TTL; add mutex protection in module_registry; map module types via register then fallback by address."

create_issue "[FW][P2] ADR/Docs, tests, telemetry, HAL cleanup, config schema" \
  "Add ADRs (Comm, E-Stop, pin map); unit/integration tests; export performance metrics; mark/remove HAL Modbus stubs; add config schema versioning + checksum/backup."

echo "Done." >&2

