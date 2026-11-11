#!/usr/bin/env bash
# Single entry point for the L2jMobius Docker setup.
# Usage: ./l2.sh [command] [args]   (run ./l2.sh help for the list)
set -euo pipefail

cd "$(dirname "$0")"

SUBMODULE=l2j_mobius

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

env_get() { sed -n "s/^$1=//p" .env | tail -n 1 | tr -d '\r'; }
env_set() {
	if grep -q "^$1=" .env; then
		sed -i "s|^$1=.*|$1=$2|" .env
	else
		echo "$1=$2" >> .env
	fi
}

ensure_env() {
	if [ ! -f .env ]; then
		cp .env.example .env
		log "Created .env from .env.example (change the passwords before exposing the server)"
	fi
}

# core.longpaths: some datapack paths exceed the Windows 260 character limit
sub() { git -C "$SUBMODULE" -c core.longpaths=true "$@"; }

# Clones the submodule shallow, blob-less and sparse, so only the chosen chronicle is downloaded
ensure_submodule() {
	local chronicle="$1"
	if [ -e "$SUBMODULE/.git" ]; then
		return
	fi

	if [ -d ".git/modules/$SUBMODULE" ]; then
		log "Restoring submodule working tree"
		git submodule update --init "$SUBMODULE"
		return
	fi

	local url sha
	url="$(git config -f .gitmodules "submodule.$SUBMODULE.url")"
	sha="$(git ls-tree HEAD "$SUBMODULE" | awk '{print $3}')"
	[ -n "$sha" ] || die "Submodule commit not found in HEAD"

	log "Cloning $url (sparse: $chronicle, commit ${sha:0:10})"
	rm -rf "$SUBMODULE"
	git clone --filter=blob:none --no-checkout --depth 1 "$url" "$SUBMODULE"
	sub config core.longpaths true
	sub sparse-checkout set --cone "$chronicle"
	sub fetch --depth 1 --filter=blob:none origin "$sha"
	sub checkout -q "$sha"
	git submodule init "$SUBMODULE"
	git submodule absorbgitdirs "$SUBMODULE"
}

# Lists every chronicle directory in the submodule commit (works without checking them out)
available_chronicles() { sub ls-tree -d --name-only HEAD | grep '^L2J_Mobius_'; }

# Client protocol revision the chronicle's game server accepts
protocol_of() {
	sed -n 's/^AllowedProtocolRevisions *= *//p' "$SUBMODULE/$1/dist/game/config/Server.ini" 2>/dev/null | tr -d '\r'
}

ensure_chronicle_checked_out() {
	local chronicle="$1"
	[ -d "$SUBMODULE/$chronicle" ] && return
	available_chronicles | grep -qx "$chronicle" \
		|| die "Unknown chronicle '$chronicle'. List them with: ./l2.sh chronicle"
	log "Adding $chronicle to sparse checkout"
	sub sparse-checkout add "$chronicle"
}

prepare() {
	ensure_env
	local chronicle
	chronicle="$(env_get CHRONICLE)"
	[ -n "$chronicle" ] || die "CHRONICLE is not set in .env"
	ensure_submodule "$chronicle"
	ensure_chronicle_checked_out "$chronicle"
	mkdir -p data/logs/login data/logs/game
}

cmd_up() {
	prepare
	log "Building and starting $(env_get CHRONICLE)"
	docker compose up -d --build "$@"
	log "Login server: 127.0.0.1:$(env_get LOGIN_PORT), game server: 7777, client protocol: $(protocol_of "$(env_get CHRONICLE)")"
	log "Follow startup with: ./l2.sh logs game"
}

cmd_chronicle() {
	local name="${1:-}"
	if [ -z "$name" ]; then
		prepare
		local current c
		current="$(env_get CHRONICLE)"
		echo "Available chronicles (* current):"
		while read -r c; do
			if [ "$c" = "$current" ]; then echo "  * $c"; else echo "    $c"; fi
		done < <(available_chronicles)
		echo "Current: $current (client protocol $(protocol_of "$current"))"
		return
	fi
	ensure_env
	ensure_submodule "$name"
	ensure_chronicle_checked_out "$name"
	if docker compose ps -q 2>/dev/null | grep -q .; then
		log "Stopping running chronicle $(env_get CHRONICLE)"
		docker compose --profile tools down
	fi
	env_set CHRONICLE "$name"
	log "CHRONICLE=$name (client protocol $(protocol_of "$name")). Start it with: ./l2.sh up"
}

cmd_update() {
	prepare
	local before after
	before="$(sub rev-parse HEAD)"
	log "Fetching latest upstream master"
	sub fetch --depth 1 --filter=blob:none origin master
	sub checkout -q FETCH_HEAD
	after="$(sub rev-parse HEAD)"
	if [ "$before" = "$after" ]; then
		log "Already up to date (${after:0:10})"
		return
	fi
	log "Submodule moved ${before:0:10} -> ${after:0:10}"
	log "Rebuild with: ./l2.sh up"
	log "Record it with: git add $SUBMODULE && git commit -m \"Update L2J_Mobius to ${after:0:10}\""
}

# Runs SQL against the game database, prints tab-separated rows without headers
db_query() {
	docker compose exec -T db sh -c 'mariadb -N -B -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE"' <<< "$1" | tr -d '\r'
}

# AccountManager cannot run in the container (it extends JFrame, which fails without a display even in
# console mode), so accounts come from AutoCreateAccounts and the access level is set directly in the database.
# The game reads it from characters.accesslevel, not from accounts.
cmd_gm() {
	if [ $# -eq 0 ]; then
		printf '%-20s %-20s %6s %s\n' ACCOUNT CHARACTER LEVEL ONLINE
		db_query "SELECT account_name, char_name, accesslevel, IF(online = 1, 'yes', 'no') FROM characters ORDER BY account_name, char_name;" \
			| awk -F'\t' '{ printf "%-20s %-20s %6s %s\n", $1, $2, $3, $4 }'
		return
	fi

	local login="$1" level="${2:-100}"
	[[ "$login" =~ ^[A-Za-z0-9_-]+$ ]] || die "Usage: ./l2.sh gm <login> [level]  (levels in AccessLevels.xml, default 100 = Master)"
	[[ "$level" =~ ^-?[0-9]+$ ]] || die "Level must be a number"

	local online count
	online="$(db_query "SELECT COUNT(*) FROM characters WHERE account_name = '$login' AND online = 1;")"
	[ "$online" = 0 ] || die "A character of $login is online; log out first (the game saves the access level on logout)"

	count="$(db_query "UPDATE characters SET accesslevel = $level WHERE account_name = '$login';
		SELECT COUNT(*) FROM characters WHERE account_name = '$login';")"
	[ "$count" != 0 ] || die "No characters on account $login; log in with the client, create a character and run this again"
	log "Set access level $level on $count character(s) of $login"
}

cmd_help() {
	cat <<EOF
Usage: ./l2.sh [command]

  up [services]       Prepare submodule/.env, build and start (default)
  down                Stop and remove containers (data volumes are kept)
  restart [service]   Restart services, e.g. after editing overrides/
  logs [service]      Follow logs (db, login, game)
  ps                  Show container status
  chronicle [name]    List available chronicles or switch to one
  update              Move the submodule to the latest upstream master
  gm                  List characters with their access levels
  gm <login> [level]  Set the access level of an account's characters (default 100 = Master)
  tools               Start phpMyAdmin on http://localhost:\$PHPMYADMIN_PORT
EOF
}

command="${1:-up}"
[ $# -gt 0 ] && shift

case "$command" in
	up) cmd_up "$@" ;;
	down) docker compose --profile tools down "$@" ;;
	restart) docker compose restart "$@" ;;
	logs) docker compose logs -f --tail=200 "$@" ;;
	ps) docker compose ps "$@" ;;
	chronicle) cmd_chronicle "$@" ;;
	update) cmd_update ;;
	gm) cmd_gm "$@" ;;
	tools) prepare && docker compose --profile tools up -d phpmyadmin ;;
	help | -h | --help) cmd_help ;;
	*) cmd_help; exit 1 ;;
esac
