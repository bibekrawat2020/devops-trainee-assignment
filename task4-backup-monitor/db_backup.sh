#!/bin/bash
set -uo pipefail

DB_CONTAINER="task2-docker-setup-db-1"
DB_USER="appuser"
DB_NAME="appdb"
BACKUP_DIR="/var/backups/db"

TIMESTAMP=$(date +%Y%m%d)
RAW_DUMP="${BACKUP_DIR}/db_backup_${TIMESTAMP}.sql"
ARCHIVE_FILE="${BACKUP_DIR}/db_backup_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting backup of '${DB_NAME}' from container '${DB_CONTAINER}'..."

if [ "$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER" 2>/dev/null)" != "true" ]; then
    echo "[ERROR] Container '${DB_CONTAINER}' is not running. Backup aborted." >&2
    exit 1
fi

if ! docker exec -t "$DB_CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" > "$RAW_DUMP" 2>/tmp/db_backup_error.log; then
    echo "[ERROR] pg_dump failed. See /tmp/db_backup_error.log" >&2
    cat /tmp/db_backup_error.log >&2
    rm -f "$RAW_DUMP"
    exit 1
fi

gzip -f "$RAW_DUMP"

if [ -f "$ARCHIVE_FILE" ]; then
    SIZE=$(du -h "$ARCHIVE_FILE" | cut -f1)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup complete: ${ARCHIVE_FILE} (${SIZE})"
else
    echo "[ERROR] Expected archive file not found after gzip: ${ARCHIVE_FILE}" >&2
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup job finished successfully."
exit 0
