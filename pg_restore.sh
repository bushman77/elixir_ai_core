#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ===== Editable defaults (or override via env) ================================
PG_SUPERUSER="${PG_SUPERUSER:-postgres}"
PG_SUPERPASS="${PG_SUPERPASS:-postgres}"   # change me if you can
APP_DB="${APP_DB:-elixir_ai_core}"
APP_USER="${APP_USER:-elixir_core}"
APP_PASS="${APP_PASS:-elixir_core_pass}"   # change me if you can
DO_APP_DB="${DO_APP_DB:-1}"                # 1=create app db/user, 0=skip
DO_PGVECTOR="${DO_PGVECTOR:-0}"            # 1=try to build pgvector from source
USE_SERVICE="${USE_SERVICE:-1}"            # 1=use runit service if available
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
PGDATA="${PGDATA:-$PREFIX/var/lib/postgresql}"
PGLOGDIR="${PGLOGDIR:-$PREFIX/var/log}"
PGLOG="${PGLOG:-$PGLOGDIR/postgresql.log}"
# ============================================================================

echo "==> Installing packages (postgresql, postgresql-contrib, termux-services)…"
yes | pkg install postgresql postgresql-contrib || true
yes | pkg install termux-services || true
mkdir -p "$PGDATA" "$PGLOGDIR"

init_if_needed() {
  if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "==> initdb (new data directory at $PGDATA)…"
    initdb -D "$PGDATA" -U "$PG_SUPERUSER" >/dev/null
  else
    echo "==> PGDATA already initialized."
  fi
}

ensure_configs() {
  local CONF="$PGDATA/postgresql.conf"
  local HBA="$PGDATA/pg_hba.conf"

  # listen on localhost
  if ! grep -q "^listen_addresses" "$CONF" 2>/dev/null; then
    echo "listen_addresses = '127.0.0.1'" >> "$CONF"
  else
    sed -i "s/^#\?listen_addresses.*/listen_addresses = '127.0.0.1'/" "$CONF"
  fi

  # ensure md5 auth for local + localhost
  if ! grep -q "^[[:space:]]*local[[:space:]]\+all[[:space:]]\+all[[:space:]]\+md5" "$HBA"; then
    sed -i 's/^[[:space:]]*local[[:space:]]\+all[[:space:]]\+all.*/# &/' "$HBA" || true
    printf "local   all             all                                     md5\n" >> "$HBA"
  fi
  if ! grep -q "^[[:space:]]*host[[:space:]]\+all[[:space:]]\+all[[:space:]]\+127.0.0.1\/32[[:space:]]\+md5" "$HBA"; then
    sed -i 's/^[[:space:]]*host[[:space:]]\+all[[:space:]]\+all[[:space:]]\+127\.0\.0\.1\/32.*/# &/' "$HBA" || true
    printf "host    all             all             127.0.0.1/32            md5\n" >> "$HBA"
  fi
}

start_service() {
  if [ "$USE_SERVICE" -eq 1 ] && command -v sv >/dev/null 2>&1; then
    # termux-services helper
    if command -v sv-enable >/dev/null 2>&1; then
      sv-enable postgresql || true
    fi
    echo "==> starting runit service: postgresql"
    sv up postgresql || true
    # fall back to pg_ctl if service didn’t come up
    sleep 1
    if ! pg_isready -h 127.0.0.1 >/dev/null 2>&1; then
      echo "==> service not ready; starting with pg_ctl…"
      pg_ctl -D "$PGDATA" -l "$PGLOG" start
    fi
  else
    echo "==> starting with pg_ctl…"
    pg_ctl -D "$PGDATA" -l "$PGLOG" start || true
  fi
}

restart_server() {
  echo "==> restarting PostgreSQL to apply configs…"
  pg_ctl -D "$PGDATA" -m fast restart || { echo "restart failed; trying start"; pg_ctl -D "$PGDATA" -l "$PGLOG" start; }
}

set_superuser_password() {
  echo "==> setting password for superuser '$PG_SUPERUSER'…"
  PGPASSWORD="" psql -h 127.0.0.1 -U "$PG_SUPERUSER" -d postgres -c "ALTER USER $PG_SUPERUSER WITH PASSWORD '$PG_SUPERPASS';" \
    || PGPASSWORD="$PG_SUPERPASS" psql -h 127.0.0.1 -U "$PG_SUPERUSER" -d postgres -c "SELECT 'password confirmed' as ok;"
}

create_app_db_user() {
  if [ "$DO_APP_DB" -eq 1 ]; then
    echo "==> creating app user/db if missing…"
    PGPASSWORD="$PG_SUPERPASS" psql -h 127.0.0.1 -U "$PG_SUPERUSER" -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$APP_USER') THEN
    CREATE ROLE $APP_USER LOGIN PASSWORD '$APP_PASS';
  END IF;
END\$\$;
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$APP_DB') THEN
    CREATE DATABASE $APP_DB OWNER $APP_USER;
  END IF;
END\$\$;
GRANT ALL PRIVILEGES ON DATABASE $APP_DB TO $APP_USER;
SQL
  fi
}

enable_pgvector_if_possible() {
  if [ "$DO_PGVECTOR" -eq 1 ]; then
    echo "==> attempting pgvector install (source build)…"
    if command -v pg_config >/dev/null 2>&1; then
      TMPDIR="$(mktemp -d)"
      cd "$TMPDIR"
      # build requires clang, make, git
      yes | pkg install clang make git || true
      git clone --depth 1 https://github.com/pgvector/pgvector.git
      cd pgvector
      make
      make install
      cd ~
      rm -rf "$TMPDIR"
      echo "==> enabling extension in $APP_DB (if created)…"
      PGPASSWORD="$PG_SUPERPASS" psql -h 127.0.0.1 -U "$PG_SUPERUSER" -d "$APP_DB" -c "CREATE EXTENSION IF NOT EXISTS vector;" || true
    else
      echo "!! pg_config not found; skipping pgvector."
    fi
  fi
}

write_pgpass() {
  local PGPASSFILE="$HOME/.pgpass"
  echo "==> writing ~/.pgpass for convenience…"
  umask 077
  {
    echo "127.0.0.1:5432:*:$PG_SUPERUSER:$PG_SUPERPASS"
    [ "$DO_APP_DB" -eq 1 ] && echo "127.0.0.1:5432:$APP_DB:$APP_USER:$APP_PASS"
  } > "$PGPASSFILE"
  chmod 600 "$PGPASSFILE"
}

conninfo_check() {
  echo "==> connection check…"
  PGPASSWORD="$PG_SUPERPASS" psql -h 127.0.0.1 -U "$PG_SUPERUSER" -d postgres -c '\conninfo' || true
  if [ "$DO_APP_DB" -eq 1 ]; then
    PGPASSWORD="$APP_PASS" psql -h 127.0.0.1 -U "$APP_USER" -d "$APP_DB" -c 'SELECT current_user, current_database();' || true
  fi
}

# === Run steps ================================================================
init_if_needed
ensure_configs
start_service
restart_server
set_superuser_password
create_app_db_user
enable_pgvector_if_possible
write_pgpass
conninfo_check

echo "==> Done. Re-run this script anytime after a reboot or package reset."

