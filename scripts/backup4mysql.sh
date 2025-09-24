#!/bin/bash
set -eu

umask 077
period=5
DIR='/root/backup/mysql'
filename=$(date +%y%m%d)

/usr/bin/mysqldump --single-transaction --all-databases --events --default-character-set=utf8mb4 -u root | /usr/bin/gzip > "$DIR/$filename.sql.gz"

OLD_DATE=$(date +%y%m%d --date "$period days ago")
OLD_DUMP=${DIR}/mysqldump.${OLD_DATE}.sql.gz
rm -f "${OLD_DUMP}"

exit 0
