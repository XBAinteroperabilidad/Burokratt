#!/usr/bin/env bash
# One-time seeding for the `byk` (users) database: schema migration + the
# bot_institution_id row RESQL/backoffice expect. TIM's own database sets
# itself up automatically on first boot, so it needs no seeding here.
# Safe to re-run.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1090
[ -f "$ROOT_DIR/.env" ] && source "$ROOT_DIR/.env"
BOT_INSTITUTION_ID="${BOT_INSTITUTION_ID:-test}"

echo "==> Waiting for users-db to accept connections"
for i in $(seq 1 30); do
  if docker exec users-db pg_isready -U byk -d byk >/dev/null 2>&1; then
    break
  fi
  [ "$i" -eq 30 ] && { echo "users-db never became ready" >&2; exit 1; }
  sleep 2
done

echo "==> Running liquibase migration on byk database"
docker run --rm --network=bykstack riaee/byk-users-db:liquibase20220615 \
  liquibase --url="jdbc:postgresql://users-db:5432/byk?user=byk" --password=01234 \
  --changelog-file=/master.yml update

echo "==> Enabling hstore extension + seeding configuration"
docker run --rm -i --network=bykstack -e PGPASSWORD=01234 postgres:14.1 \
  psql -h users-db -p 5432 -U byk -d byk -v ON_ERROR_STOP=1 <<SQL
CREATE EXTENSION IF NOT EXISTS hstore;
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM configuration WHERE key = 'bot_institution_id') THEN
    INSERT INTO configuration(key, value) VALUES ('bot_institution_id', '${BOT_INSTITUTION_ID}');
  END IF;
END \$\$;
SQL

echo "Database seeded."
