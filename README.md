# L2 Server CLI

Start and switch open-source Lineage II server emulators with one command, e.g. to have a compatible
server at hand while working on a client. Each server is built from its official repository inside Docker
and runs with MariaDB; every server and chronicle keeps its own data.

| Server | Chronicles | Client protocol | Details |
|---|---|---|---|
| `l2jmobius` (default) | any of the L2jMobius monorepo, default Interlude | from the chronicle's `Server.ini` | [servers/l2jmobius](servers/l2jmobius/README.md) |
| `acis` | Interlude | 737-746 | [servers/acis](servers/acis/README.md) |
| `l2j` | Interlude (default), High Five | 740-746 / 267-273 | [servers/l2j](servers/l2j/README.md) |

## Requirements

- [Docker](https://docs.docker.com/get-docker/) with Compose v2 (Docker Desktop on Windows/macOS)
- Git (on Windows: [Git for Windows](https://git-scm.com/download/win), which also provides Git Bash)
- ~4 GB RAM for the game server (see `GAME_JAVA_OPTS` in `.env`)

## Quick start

```bash
git clone https://github.com/mperor/l2-servercli.git
cd l2-servercli
./l2server.sh up          # Windows PowerShell: .\l2server.ps1 up
./l2server.sh             # status: what runs, where to connect, what to do next
```

The first run creates `.env`, downloads the selected server's source (shallow; only the selected
chronicle), builds the image and starts `db`, `login` and `game`; the first database start imports the
SQL schema.

## Switching

```bash
./l2server.sh acis                    # switch server (default chronicle)
./l2server.sh l2j HighFive            # switch server and chronicle
./l2server.sh chronicle               # list the current server's chronicles
./l2server.sh chronicle <name>        # switch chronicle
./l2server.sh up                      # start what is selected
```

Switching stops the running server; `./l2server.sh up` starts the selected one. Characters and settings of
every server and chronicle stay in their own Docker volumes.

## Commands

| Command | Description |
|---|---|
| `./l2server.sh` / `./l2server.sh status` | Selected server and chronicle, client protocol, addresses, state, warnings, next steps |
| `./l2server.sh up` | Download the source, build and start |
| `./l2server.sh down` | Stop and remove the containers (data volumes are kept) |
| `./l2server.sh restart game` | Restart a service, e.g. after editing `overrides/` |
| `./l2server.sh logs game` | Follow the logs of `db`, `login` or `game` |
| `./l2server.sh ps` | Container status |
| `./l2server.sh <server> [chronicle]` | Switch server (also `./l2server.sh server [name [chronicle]]`; without a name: list) |
| `./l2server.sh chronicle [name]` | List the chronicles or switch to one |
| `./l2server.sh update` | Move the server's source to the latest upstream commit |
| `./l2server.sh gm [<login> [level]]` | List characters and access levels, or make an account's characters GM |
| `./l2server.sh tools` | Start phpMyAdmin on http://localhost:8080 |
| `./l2server.sh help` | All commands |

## Connecting a client

A game client is not part of this project. Point your client of the selected chronicle to the login
server, `127.0.0.1:2106`, with a client protocol the server accepts (`./l2server.sh status` shows both). Log in
with any login and password; the account is created on first login. The login server then sends the
client to `EXTERNAL_HOST:7777`.

**GM:** log in, create a character, log out, run `./l2server.sh gm <login>` (the server's Master level), then
type `//admin` in the game chat.

## Configuration

- **`.env`** - server, chronicle, database credentials, `EXTERNAL_HOST`, ports, JVM options
  (the `COMPOSE_*` lines are maintained by `l2server.sh`). For players on other machines set `EXTERNAL_HOST` to
  the Docker host's LAN or public IP and open ports `2106` and `7777`.
- **`overrides/<server>/`** - your versions of the server's configuration files, copied over the defaults
  on every container start ([overrides/README.md](overrides/README.md)).
- **`geodata/<server>/`** - geodata region files (terrain, walls, line of sight), not part of the server
  repositories. Without them characters and monsters walk through walls; `./l2server.sh status` warns about it.

## More

- [docs/modifying.md](docs/modifying.md) - configuration and mods, your own Java changes, updating
- [docs/internals.md](docs/internals.md) - how servers, projects, volumes and sources are organised
- `servers/<server>/README.md` - server-specific details

## Credits and license

- Inspired by [stsourlidakis/l2jmobius-docker](https://github.com/stsourlidakis/l2jmobius-docker) (WTFPL),
  rewritten for the current L2jMobius layout and generalised to several server emulators.
- L2jMobius and L2J Server are licensed under the GNU GPL v3; see the upstream repositories. The public
  aCis repository ships no license file; see its project page.
- This repository's own files may be used under the same terms as the original (WTFPL).
