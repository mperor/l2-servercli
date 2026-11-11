#!/bin/bash
# Usage: entrypoint.sh login|game
# Applies overrides, renders container-specific settings and starts the server in the foreground.
set -euo pipefail

ROLE="${1:?usage: entrypoint.sh login|game}"
DIST=/opt/l2/dist
DIR="$DIST/$ROLE"
CFG="$DIR/config"

# Defaults from aCis' *_loop.sh; JAVA_OPTS comes later on the command line, so its -Xmx wins
case "$ROLE" in
	login) MAIN=net.sf.l2j.loginserver.LoginServer CONF=loginserver.properties MEM=-Xmx64m ;;
	game) MAIN=net.sf.l2j.gameserver.GameServer CONF=server.properties MEM=-Xmx2G ;;
	*) echo "Unknown role: $ROLE" >&2; exit 1 ;;
esac

# props_set <file> <key> <value> - replaces "Key = ..." keeping the file layout
props_set() {
	local value="${3//\\/\\\\}"
	value="${value//&/\\&}"
	value="${value//|/\\|}"
	sed -i -E "s|^$2[[:space:]]*=.*$|$2 = $value|" "$1"
}

# 1. User overrides (overrides/acis/<role>/... mirrors dist/<role>/...)
if [ -d "/overrides/$ROLE" ]; then
	echo "Applying overrides from /overrides/$ROLE"
	cp -rf "/overrides/$ROLE/." "$DIR/"
fi

# 2. Database connection (values from .env always win)
props_set "$CFG/$CONF" URL "jdbc:mariadb://${DB_HOST:-db}/${MARIADB_DATABASE}"
props_set "$CFG/$CONF" Login "$MARIADB_USER"
props_set "$CFG/$CONF" Password "$MARIADB_PASSWORD"

# 3. Networking between containers
if [ "$ROLE" = login ]; then
	# The game server registers itself on first start; the hex id is kept in the game-state volume
	props_set "$CFG/$CONF" AcceptNewGameServer True
else
	props_set "$CFG/$CONF" LoginHost "${LOGIN_HOST:-login}"
	# Sent to clients by the login server; "*" would be the container's own address
	props_set "$CFG/$CONF" Hostname "${EXTERNAL_HOST:-127.0.0.1}"

	# The public repository ships no geodata, and aCis exits if a region listed in geoengine.properties is
	# missing. Without region files the list is dropped, so the server runs without geodata (no line of sight
	# or pathfinding). Region files placed in overrides/acis/game/data/geodata/ are used as listed.
	if ! ls "$DIR/data/geodata" | grep -q -E '^[0-9]+_[0-9]+'; then
		echo "No geodata in data/geodata, starting without it"
		sed -i -E '/^[0-9]+_[0-9]+[[:space:]]*(=.*)?$/d' "$CFG/geoengine.properties"
	fi

	# aCis refuses to start without config/hexid.txt (normally made by RegisterGameServer on the login side).
	# A random one is generated once and kept in the game-state volume; the login server registers it on first
	# connect because of AcceptNewGameServer = True. An overrides hexid.txt is used as is.
	if [ -d /state ] && [ ! -f "/overrides/game/config/hexid.txt" ]; then
		if [ ! -f /state/hexid.txt ]; then
			printf 'ServerID=1\nHexID=%s\n' "$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')" > /state/hexid.txt
			echo "Generated /state/hexid.txt"
		fi
		ln -sf /state/hexid.txt "$CFG/hexid.txt"
	fi
fi

# 4. Start in the foreground so logs go to "docker logs" and Docker handles restarts
mkdir -p "$DIR/log"
cd "$DIR"
# shellcheck disable=SC2086
exec java "$MEM" ${JAVA_OPTS:-} -cp "libs/*" "$MAIN"
