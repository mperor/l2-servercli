#!/bin/bash
# Executed by the MariaDB image on first start (empty data volume only).
# Imports the chronicle's SQL scripts: login tables first, then game tables.
set -eo pipefail

for dir in /l2-sql/login /l2-sql/game; do
	for f in "$dir"/*.sql; do
		[ -e "$f" ] || continue
		echo "initdb: importing $f"
		mariadb --protocol=socket -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE" < "$f"
	done
done
