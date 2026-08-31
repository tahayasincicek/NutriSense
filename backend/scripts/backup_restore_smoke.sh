#!/bin/sh
set -eu

backup_path="/tmp/nutrisense-restore-smoke.sql"

cleanup() {
  MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot \
    -e "DROP DATABASE IF EXISTS nutrisense_restore_test;" >/dev/null
  rm -f "$backup_path"
}
trap cleanup EXIT INT TERM

MYSQL_PWD="$MYSQL_PASSWORD" mysqldump \
  --single-transaction \
  --routines \
  --triggers \
  --no-tablespaces \
  -u"$MYSQL_USER" \
  "$MYSQL_DATABASE" > "$backup_path"

MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot \
  -e "DROP DATABASE IF EXISTS nutrisense_restore_test;
      CREATE DATABASE nutrisense_restore_test
      CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot \
  nutrisense_restore_test < "$backup_path"

source_count="$(
  MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -N -uroot \
    -e "SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema='$MYSQL_DATABASE';"
)"
restored_count="$(
  MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -N -uroot \
    -e "SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema='nutrisense_restore_test';"
)"

test "$source_count" -gt 0
test "$source_count" -eq "$restored_count"
echo "BACKUP_RESTORE_SMOKE=PASS data=synthetic-only tables=$source_count"
