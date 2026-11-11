#!/usr/bin/env bash
# Single entry point for L2 Quickstart.
# Usage: ./l2.sh [command] [args]   (no command: status; run ./l2.sh help for the list)
set -euo pipefail

cd "$(dirname "$0")"

# How the user calls this script (l2.ps1 sets .\l2.ps1), used in the commands it suggests
CLI="${L2_CLI:-./l2.sh}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWarning:\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

env_get() { sed -n "s/^$1=//p" .env | tail -n 1 | tr -d '\r'; }
env_set() {
	if grep -q "^$1=" .env; then
		sed -i "s|^$1=.*|$1=$2|" .env
	else
		echo "$1=$2" >> .env
	fi
}

available_servers() { ls servers; }

# Compose merges servers/<SERVER>/compose.yml over the common docker-compose.yml.
# COMPOSE_FILE lives in .env, so plain "docker compose ..." commands work as well.
select_server_compose() {
	env_set COMPOSE_PATH_SEPARATOR :
	env_set COMPOSE_FILE "docker-compose.yml:servers/$1/compose.yml"
}

ensure_env() {
	if [ ! -f .env ]; then
		cp .env.example .env
		log "Created .env from .env.example (change the passwords before exposing the server)"
	fi
	# .env files from before the multi-server layout only had CHRONICLE (L2jMobius)
	if [ -z "$(env_get SERVER)" ]; then
		env_set SERVER l2jmobius
		log "Set SERVER=l2jmobius in .env"
	fi
	local server
	server="$(env_get SERVER)"
	[ -f "servers/$server/provider.sh" ] || die "Unknown SERVER '$server' in .env. List them with: $CLI server"
	[ "$(env_get COMPOSE_FILE)" = "docker-compose.yml:servers/$server/compose.yml" ] || select_server_compose "$server"
}

load_provider() {
	# shellcheck source=servers/l2jmobius/provider.sh
	source "servers/$(env_get SERVER)/provider.sh"
}

# One compose project per server and chronicle (e.g. l2-acis-interlude), so containers, network and
# volumes never mix. Project names may only contain lowercase letters, digits, "_" and "-".
project_name() {
	printf 'l2-%s-%s' "$(env_get SERVER)" "$(provider_slug "$(env_get CHRONICLE)")" \
		| tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '_'
}

sync_project() {
	local project
	project="$(project_name)"
	[ "$(env_get COMPOSE_PROJECT_NAME)" = "$project" ] || env_set COMPOSE_PROJECT_NAME "$project"
}

submodule_path() { git config -f .gitmodules "submodule.$1.path"; }

# core.longpaths: some datapack paths exceed the Windows 260 character limit
sub() {
	local name="$1"
	shift
	git -C "$(submodule_path "$name")" -c core.longpaths=true "$@"
}

# Clones a submodule shallow and blob-less; with sparse directories given, only those are checked out
ensure_submodule() {
	local name="$1"
	shift
	local path
	path="$(submodule_path "$name")"
	[ -n "$path" ] || die "Submodule $name not found in .gitmodules"
	if [ -e "$path/.git" ]; then
		return
	fi

	if [ -d ".git/modules/$name" ]; then
		log "Restoring submodule working tree $path"
		git submodule update --init "$path"
		return
	fi

	local url sha
	url="$(git config -f .gitmodules "submodule.$name.url")"
	sha="$(git ls-tree HEAD "$path" | awk '{print $3}')"
	[ -n "$sha" ] || die "Submodule commit for $path not found in HEAD"

	log "Cloning $url${*:+ (sparse: $*)}, commit ${sha:0:10}"
	rm -rf "$path"
	git clone --filter=blob:none --no-checkout --depth 1 "$url" "$path"
	sub "$name" config core.longpaths true
	if [ $# -gt 0 ]; then
		sub "$name" sparse-checkout set --cone "$@"
	fi
	sub "$name" fetch --depth 1 --filter=blob:none origin "$sha"
	sub "$name" checkout -q "$sha"
	git submodule init "$path"
	git submodule absorbgitdirs "$path"
}

prepare() {
	local chronicle
	chronicle="$(env_get CHRONICLE)"
	[ -n "$chronicle" ] || die "CHRONICLE is not set in .env"
	provider_prepare "$chronicle"
	local server
	server="$(env_get SERVER)"
	mkdir -p "data/logs/$server/login" "data/logs/$server/game" "overrides/$server" "geodata/$server"
}

# One line naming the configured server, shown before commands act on it
show_context() {
	log "$PROVIDER_NAME $(env_get CHRONICLE) (project $(env_get COMPOSE_PROJECT_NAME))"
}

# Other l2 projects with running containers (e.g. the previous server before ./l2.sh up)
running_other_projects() {
	docker ps --format '{{.Label "com.docker.compose.project"}}' 2>/dev/null | grep -E '^(l2-|l2jmobius$)' | sort -u \
		| grep -vx "$(env_get COMPOSE_PROJECT_NAME)" || true
}

# Things that work differently than one might expect for this setup
show_notes() {
	local server count p
	server="$(env_get SERVER)"
	count="$(ls "geodata/$server" 2>/dev/null | grep -c -E "$PROVIDER_GEODATA_FILES" || true)"
	if [ "$count" = 0 ]; then
		warn "no geodata in geodata/$server/ - characters and monsters walk through walls, no pathfinding"
	else
		log "Geodata: $count region files in geodata/$server/"
	fi
	while read -r p; do
		[ -n "$p" ] && warn "project $p is running, not this one; $CLI up replaces it"
	done < <(running_other_projects)
}

# "db running (healthy), login running, game exited" for the services that exist, empty if none
services_state() {
	docker compose ps -a --format '{{.Service}} {{.State}} {{.Health}}' 2>/dev/null \
		| awk '{ s[$1] = $1 " " $2 ($3 != "" ? " (" $3 ")" : "") }
			END { n = split("db login game", order, " "); for (i = 1; i <= n; i++) if (order[i] in s) out = out (out ? ", " : "") s[order[i]]; print out }'
}

status_row() { printf '  %-16s %s\n' "$1" "$2"; }
next_row() { printf '  %-32s %s\n' "$1" "$2"; }

cmd_status() {
	local chronicle server project state ready=false starting=false
	chronicle="$(env_get CHRONICLE)"
	server="$(env_get SERVER)"
	project="$(env_get COMPOSE_PROJECT_NAME)"

	state="$(services_state)"
	if docker compose ps --status running -q game 2>/dev/null | grep -q .; then
		if docker compose logs --no-log-prefix game 2>/dev/null | grep -q "$PROVIDER_REGISTERED_LOG"; then
			ready=true
			state="$state - registered on login, ready"
		else
			starting=true
			state="$state - not registered on login yet"
		fi
	fi

	printf '%s  %s   (project %s)\n\n' "$PROVIDER_NAME" "$chronicle" "$project"
	local protocol
	protocol="$(provider_protocol "$chronicle")"
	if [[ "$protocol" == *[,\;]* ]]; then
		status_row "Client protocol" "$protocol (the game client must use one of these revisions)"
	else
		status_row "Client protocol" "${protocol:-unknown} (the game client must use this revision)"
	fi
	status_row Login "127.0.0.1:$(env_get LOGIN_PORT) (the address to set in the client)"
	status_row Game "$(env_get EXTERNAL_HOST):7777 (the login server sends clients here: EXTERNAL_HOST in .env)"
	status_row State "${state:-not running}"
	echo
	show_notes

	echo
	echo "Next:"
	if $ready; then
		next_row "connect a game client" "to 127.0.0.1:$(env_get LOGIN_PORT), see README \"Connecting a client\""
		next_row "$CLI logs game" "follow the game server log"
		next_row "$CLI down" "stop this server"
	elif $starting; then
		next_row "$CLI logs game" "follow the startup until \"$PROVIDER_REGISTERED_LOG\""
		next_row "$CLI down" "stop this server"
	else
		next_row "$CLI up" "start this server"
	fi
	local count other
	if [ -e "$(submodule_path "$PROVIDER_SUBMODULE")/.git" ]; then
		count="$(provider_chronicles 2>/dev/null | grep -c . || true)"
		if [ "$count" -gt 1 ]; then
			next_row "$CLI chronicle" "list the $count chronicles"
			next_row "$CLI chronicle <name>" "switch the chronicle"
		else
			next_row "$CLI chronicle" "list the chronicles ($count)"
		fi
	else
		next_row "$CLI chronicle" "download the source and list the chronicles"
	fi
	while read -r other; do
		next_row "$CLI $other [chronicle]" "switch to $(sed -n 's/^PROVIDER_NAME=//p' "servers/$other/provider.sh")"
	done < <(available_servers | grep -vx "$server")
}

stop_running() {
	if docker compose ps -q 2>/dev/null | grep -q .; then
		log "Stopping running $(env_get SERVER) $(env_get CHRONICLE)"
		docker compose --profile tools down
	fi
}

# Containers of other servers/chronicles hold the same host ports. "l2jmobius" is the single project
# used before the per-chronicle projects.
remove_other_projects() {
	local current p
	current="$(env_get COMPOSE_PROJECT_NAME)"
	while read -r p; do
		[ -n "$p" ] && [ "$p" != "$current" ] || continue
		log "Removing containers of project $p (its data volumes are kept)"
		docker compose -p "$p" --profile tools down --remove-orphans
	done < <(docker ps -a --format '{{.Label "com.docker.compose.project"}}' | grep -E '^(l2-|l2jmobius$)' | sort -u)
}

# Copies data from volumes of the earlier layout (provider_legacy_volumes) into this project's volumes,
# once, before the project's volumes exist. The old volumes are left for the user to delete.
migrate_legacy_volumes() {
	local project key legacy pending=()
	project="$(env_get COMPOSE_PROJECT_NAME)"
	while read -r key legacy; do
		[ -n "$legacy" ] || continue
		docker volume inspect "$legacy" > /dev/null 2>&1 || continue
		docker volume inspect "${project}_$key" > /dev/null 2>&1 && continue
		pending+=("$key $legacy")
	done < <(provider_legacy_volumes "$(env_get CHRONICLE)")
	[ ${#pending[@]} -gt 0 ] || return 0

	docker compose build
	docker compose up --no-start
	local entry
	for entry in "${pending[@]}"; do
		read -r key legacy <<< "$entry"
		log "Copying volume $legacy to ${project}_$key (delete the old one when no longer needed)"
		docker run --rm -v "$legacy:/from:ro" -v "${project}_$key:/to" --entrypoint sh mariadb:11.8 -c 'cp -a /from/. /to/'
	done
}

cmd_up() {
	prepare
	remove_other_projects
	migrate_legacy_volumes
	log "Building and starting"
	docker compose up -d --build "$@"
	echo
	cmd_status
}

cmd_server() {
	local name="${1:-}" current s
	current="$(env_get SERVER)"
	if [ -z "$name" ]; then
		echo "Available servers (* current):"
		while read -r s; do
			if [ "$s" = "$current" ]; then echo "  * $s"; else echo "    $s"; fi
		done < <(available_servers)
		return
	fi
	[ -f "servers/$name/provider.sh" ] || die "Unknown server '$name'. List them with: $CLI server"
	local chronicle="${2:-}"
	if [ "$name" = "$current" ]; then
		[ -n "$chronicle" ] || { log "SERVER is already $name"; return; }
	else
		stop_running
		env_set SERVER "$name"
		select_server_compose "$name"
		load_provider
		env_set CHRONICLE "$PROVIDER_DEFAULT_CHRONICLE"
		sync_project
		[ -n "$chronicle" ] || { log "SERVER=$name, CHRONICLE=$PROVIDER_DEFAULT_CHRONICLE. Start it with: $CLI up"; return; }
	fi
	cmd_chronicle "$chronicle"
}

cmd_chronicle() {
	local name="${1:-}"
	if [ -z "$name" ]; then
		prepare
		local current c
		current="$(env_get CHRONICLE)"
		echo "Available chronicles of $(env_get SERVER) (* current):"
		while read -r c; do
			if [ "$c" = "$current" ]; then echo "  * $c"; else echo "    $c"; fi
		done < <(provider_chronicles)
		echo "Current: $current (client protocol $(provider_protocol "$current"))"
		return
	fi
	provider_prepare "$name"
	stop_running
	env_set CHRONICLE "$name"
	sync_project
	log "CHRONICLE=$name (client protocol $(provider_protocol "$name")). Start it with: $CLI up"
}

cmd_update() {
	prepare
	local name="$PROVIDER_SUBMODULE" path branch before after
	path="$(submodule_path "$name")"
	branch="$(git config -f .gitmodules "submodule.$name.branch" || echo master)"
	before="$(sub "$name" rev-parse HEAD)"
	log "Fetching latest upstream $branch"
	sub "$name" fetch --depth 1 --filter=blob:none origin "$branch"
	sub "$name" checkout -q FETCH_HEAD
	after="$(sub "$name" rev-parse HEAD)"
	if [ "$before" = "$after" ]; then
		log "Already up to date (${after:0:10})"
		return
	fi
	log "Submodule moved ${before:0:10} -> ${after:0:10}"
	log "Rebuild with: $CLI up"
	log "Record it with: git add $path && git commit -m \"Update $name to ${after:0:10}\""
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

	local login="$1" level="${2:-$PROVIDER_GM_LEVEL}"
	[[ "$login" =~ ^[A-Za-z0-9_-]+$ ]] \
		|| die "Usage: $CLI gm <login> [level]  (levels in $PROVIDER_ACCESS_LEVELS, default $PROVIDER_GM_LEVEL = Master)"
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
Usage: $CLI [command]   (without a command: status)

  up [services]       Prepare source/.env, build and start
  down                Stop and remove containers (data volumes are kept)
  restart [service]   Restart services, e.g. after editing overrides/
  logs [service]      Follow logs (db, login, game)
  ps                  Show container status
  status              Show the configured server and chronicle, its state, warnings (e.g. no geodata)
                      and the next step (default)
  server [name [chronicle]]
                      List available servers or switch to one (e.g. l2jmobius), optionally with a chronicle
  <server> [chronicle]
                      Same as server <server> [chronicle], e.g. $CLI acis
  chronicle [name]    List the current server's chronicles or switch to one
  update              Move the server source to the latest upstream commit
  gm                  List characters with their access levels
  gm <login> [level]  Set the access level of an account's characters (default: the server's Master level)
  tools               Start phpMyAdmin on http://localhost:\$PHPMYADMIN_PORT
EOF
}

command="${1:-status}"
[ $# -gt 0 ] && shift

case "$command" in
	help | -h | --help) cmd_help; exit ;;
esac

ensure_env
load_provider
sync_project

# Commands acting on the stack first say which server and chronicle that is
case "$command" in
	up | down | restart | logs | ps | update | gm | tools) show_context ;;
esac

case "$command" in
	up) cmd_up "$@" ;;
	status) cmd_status ;;
	down) docker compose --profile tools down "$@" ;;
	restart) docker compose restart "$@" ;;
	logs) docker compose logs -f --tail=200 "$@" ;;
	ps) docker compose ps "$@" ;;
	server) cmd_server "$@" ;;
	chronicle) cmd_chronicle "$@" ;;
	update) cmd_update ;;
	gm) cmd_gm "$@" ;;
	tools) prepare && docker compose --profile tools up -d phpmyadmin ;;
	*)
		# ./l2.sh <server> [chronicle] is a shortcut for ./l2.sh server <server> [chronicle]
		if [ -f "servers/$command/provider.sh" ]; then
			cmd_server "$command" "$@"
		else
			cmd_help
			exit 1
		fi
		;;
esac
