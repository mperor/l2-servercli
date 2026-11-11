# Build context: the aCis submodule (sources/acis). Extra context "scripts" = servers/acis.

FROM eclipse-temurin:21-jdk AS build

ARG ANT_VERSION=1.10.15
ARG ANT_SHA512=d78427aff207592c024ff1552dc04f7b57065a195c42d398fcffe7a0145e8d00cd46786f5aa52e77ab0fdf81334f065eb8011eecd2b48f7228e97ff4cb20d16c

# Ant from Apache instead of apt: the distro package pulls in an older JDK.
ADD https://archive.apache.org/dist/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz /tmp/ant.tar.gz
RUN echo "${ANT_SHA512}  /tmp/ant.tar.gz" | sha512sum -c - \
	&& tar -xzf /tmp/ant.tar.gz -C /opt \
	&& ln -s "/opt/apache-ant-${ANT_VERSION}/bin/ant" /usr/local/bin/ant \
	&& rm /tmp/ant.tar.gz

# The game server build produces login/ and gameserver/ (jars, configs); the datapack build adds data/.
# Both are merged into /opt/l2/dist/{login,game}, the layout entrypoint.sh expects.
WORKDIR /src
COPY . .

# Two source changes; the build fails if upstream changes the patched lines.
# 1. For clients with a private IP the login server sends the game server's connection address instead of
#    its Hostname. Behind Docker's NAT every client has a private IP, and the connection address is the
#    container's, unreachable from the host. The login server always sends Hostname (= EXTERNAL_HOST) instead.
ARG SERVERLIST=aCis_gameserver/java/net/sf/l2j/loginserver/network/serverpackets/ServerList.java
RUN grep -q 'isLocalIp(account.getClientIp()) && ' "$SERVERLIST" \
	&& sed -i 's/isLocalIp(account.getClientIp()) && /false \&\& /' "$SERVERLIST"

# 2. Without geodata every move is rejected (null blocks report height 0, which never matches the target).
#    Movement starting where no geodata is loaded is allowed as is, without obstacles; regions with
#    geodata behave as upstream.
ARG GEOENGINE=aCis_gameserver/java/net/sf/l2j/gameserver/geoengine/GeoEngine.java
ARG CANMOVE='public final boolean canMove(int ox, int oy, int oz, int tx, int ty, int tz, ExServerPrimitive debug)'
ARG VALIDLOC='public final Location getValidLocation(int ox, int oy, int oz, int tx, int ty, int tz, ExServerPrimitive debug)'
RUN grep -qF "$CANMOVE" "$GEOENGINE" && grep -qF "$VALIDLOC" "$GEOENGINE" \
	&& sed -i \
		-e "/$CANMOVE/{n;s/\$/ if (!hasGeo(ox, oy)) return !World.isOutOfWorld(tx, ty);/}" \
		-e "/$VALIDLOC/{n;s/\$/ if (!hasGeo(ox, oy)) return new Location(tx, ty, tz);/}" \
		"$GEOENGINE" \
	&& [ "$(grep -c 'if (!hasGeo(ox, oy))' "$GEOENGINE")" = 2 ]

RUN ant -f aCis_gameserver/build.xml dist \
	&& ant -f aCis_datapack/build.xml build \
	&& mkdir -p /opt/l2/dist \
	&& cp -r aCis_gameserver/build/dist/login /opt/l2/dist/login \
	&& cp -r aCis_gameserver/build/dist/gameserver /opt/l2/dist/game \
	&& cp -r aCis_datapack/build/gameserver/. /opt/l2/dist/game/ \
	&& cp -r aCis_datapack/build/login/. /opt/l2/dist/login/

FROM eclipse-temurin:21-jre

COPY --from=build /opt/l2/dist /opt/l2/dist
COPY --from=scripts entrypoint.sh /usr/local/bin/entrypoint.sh
# Guard against CRLF line endings from a Windows checkout
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /opt/l2/dist
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
