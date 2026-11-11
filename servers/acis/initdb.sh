#!/bin/bash
# Executed by the MariaDB image on first start (empty data volume only).
# Imports every aCis SQL script into one database, like tools/database_installer.sh does.
set -eo pipefail

for f in /l2-sql/*.sql; do
	[ -e "$f" ] || continue
	echo "initdb: importing $f"
	mariadb --protocol=socket -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE" < "$f"
done
