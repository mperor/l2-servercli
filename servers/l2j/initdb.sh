#!/bin/bash
# Executed by the MariaDB image on first start (empty data volume only).
# Imports the login tables, then the chronicle's game tables with their custom and mods tables, into one
# database (the table names do not overlap), like "l2jcli db install -m FULL -mods" does for two databases.
# Older datapacks (Interlude) still carry their own login tables; the login server's versions are kept.
set -eo pipefail

for dir in /l2-sql/login /l2-sql/game /l2-sql/game/custom /l2-sql/game/mods; do
	for f in "$dir"/*.sql; do
		[ -e "$f" ] || continue
		if [ "$dir" != /l2-sql/login ] && [ -e "/l2-sql/login/$(basename "$f")" ]; then
			echo "initdb: skipping $f (login table, imported from the login server)"
			continue
		fi
		echo "initdb: importing $f"
		mariadb --protocol=socket -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE" < "$f"
	done
done
