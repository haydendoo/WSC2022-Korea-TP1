#!/usr/bin/env bash
# Sanity-checks the built server binary: --help works, and GET / returns
# HTTP 200 when run with a local config file (no AWS dependencies
# reachable - handleHealth doesn't touch DynamoDB). This is a smoke test
# for the practice binary itself, not a test of any deployed
# infrastructure.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"

"${REPO_ROOT}/scripts/build.sh"

WORK_DIR="$(mktemp -d)"
trap 'kill "${SERVER_PID:-0}" 2>/dev/null || true; rm -rf "${WORK_DIR}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

"${DIST_DIR}/server" --help >/dev/null 2>&1 || fail "server --help exited non-zero"
echo "OK: server --help"

cat > "${WORK_DIR}/server.json" <<'EOF'
{"Table":"unicorn","Region":"ap-southeast-1","Port":0}
EOF

export AWS_ACCESS_KEY_ID="local"
export AWS_SECRET_ACCESS_KEY="local"

"${DIST_DIR}/server" --config "${WORK_DIR}/server.json" --port 18190 >"${WORK_DIR}/server.log" 2>&1 &
SERVER_PID=$!

code=""
for _ in $(seq 1 20); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:18190/" || true)"
  [[ "${code}" == "200" ]] && break
  sleep 0.25
done

kill "${SERVER_PID}" 2>/dev/null || true
wait "${SERVER_PID}" 2>/dev/null || true

[[ "${code}" == "200" ]] || { cat "${WORK_DIR}/server.log" >&2; fail "GET / returned '${code}', expected 200"; }
echo "OK: server GET / -> 200"

echo "==> all checks passed"
