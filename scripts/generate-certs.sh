#!/usr/bin/env bash
# Generates every self-signed TLS cert / keystore the stack needs.
# Safe to re-run: skips anything that already exists (pass --force to regenerate everything).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$ROOT_DIR/Installation-Guides/default-setup/backoffice-and-bykstack"
FORCE="${1:-}"

# shellcheck disable=SC1090
[ -f "$ROOT_DIR/.env" ] && source "$ROOT_DIR/.env"
CERT_SUBJECT_CN="${CERT_SUBJECT_CN:-localhost}"
SUBJECT="/C=EE/ST=Harju/L=Tallinn/O=Burokratt/OU=local-dev/CN=${CERT_SUBJECT_CN}"

gen_cert_pair() {
  local dir="$1"
  mkdir -p "$dir"
  if [ -f "$dir/cert.crt" ] && [ -f "$dir/key.key" ] && [ "$FORCE" != "--force" ]; then
    echo "  - $dir: cert.crt/key.key already present, skipping"
    return
  fi
  echo "  - $dir: generating cert.crt/key.key"
  openssl req -newkey rsa:4096 -x509 -sha256 -days 3980 -nodes \
    -out "$dir/cert.crt" -keyout "$dir/key.key" -subj "$SUBJECT" 2>/dev/null
}

echo "==> Service TLS certs"
for svc in ruuter dmapper chat-widget tim resql monitor customer-support; do
  gen_cert_pair "$BASE/$svc"
done

echo "==> Postgres (sql-db) TLS certs"
for db in users-db tim-db; do
  dir="$BASE/sql-db/$db"
  gen_cert_pair "$dir"
  # postgres:14.1 runs as uid/gid 999 and refuses to start if it can't read
  # (and refuses if group/world-readable) its TLS key — fix ownership/perms
  # via a throwaway container so this doesn't need host sudo.
  docker run --rm -v "$dir:/certs" alpine:3 sh -c \
    "chown 999:999 /certs/cert.crt /certs/key.key && chmod 600 /certs/key.key && chmod 644 /certs/cert.crt" \
    >/dev/null
done

echo "==> OpenSearch cluster certs (root CA, admin, node, client)"
OS_DIR="$BASE/opensearch/config"
if [ -f "$OS_DIR/root-ca.pem" ] && [ "$FORCE" != "--force" ]; then
  echo "  - $OS_DIR: already present, skipping"
else
  ( cd "$OS_DIR" && sh ./generate-certs.sh >/dev/null )
fi
echo "==> OpenSearch Dashboards TLS cert"
gen_cert_pair "$OS_DIR"

echo "==> TIM JWT signing keystore (jwtkeystore.jks)"
TIM_DIR="$BASE/tim"
if [ -f "$TIM_DIR/jwtkeystore.jks" ] && [ "$FORCE" != "--force" ]; then
  echo "  - $TIM_DIR: jwtkeystore.jks already present, skipping"
else
  # Uses the byk-tim image itself as a throwaway JDK — no local java/keytool needed.
  # Alias/passwords must match TIM's jwt-integration.signature.* env vars in docker-compose.yml.
  docker run --rm -v "$TIM_DIR:/out" --entrypoint keytool riaee/byk-tim:07 \
    -genkeypair -alias tim_jwt -keyalg RSA -keysize 2048 \
    -keystore /out/jwtkeystore.jks -validity 3650 -storetype JKS \
    -storepass safe_keystore_password -keypass safe_keystore_password \
    -dname "CN=byk.buerokratt.ee, OU=local-dev, O=Burokratt, L=Tallinn, ST=Harju, C=EE" \
    >/dev/null
fi

echo "All certs ready."
