#!/bin/bash
set -e

POSTGRES_DB="${POSTGRES_DB:-zabbix}"
POSTGRES_USER="${POSTGRES_USER:-zabbix}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:?POSTGRES_PASSWORD must be set}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_VERSION="${POSTGRES_VERSION:-16}"
PGDATA="${PGDATA:-/var/lib/postgresql/data}"

PG_BIN="/usr/lib/postgresql/${POSTGRES_VERSION}/bin"

echo "=========================================="
echo " Zabbix container"
echo " PostgreSQL version: ${POSTGRES_VERSION}"
echo " PostgreSQL DB:      ${POSTGRES_DB}"
echo " PostgreSQL user:    ${POSTGRES_USER}"
echo " PostgreSQL port:    ${POSTGRES_PORT}"
echo " PostgreSQL data:    ${PGDATA}"
echo "=========================================="

if [ ! -x "${PG_BIN}/initdb" ]; then
    echo "ERROR: PostgreSQL binaries not found:"
    echo "       ${PG_BIN}"
    exit 1
fi

mkdir -p "${PGDATA}"
chown -R postgres:postgres "${PGDATA}"

if [ ! -s "${PGDATA}/PG_VERSION" ]; then

    echo "Initializing PostgreSQL..."

    runuser -u postgres -- \
        "${PG_BIN}/initdb" \
        -D "${PGDATA}"

else

    echo "PostgreSQL database already initialized."

fi

echo "Starting PostgreSQL..."

if runuser -u postgres -- \
    "${PG_BIN}/pg_ctl" \
    -D "${PGDATA}" \
    status >/dev/null 2>&1
then

    echo "PostgreSQL is already running."

else

    runuser -u postgres -- \
        "${PG_BIN}/pg_ctl" \
        -D "${PGDATA}" \
        -l /var/log/postgresql/postgresql.log \
        start

fi

echo "Waiting for PostgreSQL..."

until runuser -u postgres -- \
    "${PG_BIN}/pg_isready" \
    -h 127.0.0.1 \
    -p "${POSTGRES_PORT}" \
    -q
do
    sleep 1
done

echo "PostgreSQL is ready."

if ! runuser -u postgres -- psql \
    -h 127.0.0.1 \
    -p "${POSTGRES_PORT}" \
    -tAc \
    "SELECT 1 FROM pg_roles WHERE rolname='${POSTGRES_USER}'" \
    | grep -q 1
then

    echo "Creating PostgreSQL user '${POSTGRES_USER}'"

    runuser -u postgres -- psql \
        -h 127.0.0.1 \
        -p "${POSTGRES_PORT}" \
        -v ON_ERROR_STOP=1 <<EOF
CREATE USER "${POSTGRES_USER}" WITH PASSWORD '${POSTGRES_PASSWORD}';
EOF

else

    echo "PostgreSQL user '${POSTGRES_USER}' already exists."

    runuser -u postgres -- psql \
        -h 127.0.0.1 \
        -p "${POSTGRES_PORT}" \
        -v ON_ERROR_STOP=1 <<EOF
ALTER USER "${POSTGRES_USER}" WITH PASSWORD '${POSTGRES_PASSWORD}';
EOF

fi

if ! runuser -u postgres -- psql \
    -h 127.0.0.1 \
    -p "${POSTGRES_PORT}" \
    -tAc \
    "SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DB}'" \
    | grep -q 1
then

    echo "Creating database '${POSTGRES_DB}'"

    runuser -u postgres -- createdb \
        -h 127.0.0.1 \
        -p "${POSTGRES_PORT}" \
        -O "${POSTGRES_USER}" \
        "${POSTGRES_DB}"

else

    echo "Database '${POSTGRES_DB}' already exists."

fi

runuser -u postgres -- psql \
    -h 127.0.0.1 \
    -p "${POSTGRES_PORT}" \
    -v ON_ERROR_STOP=1 \
    -c "ALTER DATABASE \"${POSTGRES_DB}\" OWNER TO \"${POSTGRES_USER}\";"

echo "Checking Zabbix database schema..."

if ! runuser -u postgres -- psql \
    -h 127.0.0.1 \
    -p "${POSTGRES_PORT}" \
    -d "${POSTGRES_DB}" \
    -tAc \
    "SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='users'" \
    | grep -q 1
then

    echo "Initializing Zabbix database schema..."

    zcat /usr/share/zabbix/sql-scripts/postgresql/server.sql.gz \
        | runuser -u "${POSTGRES_USER}" -- psql \
            -h 127.0.0.1 \
            -p "${POSTGRES_PORT}" \
            -v ON_ERROR_STOP=1 \
            "${POSTGRES_DB}"

    echo "Zabbix database schema initialized."

else

    echo "Zabbix database schema already exists."

fi

cat > /etc/zabbix/zabbix_server.conf <<EOF
DBHost=127.0.0.1
DBPort=${POSTGRES_PORT}
DBName=${POSTGRES_DB}
DBUser=${POSTGRES_USER}
DBPassword=${POSTGRES_PASSWORD}

LogType=console

CacheSize=128M
ValueCacheSize=64M
TrendCacheSize=128M
EOF

echo "Zabbix configuration generated."

echo "Starting supervisord..."

exec /usr/bin/supervisord \
    -n \
    -c /etc/supervisor/supervisord.conf