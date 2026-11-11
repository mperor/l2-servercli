# aCis provider for l2.sh (sourced, not executed); see servers/l2jmobius/provider.sh for the interface.
# aCis targets Interlude only, so there is a single chronicle.

PROVIDER_SUBMODULE=acis
PROVIDER_DEFAULT_CHRONICLE=Interlude
PROVIDER_GM_LEVEL=8
PROVIDER_ACCESS_LEVELS=aCis_datapack/data/xml/accessLevels.xml

provider_prepare() {
	[ "$1" = Interlude ] || die "aCis only runs Interlude (CHRONICLE=Interlude)"
	ensure_submodule "$PROVIDER_SUBMODULE"
	mkdir -p geodata/acis
}

provider_chronicles() { echo Interlude; }

# Hard-coded in SendProtocolVersion.java
provider_protocol() { echo "746 (also 737, 740, 744)"; }
