#!/usr/bin/env bash
# Single entry point for the L2jMobius Docker setup.
# Usage: ./l2.sh [command] [args]   (run ./l2.sh help for the list)
set -euo pipefail

cd "$(dirname "$0")"

SUBMODULE=l2j_mobius
SUPPORTED_CHRONICLES="L2J_Mobius_C1_HarbingersOfWar L2J_Mobius_C4_ScionsOfDestiny L2J_Mobius_CT_0_Interlude"

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

ensure_chronicle_checked_out() {
	local chronicle="$1"
	[ -d "$SUBMODULE/$chronicle" ] && return
	sub ls-tree -d --name-only HEAD | grep -qx "$chronicle" \
		|| die "Unknown chronicle '$chronicle'. Available: $(sub ls-tree -d --name-only HEAD | grep '^L2J_' | tr '\n' ' ')"
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
	log "Login server: 127.0.0.1:$(env_get LOGIN_PORT), game server: 7777"
	log "Follow startup with: ./l2.sh logs game"
}

cmd_chronicle() {
	local name="${1:-}"
	if [ -z "$name" ]; then
		echo "Supported: $SUPPORTED_CHRONICLES"
		ensure_env
		echo "Current:   $(env_get CHRONICLE)"
		return
	fi
	case " $SUPPORTED_CHRONICLES " in
		*" $name "*) ;;
		*) log "Warning: $name is not one of the tested chronicles ($SUPPORTED_CHRONICLES)" ;;
	esac
	ensure_env
	ensure_submodule "$name"
	ensure_chronicle_checked_out "$name"
	if docker compose ps -q 2>/dev/null | grep -q .; then
		log "Stopping running chronicle $(env_get CHRONICLE)"
		docker compose down
	fi
	env_set CHRONICLE "$name"
	log "CHRONICLE=$name. Start it with: ./l2.sh up"
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

cmd_account() {
	docker compose exec login sh -c 'cd /opt/l2/dist/login && java -Djava.util.logging.config.file=console.cfg -cp "../libs/*" org.l2jmobius.tools.AccountManager'
}

cmd_help() {
	cat <<EOF
Usage: ./l2.sh [command]

  up [services]       Prepare submodule/.env, build and start (default)
  down                Stop and remove containers (data volumes are kept)
  restart [service]   Restart services, e.g. after editing overrides/
  logs [service]      Follow logs (db, login, game)
  ps                  Show container status
  chronicle [name]    Show or switch the chronicle
  update              Move the submodule to the latest upstream master
  account             Run the interactive AccountManager
  tools               Start phpMyAdmin on http://localhost:\$PHPMYADMIN_PORT
EOF
}

command="${1:-up}"
[ $# -gt 0 ] && shift

case "$command" in
	up) cmd_up "$@" ;;
	down) docker compose down "$@" ;;
	restart) docker compose restart "$@" ;;
	logs) docker compose logs -f --tail=200 "$@" ;;
	ps) docker compose ps "$@" ;;
	chronicle) cmd_chronicle "$@" ;;
	update) cmd_update ;;
	account) cmd_account ;;
	tools) prepare && docker compose --profile tools up -d phpmyadmin ;;
	help | -h | --help) cmd_help ;;
	*) cmd_help; exit 1 ;;
esac
