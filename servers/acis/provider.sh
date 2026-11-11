# aCis provider for l2.sh (sourced, not executed); see servers/l2jmobius/provider.sh for the interface.
# aCis targets Interlude only, so there is a single chronicle.

PROVIDER_NAME=aCis
PROVIDER_SUBMODULE=acis
PROVIDER_DEFAULT_CHRONICLE=Interlude
PROVIDER_GM_LEVEL=8
PROVIDER_ACCESS_LEVELS=aCis_datapack/data/xml/accessLevels.xml
PROVIDER_GEODATA_FILES='^[0-9]+_[0-9]+(_conv\.dat|\.l2j)$'
PROVIDER_REGISTERED_LOG='Registered as server'

provider_prepare() {
	[ "$1" = Interlude ] || die "aCis only runs Interlude (CHRONICLE=Interlude)"
	ensure_submodule "$PROVIDER_SUBMODULE"
}

provider_chronicles() { echo Interlude; }

provider_slug() { printf '%s' "${1,,}"; }

provider_legacy_volumes() { :; }

# Hard-coded in SendProtocolVersion.java
provider_protocol() { echo "746, 744, 740, 737"; }
