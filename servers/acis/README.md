# aCis

[aCis](https://gitlab.com/Tryskell/acis_public) (latest public revision), submodule `sources/acis`.
Interlude only; Java 21, built with Ant.

```bash
./l2server.sh acis      # CHRONICLE=Interlude
./l2server.sh up        # ready at "Registered as server"
```

## Client protocol

Interlude clients `737`, `740`, `744` and `746` (hard-coded in `SendProtocolVersion.java`).

## Configuration

Configuration is in `*.properties` files: override e.g. `overrides/acis/game/config/players.properties`
(originals in `sources/acis/aCis_gameserver/config/`). Always set by the entrypoint: the database
connection, `LoginHost`, `Hostname` (= `EXTERNAL_HOST`, the address sent to clients) and the login
server's `AcceptNewGameServer = True`. The database is `acis`.

The game server's registration (`config/hexid.txt`) is generated on the first start and kept in the game
state volume; no `RegisterGameServer` step is needed.

## Geodata

Not part of the repository. Put `XX_YY_conv.dat` (L2OFF) or `XX_YY.l2j` (L2J) files into
`geodata/acis/`; the format is detected from the file names and only regions with a file are loaded
(aCis itself exits when a listed region is missing).

## Source changes

Two lines are patched at build time; the build fails if upstream changes them:

- The login server always sends `Hostname`. Upstream sends clients with a private IP the game server's
  connection address, which behind Docker's NAT is the unreachable container address for every client.
- Movement is allowed where no geodata is loaded. Upstream rejects every move without geodata
  (null blocks report height 0, which never matches the target), so nobody could walk.

## GM

`./l2server.sh gm <login>` sets level `8` (Master in `aCis_datapack/data/xml/accessLevels.xml`).
