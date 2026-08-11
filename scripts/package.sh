#!/usr/bin/env bash
# Assembles dist/ - the package handed to participants: the server
# binary, its example config, database/table.json, and the three shared
# practice IoT certificate/key files (certs/). This mirrors what the spec
# calls "the Readme file of this game event" that bundles the binary and
# certificate downloads.
#
# Also builds a local Docker image for the service when Docker is
# available (not part of dist/ itself - dist/ matches what the spec
# describes participants receiving, which does not include container
# images).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"

"${REPO_ROOT}/scripts/build.sh"

echo "==> assembling dist/"
mkdir -p "${DIST_DIR}/config" "${DIST_DIR}/database" "${DIST_DIR}/certs"

cp "${REPO_ROOT}/config/server.example.json" "${DIST_DIR}/config/server.example.json"
cp "${REPO_ROOT}/database/table.json" "${DIST_DIR}/database/table.json"
cp "${REPO_ROOT}/certs/root-CA.crt" "${DIST_DIR}/certs/root-CA.crt"
cp "${REPO_ROOT}/certs/GameDayThing.cert.pem" "${DIST_DIR}/certs/GameDayThing.cert.pem"
cp "${REPO_ROOT}/certs/GameDayThing.private.key" "${DIST_DIR}/certs/GameDayThing.private.key"
chmod +x "${DIST_DIR}/server"

cat > "${DIST_DIR}/README.md" <<'EOF'
# Unicorn Service - Day 1 Distribution Package

This is what you were given at the start of the competition: the
`server` binary, its example configuration, the DynamoDB table
definition, and the three IoT certificate/key files. See the Day 1 Test
Project PDF for the full task description.

## Contents

- `server` - x86-64 Linux binary. Run with `--help` for usage. Reads
  `--table` / `--region` / `--port` from flags or environment variables,
  optionally defaulted from a local JSON file (`--config`) shaped like
  `config/server.example.json`.
- `config/server.example.json` - the configuration shape the service
  expects.
- `database/table.json` - the DynamoDB `CreateTable` request for the
  `unicorn` table (partition key `id`, sort key `sentiment`). Apply it
  yourself, e.g.:

  ```
  aws dynamodb create-table --cli-input-json file://database/table.json
  ```

- `certs/root-CA.crt`, `certs/GameDayThing.cert.pem`,
  `certs/GameDayThing.private.key` - upload these three files, with
  these exact names, to the S3 bucket you create (Re-platform schedule
  Phase I). Then register `GameDayThing.cert.pem` with AWS IoT Core
  (`aws iot register-certificate-without-ca --certificate-pem
  file://certs/GameDayThing.cert.pem --status ACTIVE` is the simplest
  path), create an IoT Thing, attach the certificate, and attach an IoT
  policy that allows `iot:Connect`, `iot:Publish`, `iot:Subscribe`, and
  `iot:Receive`. The practice IoT devices publish to topic
  `sdk/test/Python` using this exact certificate/key pair, shared across
  every participant.
EOF

echo "==> dist/ ready:"
find "${DIST_DIR}" -maxdepth 2 -type f | sort

if command -v docker >/dev/null 2>&1; then
  echo "==> building docker image"
  docker build -t unicorn-gameday/server:latest "${REPO_ROOT}/services/server"
  echo "==> built image unicorn-gameday/server:latest"
else
  echo "==> docker not found, skipping image build (dist/ is still ready)"
fi
