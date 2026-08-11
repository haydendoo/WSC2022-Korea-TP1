#!/usr/bin/env bash
# Builds the server binary for linux/amd64 (the target platform per the
# spec: "x86 statically linked, unstripped ELF executable").
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"

mkdir -p "${DIST_DIR}"

echo "==> building server"
(
  cd "${REPO_ROOT}/services/server"
  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o "${DIST_DIR}/server" .
)
echo "==> built ${DIST_DIR}/server"
