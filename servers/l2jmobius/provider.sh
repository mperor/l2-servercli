# L2jMobius provider for l2.sh (sourced, not executed).
# A provider defines:
#   PROVIDER_NAME                   display name (read with sed by l2.sh status for other servers, keep it plain)
#   PROVIDER_SUBMODULE              submodule name in .gitmodules holding the server source
#   PROVIDER_DEFAULT_CHRONICLE      CHRONICLE used when switching to this server
#   PROVIDER_GM_LEVEL               characters.accesslevel of the Master level (./l2.sh gm default)
#   PROVIDER_ACCESS_LEVELS          where the access levels are defined (shown in ./l2.sh gm usage)
#   PROVIDER_GEODATA_FILES          regex for geodata region file names in geodata/<server>/
#   PROVIDER_REGISTERED_LOG         game server log text once it is registered on the login server
#   provider_prepare <chronicle>    makes the source of the chronicle available (dies if unknown)
#   provider_chronicles             lists the chronicles this server can run
#   provider_protocol <chronicle>   client protocol revision the game server accepts
#   provider_slug <chronicle>       short chronicle name for the compose project (l2-<server>-<slug>)
#   provider_legacy_volumes <chr>   "<volume key> <old volume name>" lines to copy once into the project

PROVIDER_NAME=L2jMobius
PROVIDER_SUBMODULE=l2j_mobius
PROVIDER_DEFAULT_CHRONICLE=L2J_Mobius_CT_0_Interlude
PROVIDER_GM_LEVEL=100
PROVIDER_ACCESS_LEVELS=dist/game/config/AccessLevels.xml
PROVIDER_GEODATA_FILES='^[0-9]+_[0-9]+\.l2j$'
PROVIDER_REGISTERED_LOG='Registered on login as Server'

# The monorepo has ~40 chronicles; the sparse checkout holds only the ones used so far
provider_prepare() {
	ensure_submodule "$PROVIDER_SUBMODULE" "$1"
	local path
	path="$(submodule_path "$PROVIDER_SUBMODULE")"
	[ -d "$path/$1" ] && return
	provider_chronicles | grep -qx "$1" \
		|| die "Unknown chronicle '$1'. List them with: ./l2.sh chronicle"
	log "Adding $1 to sparse checkout"
	sub "$PROVIDER_SUBMODULE" sparse-checkout add "$1"
}

# Lists every chronicle directory in the submodule commit (works without checking them out)
provider_chronicles() { sub "$PROVIDER_SUBMODULE" ls-tree -d --name-only HEAD | grep '^L2J_Mobius_'; }

# L2J_Mobius_CT_0_Interlude -> ct_0_interlude (project l2-l2jmobius-ct_0_interlude)
provider_slug() { local s="${1#L2J_Mobius_}"; printf '%s' "${s,,}"; }

# Before the per-chronicle projects all chronicles shared the project "l2jmobius" with these volume names
provider_legacy_volumes() {
	echo "db-data l2jmobius-db-$1"
	echo "game-state l2jmobius-state-$1"
}

provider_protocol() {
	sed -n 's/^AllowedProtocolRevisions *= *//p' \
		"$(submodule_path "$PROVIDER_SUBMODULE")/$1/dist/game/config/Server.ini" 2>/dev/null | tr -d '\r'
}
