# Build context: a single chronicle directory from the l2j_mobius submodule
# (e.g. l2j_mobius/L2J_Mobius_CT_0_Interlude). Extra context "scripts" = ./docker.

FROM eclipse-temurin:27-jdk AS build

ARG ANT_VERSION=1.10.15
ARG ANT_SHA512=d78427aff207592c024ff1552dc04f7b57065a195c42d398fcffe7a0145e8d00cd46786f5aa52e77ab0fdf81334f065eb8011eecd2b48f7228e97ff4cb20d16c

# Ant from Apache instead of apt: the distro package pulls in an older JDK.
ADD https://archive.apache.org/dist/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz /tmp/ant.tar.gz
RUN echo "${ANT_SHA512}  /tmp/ant.tar.gz" | sha512sum -c - \
	&& tar -xzf /tmp/ant.tar.gz -C /opt \
	&& ln -s "/opt/apache-ant-${ANT_VERSION}/bin/ant" /usr/local/bin/ant \
	&& rm /tmp/ant.tar.gz

# build.xml writes its output to ../build, i.e. /src/build
WORKDIR /src/chronicle
COPY . .
RUN ant -f build.xml jar \
	&& cp /src/build/dist/libs/*.jar dist/libs/ \
	&& rm -f dist/libs/*-sources.jar

# JDK, not JRE: the game server compiles its datapack scripts at runtime (javax.tools)
FROM eclipse-temurin:27-jdk

COPY --from=build /src/chronicle/dist /opt/l2/dist
COPY --from=scripts entrypoint.sh /usr/local/bin/entrypoint.sh
# Guard against CRLF line endings from a Windows checkout
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /opt/l2/dist
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
