# L2 Quickstart

Run an open-source Lineage II server emulator with a single command. Each server's source is pulled
in as a git submodule from its official repository, built inside Docker and started together with
MariaDB. Supported servers (`SERVER` in `.env`, see [Servers](#servers)):

- **`l2jmobius`** (default) - [L2jMobius](https://l2jmobius.org/), any chronicle of the
  [monorepo](https://gitlab.com/MobiusDevelopment/L2J_Mobius), e.g. C6 Interlude; Java 27.
- **`acis`** - [aCis](https://gitlab.com/Tryskell/acis_public) (Interlude only, latest public
  revision); Java 21.

## Requirements

- [Docker](https://docs.docker.com/get-docker/) with Compose v2 (Docker Desktop on Windows/macOS)
- Git (on Windows: [Git for Windows](https://git-scm.com/download/win), which also provides Git Bash)
- ~4 GB RAM for the game server (see `GAME_JAVA_OPTS` in `.env`)

## Quick start

```bash
git clone https://github.com/mperor/l2-quickstart.git
cd l2-quickstart
./l2.sh up          # Windows PowerShell: .\l2.ps1 up
```

On the first run `l2.sh`:

1. creates `.env` from `.env.example`,
2. clones the server's submodule under `sources/` **shallow** (for L2jMobius also **sparse**, so only
   the selected chronicle is downloaded: ~200 MB instead of the whole multi-chronicle repository),
3. builds the server image and starts `db`, `login` and `game`.

The first start imports the SQL schema; afterwards the game server is ready in about 15 seconds.
Then connect a game client, see [Connecting a client](#connecting-a-client).

## Commands

| Command | Description |
|---|---|
| `./l2.sh up` | Prepare submodule and `.env`, build and start (default command) |
| `./l2.sh down` | Stop containers (database volume is kept) |
| `./l2.sh restart game` | Restart a service, e.g. after editing `overrides/` |
| `./l2.sh logs game` | Follow logs of `db`, `login` or `game` |
| `./l2.sh ps` | Container status |
| `./l2.sh status` | Configured server and chronicle, container state, login registration and warnings (e.g. no geodata) |
| `./l2.sh server [name]` | List available servers or switch to one |
| `./l2.sh chronicle [name]` | List the current server's chronicles or switch to one |
| `./l2.sh update` | Move the server submodule to the latest upstream commit |
| `./l2.sh gm` | List characters with their access levels |
| `./l2.sh gm <login> [level]` | Set the access level of an account's characters (default `100` = Master) |
| `./l2.sh tools` | Start phpMyAdmin on http://localhost:8080 |

## Servers

`./l2.sh server` lists the servers in `servers/`; switch with `./l2.sh server <name>` (stops the
running one and selects the server's default chronicle, then run `./l2.sh up`).

Every server and chronicle is its own compose project, `l2-<server>-<chronicle>`
(e.g. `l2-acis-interlude`, `l2-l2jmobius-ct_0_interlude`), with its own containers, network,
database (`<project>_db-data`) and game state volume (`<project>_game-state`), so switching back and
forth keeps characters intact. `./l2.sh up` removes the containers of any other project first, since
they use the same ports; their volumes stay. `docker volume ls` lists them; delete one you no longer
need with `docker volume rm <name>`.

`docker-compose.yml` holds what all servers share (MariaDB, ports, overrides, phpMyAdmin);
`servers/<server>/compose.yml` adds the server's image, build, database name and SQL import. `l2.sh`
merges them by setting `COMPOSE_FILE` and `COMPOSE_PROJECT_NAME` in `.env`, so plain
`docker compose ...` commands work as well.

Earlier versions kept all L2jMobius chronicles in one project `l2jmobius` with volumes
`l2jmobius-db-<chronicle>` / `l2jmobius-state-<chronicle>`. `./l2.sh up` copies them once into the
chronicle's new volumes; the old volumes are not touched and can be deleted afterwards.

### aCis

```bash
./l2.sh server acis   # CHRONICLE=Interlude
./l2.sh up            # game server ready when "./l2.sh logs game" shows "Registered as server"
```

- Configuration is in `*.properties` files: override e.g. `overrides/acis/game/config/players.properties`
  (from `sources/acis/aCis_gameserver/config/`). The database connection, `LoginHost`, `Hostname`
  (= `EXTERNAL_HOST`) and the login's `AcceptNewGameServer = True` are always set from `.env`.
- The game server's registration (`config/hexid.txt`) is generated on the first start and kept in the
  `l2-acis-interlude_game-state` volume; no `RegisterGameServer` step is needed. The database is `acis`.
- Geodata (see [Configuration](#configuration)) can be `XX_YY_conv.dat` or `XX_YY.l2j`; the format is
  detected from the file names and only regions with a file are loaded.
- Two source changes are applied at build time (the build fails if upstream changes those lines):
  the login server always sends `Hostname`, because behind Docker's NAT every client has a private IP and
  would otherwise get the game server's container address; and movement is allowed where no geodata is
  loaded, which upstream rejects completely.
- GM: `./l2.sh gm <login>` sets level `8` (Master, see `aCis_datapack/data/xml/accessLevels.xml`).

## Chronicles

Any `L2J_Mobius_*` directory of the upstream repository can be selected. `./l2.sh chronicle` lists
them all; switch with `./l2.sh chronicle <name>` (stops the running one, then run `./l2.sh up`).
Only the selected chronicle is downloaded.

The default, used as the example throughout this README, is `L2J_Mobius_CT_0_Interlude`.
Each chronicle gets its own image tag (`l2jmobius:<chronicle>`) and its own project
(`l2-l2jmobius-<chronicle without the L2J_Mobius_ prefix>`, see [Servers](#servers)).

## Connecting a client

A game client is not included; use your own client of the selected chronicle.

1. **Matching protocol.** L2jMobius accepts only the protocol revision in the chronicle's
   `dist/game/config/Server.ini` (`AllowedProtocolRevisions`; e.g. `746` for Interlude, `419` for C1),
   aCis accepts Interlude clients `737`-`746`.
   `./l2.sh chronicle` and `./l2.sh up` print it. With a mismatch the login works, but the connection
   drops after selecting the server.
2. **Login address.** The client must connect to `127.0.0.1:2106` instead of the official login server.
   The address is `ServerAddr` in `system/l2.ini`, which is encrypted in original clients. Either
   - use a system patch for your chronicle with a plain `l2.ini` and set `ServerAddr=127.0.0.1`, or
   - decrypt and re-encrypt `l2.ini` with `l2encdec` (`l2encdec -s l2.ini`, edit `dec-l2.ini`,
     `l2encdec -e 413 dec-l2.ini`, rename `enc-l2.ini` to `l2.ini`), or
   - redirect the login host name from `l2.ini` to `127.0.0.1` in the `hosts` file
     (only works if `ServerAddr` is a host name, not an IP).

   To see where the client really connects, run this in PowerShell while it tries to log in:
   `Get-NetTCPConnection -OwningProcess (Get-Process l2).Id`.
3. **Account.** Log in with any login and password; the account is created on first login
   (`AutoCreateAccounts = True`). The login server then sends the client to `EXTERNAL_HOST:7777`.

### GM access

1. Log in, create a character and log out (the game saves the access level on logout and would
   overwrite the change).
2. `./l2.sh gm <login>` sets the Master level on all characters of the account: `100` for L2jMobius
   (levels in `dist/game/config/AccessLevels.xml`), `8` for aCis (`data/xml/accessLevels.xml`).
3. Check with `./l2.sh gm` (lists characters and levels), then log in and type `//admin` in the chat.
   GMs start invisible and invulnerable (`GMStartup*` in `General.ini`); `//visible` shows you to others.

The bundled `AccountManager` cannot be used: it opens a Swing window even in console mode, which fails
in a container without a display.

## Configuration

- **`.env`** - server, chronicle, database credentials, `EXTERNAL_HOST`, ports, JVM options
  (`COMPOSE_*` lines are maintained by `l2.sh`).
- **`overrides/<server>/`** - your own versions of any file under `dist/game` or `dist/login`
  (e.g. `overrides/l2jmobius/game/config/Rates.ini`). They are copied over the defaults on every
  container start, so no rebuild is needed. See [overrides/README.md](overrides/README.md).
- **`geodata/<server>/`** - geodata region files of the chronicle (terrain, walls, line of sight). They are
  not part of the server repositories and have to be obtained separately (L2jMobius: `XX_YY.l2j`).
  The directory is mounted into the game server; after adding files run `./l2.sh restart game`. Without
  geodata characters and monsters move without obstacles (through walls, no pathfinding);
  `./l2.sh up` and `./l2.sh status` warn about it.

### Playing from other machines

Set `EXTERNAL_HOST` in `.env` to the LAN or public IP of the Docker host and run `./l2.sh up`.
For mixed local/LAN/internet setups put your own `ipconfig.xml` in `overrides/l2jmobius/game/config/`.
Ports `2106` and `7777` must be reachable.

## Project layout

```
docker-compose.yml               shared services: db, login, game (+ phpmyadmin, "tools" profile)
servers/<server>/compose.yml     server-specific image, build, SQL import, volume names
servers/<server>/provider.sh     sourced by l2.sh: fetching the source, chronicles, protocol
servers/<server>/Dockerfile      build -> runtime image (L2jMobius: Ant + JDK 27)
servers/<server>/entrypoint.sh   applies overrides, sets DB/network settings, starts login|game
servers/<server>/initdb.sh       imports the server's SQL on the first database start
l2.sh / l2.ps1                   the single entry point
sources/l2j_mobius/              submodule: MobiusDevelopment/L2J_Mobius (sparse checkout)
sources/acis/                    submodule: Tryskell/acis_public (shallow)
overrides/<server>/              your config overrides
data/logs/<server>/              server logs (git-ignored)
geodata/<server>/                geodata region files, if you have them (git-ignored)
```

## Updating a server

```bash
./l2.sh update
./l2.sh up
git add sources/l2j_mobius && git commit -m "Update L2J_Mobius"
```

The submodule commit recorded in this repository is what everybody cloning it will build,
so updates are explicit and reproducible.

## Modifying the server source

The submodule points to the upstream GitLab repository. To keep your own Java changes,
mirror it to a repository you own and switch the submodule URL:

```bash
gh repo create <you>/L2J_Mobius --private
git -C sources/l2j_mobius remote add mine https://github.com/<you>/L2J_Mobius.git
git -C sources/l2j_mobius fetch --unshallow origin master
git -C sources/l2j_mobius push mine HEAD:refs/heads/master
git submodule set-url sources/l2j_mobius https://github.com/<you>/L2J_Mobius.git
```

GitHub does not charge for repository storage (private repositories included); just keep within
GitHub's limits (no single file over 100 MB, repository ideally under a few GB).
Merge upstream changes into your mirror from time to time.

## Credits and license

- Inspired by [stsourlidakis/l2jmobius-docker](https://github.com/stsourlidakis/l2jmobius-docker) (WTFPL),
  rewritten for the current L2jMobius layout (`Database.ini`, Java 27, multi-chronicle monorepo)
  and generalised to several server emulators.
- L2jMobius is licensed under the GNU GPL v3; see the upstream repository. The public aCis repository
  ships no license file; see its project page.
- This repository's own files may be used under the same terms as the original (WTFPL).
