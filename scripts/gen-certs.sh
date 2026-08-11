#!/usr/bin/env bash
# Generates the shared practice IoT device identity for the Day 1
# GameDay-simulator scenario: a self-signed CA plus a device certificate
# signed by it, using the exact file names the spec requires (Service
# Details / IoT core):
#
#   1. GameDayThing.cert.pem
#   2. GameDayThing.private.key
#   3. root-CA.crt
#
# These are intentionally SHARED, non-sensitive practice artifacts, not a
# production secret: every participant registers the SAME certificate
# into their own AWS IoT Core account (the practice equivalent of the
# vendor handing out one device identity to every competitor), and the
# companion gameday-simulator scenario uses this exact key pair to act as
# the "IoT device" publishing to whichever participant's endpoint it is
# pointed at. Regenerating these files invalidates the copy embedded in
# gameday-simulator - re-copy certs/ there after running this script.
#
# root-CA.crt here is this practice kit's OWN CA certificate (not AWS's
# production Amazon Root CA) - fine for this purpose, since the CA cert's
# only required role in the spec is "one of the three files uploaded to
# S3"; the actual TLS trust anchor used to validate AWS IoT's server
# certificate is the operating system's/Go's standard trust store, not
# this file.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERTS_DIR="${REPO_ROOT}/certs"
mkdir -p "${CERTS_DIR}"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "==> generating CA key + self-signed CA certificate (root-CA.crt)"
openssl ecparam -name prime256v1 -genkey -noout -out "${WORK_DIR}/ca.key"
openssl req -x509 -new -nodes \
  -key "${WORK_DIR}/ca.key" \
  -sha256 -days 3650 \
  -subj "/O=Unicorn GameDay/OU=WSC2022 TP53 Day 1 Practice Kit/CN=Unicorn GameDay Practice Root CA" \
  -out "${CERTS_DIR}/root-CA.crt"

echo "==> generating GameDayThing device key + CSR"
openssl ecparam -name prime256v1 -genkey -noout -out "${CERTS_DIR}/GameDayThing.private.key"
openssl req -new \
  -key "${CERTS_DIR}/GameDayThing.private.key" \
  -subj "/O=Unicorn GameDay/OU=WSC2022 TP53 Day 1 Practice Kit/CN=GameDayThing" \
  -out "${WORK_DIR}/device.csr"

echo "==> signing GameDayThing.cert.pem with the practice CA"
openssl x509 -req \
  -in "${WORK_DIR}/device.csr" \
  -CA "${CERTS_DIR}/root-CA.crt" -CAkey "${WORK_DIR}/ca.key" -CAcreateserial \
  -days 3650 -sha256 \
  -out "${CERTS_DIR}/GameDayThing.cert.pem"

chmod 600 "${CERTS_DIR}/GameDayThing.private.key"
chmod 644 "${CERTS_DIR}/GameDayThing.cert.pem" "${CERTS_DIR}/root-CA.crt"

echo "==> done. Generated:"
ls -la "${CERTS_DIR}"
echo
echo "==> reminder: re-copy certs/ into"
echo "    ~/projects/gameday-simulator/internal/scenarios/wsc2022koreaday1/dist/certs/"
echo "    if you regenerated these files."
