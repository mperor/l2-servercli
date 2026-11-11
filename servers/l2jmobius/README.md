# L2jMobius

[L2jMobius](https://l2jmobius.org/) from its [GitLab monorepo](https://gitlab.com/MobiusDevelopment/L2J_Mobius),
submodule `sources/l2j_mobius`. Java 27, built with Ant.

```bash
./l2server.sh l2jmobius                                  # default chronicle: L2J_Mobius_CT_0_Interlude
./l2server.sh l2jmobius L2J_Mobius_C1_HarbingersOfWar    # or any other chronicle
./l2server.sh up                                         # ready at "Registered on login as Server"
```

## Chronicles

Any `L2J_Mobius_*` directory of the monorepo can be selected; `./l2server.sh chronicle` lists them all.
The submodule is a shallow, blob-less, **sparse** checkout, so only the chronicles used so far are
downloaded (~200 MB each instead of the whole repository). Each chronicle has its own image tag
(`l2server-l2jmobius:<chronicle>`) and project (`l2server-l2jmobius-<chronicle without the L2J_Mobius_ prefix>`).

## Client protocol

The game server accepts only `AllowedProtocolRevisions` from the chronicle's
`dist/game/config/Server.ini`, e.g. `746` for Interlude and `419` for C1; `./l2server.sh status` shows it.

## Configuration

Overrides go to `overrides/l2jmobius/{game,login}/` (originals in
`sources/l2j_mobius/<chronicle>/dist/`), see [overrides/README.md](../../overrides/README.md).
Always set by the entrypoint: the database connection in `Database.ini`, `EnableGUI = False` in
`Interface.ini`, `LoginHostname = 0.0.0.0` (login) and `LoginHost = login` (game) in `Server.ini`, and a
generated `config/ipconfig.xml` with `EXTERNAL_HOST` (unless you provide one in overrides). The generated
file has a second `define` repeating the default address, because C1's registration on the login server
reads a third host entry and fails with fewer.

Geodata: `XX_YY.l2j` region files in `geodata/l2jmobius/`.

## GM

`./l2server.sh gm <login>` sets level `100` (Master in `dist/game/config/AccessLevels.xml`). GMs start invisible
and invulnerable (`GMStartup*` in `General.ini`); `//visible` shows you to others. The bundled
`AccountManager` cannot be used in the container: it opens a Swing window even in console mode.
