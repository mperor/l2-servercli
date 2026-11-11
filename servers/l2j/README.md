# L2J Server

[L2J Server](https://bitbucket.org/l2jserver/workspace/projects/L2J): the game and datapack of the selected
chronicle with the current login server, which accepts both. Java 25, built with the Maven wrappers like
L2J's own Docker images (the first build downloads the Maven dependencies, later ones reuse a BuildKit
cache).

```bash
./l2server.sh l2j             # CHRONICLE=Interlude (default)
./l2server.sh l2j HighFive    # or High Five
./l2server.sh up              # ready at "Registered on login as Server"
```

| | Interlude | High Five |
|---|---|---|
| Game + datapack | `sources/l2j/Interlude/{game,datapack}` (`Interlude` branches) | `sources/l2j/HighFive/{game,datapack}` (`develop`) |
| Client protocol | `740`-`746` | `267`, `268`, `271`, `273` |
| Game configuration | `config/*.properties`, database in `server.properties` | `config/*.properties` incl. `database.properties` |
| GM (`./l2server.sh gm <login>`) | level `100` (`config/GMAccess.properties`) | level `8` (Master, datapack `config/accessLevels.xml`) |
| Geodata in `geodata/l2j/` | `XX_YY.l2j`; when present `GeoData = 1` is set and `geo_index.txt` generated | `XX_YY.l2j`, loaded when present |

- The login server is `sources/l2j/login` (`master`) for both chronicles. Only the selected chronicle's
  submodules are downloaded; `./l2server.sh update` moves them and the login server. The Interlude code targets
  Java 17 and runs on 25.
- Configuration overrides go to `overrides/l2j/{game,login}/config/` (originals in the submodules'
  `src/main/resources/config/`). Always set by the entrypoint: the database connection, `LoginHost`, the
  login's `GameServerHost` and `EnableUPnP = False`; the address sent to clients comes from
  `EXTERNAL_HOST` through a generated `ipconfig.xml`.
- The login and game tables (plus the `custom` and `mods` tables) go into one database, `l2jserver`.
  The Interlude datapack still carries old copies of the login tables (`accounts`, `account_data`,
  `gameservers`); they are skipped in favour of the login server's. The game server registers itself on the
  first start (`AcceptNewGameServer = True`) and keeps `config/hexid.txt` in the game state volume.
