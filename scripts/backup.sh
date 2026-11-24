#!/bin/sh
# 在群晖「控制面板 -> 任务计划 -> 用户定义的脚本」中以 root 运行。
# 建议每天执行一次，保留 KEEP_DAYS 天。
set -eu

CONTAINER="kodi-mariadb"
ROOT_PASSWORD="CHANGE_ME"   # 与 .env 中的 MARIADB_ROOT_PASSWORD 一致
BACKUP_DIR="/volume1/backup/kodi"
KEEP_DAYS=30

mkdir -p "$BACKUP_DIR"
STAMP=$(date +%Y%m%d-%H%M)

docker exec -e MYSQL_PWD="$ROOT_PASSWORD" "$CONTAINER" \
  mariadb-dump -uroot --single-transaction --all-databases \
  | gzip > "$BACKUP_DIR/kodi-$STAMP.sql.gz"

find "$BACKUP_DIR" -name 'kodi-*.sql.gz' -mtime +"$KEEP_DAYS" -delete

echo "backup done: $BACKUP_DIR/kodi-$STAMP.sql.gz"
