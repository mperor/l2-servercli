# L2J Server provider for l2.sh (sourced, not executed); see servers/l2jmobius/provider.sh for the interface.
# Each chronicle is a game and a datapack branch (sources/l2j/<chronicle>/{game,datapack}); the login server
# (sources/l2j/login, master) serves all of them.

PROVIDER_NAME="L2J Server"
PROVIDER_SUBMODULE=l2j_login
PROVIDER_DEFAULT_CHRONICLE=Interlude
PROVIDER_GEODATA_FILES='^[0-9]+_[0-9]+\.l2j$'
PROVIDER_REGISTERED_LOG='Registered on login as Server'

# Interlude GMAccess.properties grants GM rights from 100; High Five has accessLevels.xml with Master = 8
case "$(env_get CHRONICLE)" in
	HighFive)
		PROVIDER_GM_LEVEL=8
		PROVIDER_ACCESS_LEVELS=sources/l2j/HighFive/datapack/src/main/resources/config/accessLevels.xml
		;;
	*)
		PROVIDER_GM_LEVEL=100
		PROVIDER_ACCESS_LEVELS=sources/l2j/Interlude/game/src/main/resources/config/GMAccess.properties
		;;
esac

provider_chronicles() { printf '%s\n' Interlude HighFive; }

# Submodules of a chronicle, used by provider_prepare and ./l2.sh update
provider_submodules() {
	local chronicle
	chronicle="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
	printf '%s\n' l2j_login "l2j_${chronicle}_game" "l2j_${chronicle}_datapack"
}

provider_prepare() {
	provider_chronicles | grep -qx "$1" || die "Unknown chronicle '$1'. List them with: $CLI chronicle"
	local name
	for name in $(provider_submodules "$1"); do
		ensure_submodule "$name"
	done
}

provider_slug() { printf '%s' "${1,,}"; }

provider_legacy_volumes() { :; }

provider_protocol() {
	local config="sources/l2j/$1/game/src/main/resources/config/server.properties" min max
	if [ "$1" = Interlude ]; then
		min="$(sed -n 's/^MinProtocolRevision *= *//p' "$config" 2>/dev/null | tr -d '\r')"
		max="$(sed -n 's/^MaxProtocolRevision *= *//p' "$config" 2>/dev/null | tr -d '\r')"
		[ -n "$min" ] && echo "$min-$max"
	else
		sed -n 's/^AllowedProtocolRevisions *= *//p' "$config" 2>/dev/null | tr -d '\r' | sed 's/,/, /g'
	fi
}
