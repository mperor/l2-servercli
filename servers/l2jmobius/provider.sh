# L2jMobius provider for l2.sh (sourced, not executed).
# A provider defines:
#   PROVIDER_SUBMODULE              submodule name in .gitmodules holding the server source
#   PROVIDER_DEFAULT_CHRONICLE      CHRONICLE used when switching to this server
#   provider_prepare <chronicle>    makes the source of the chronicle available (dies if unknown)
#   provider_chronicles             lists the chronicles this server can run
#   provider_protocol <chronicle>   client protocol revision the game server accepts

PROVIDER_SUBMODULE=l2j_mobius
PROVIDER_DEFAULT_CHRONICLE=L2J_Mobius_CT_0_Interlude

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

provider_protocol() {
	sed -n 's/^AllowedProtocolRevisions *= *//p' \
		"$(submodule_path "$PROVIDER_SUBMODULE")/$1/dist/game/config/Server.ini" 2>/dev/null | tr -d '\r'
}
