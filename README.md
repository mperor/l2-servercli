# L2jMobius Docker

Run an [L2jMobius](https://l2jmobius.org/) server (any chronicle of the monorepo, e.g. C6 Interlude)
with a single command. The server source is pulled in as a git submodule from the official
[GitLab repository](https://gitlab.com/MobiusDevelopment/L2J_Mobius), built inside Docker (Java 27),
and started together with MariaDB.

## Requirements

- [Docker](https://docs.docker.com/get-docker/) with Compose v2 (Docker Desktop on Windows/macOS)
- Git (on Windows: [Git for Windows](https://git-scm.com/download/win), which also provides Git Bash)
- ~4 GB RAM for the game server (see `GAME_JAVA_OPTS` in `.env`)

## Quick start

```bash
git clone https://github.com/mperor/l2jmobius-docker.git
cd l2jmobius-docker
./l2.sh up          # Windows PowerShell: .\l2.ps1 up
```

On the first run `l2.sh`:

1. creates `.env` from `.env.example`,
2. clones the `l2j_mobius` submodule **shallow and sparse**, so only the selected chronicle
   is downloaded (~200 MB instead of the whole multi-chronicle repository),
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
| `./l2.sh chronicle [name]` | List available chronicles or switch to one |
| `./l2.sh update` | Move the submodule to the latest upstream `master` |
| `./l2.sh gm` | List characters with their access levels |
| `./l2.sh gm <login> [level]` | Set the access level of an account's characters (default `100` = Master) |
| `./l2.sh tools` | Start phpMyAdmin on http://localhost:8080 |

## Chronicles

Any `L2J_Mobius_*` directory of the upstream repository can be selected. `./l2.sh chronicle` lists
them all; switch with `./l2.sh chronicle <name>` (stops the running one, then run `./l2.sh up`).
Only the selected chronicle is downloaded.

The default, used as the example throughout this README, is `L2J_Mobius_CT_0_Interlude`.
Each chronicle gets its own image tag (`l2jmobius:<chronicle>`) and its own database volume
(`l2jmobius-db-<chronicle>`), so switching back and forth keeps characters intact.

## Connecting a client

A game client is not included; use your own client of the selected chronicle.

1. **Matching protocol.** The game server accepts only the protocol revision in the chronicle's
   `dist/game/config/Server.ini` (`AllowedProtocolRevisions`; e.g. `746` for Interlude, `419` for C1).
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
2. `./l2.sh gm <login>` sets level `100` (Master) on all characters of the account; levels are defined
   in `dist/game/config/AccessLevels.xml`.
3. Check with `./l2.sh gm` (lists characters and levels), then log in and type `//admin` in the chat.
   GMs start invisible and invulnerable (`GMStartup*` in `General.ini`); `//visible` shows you to others.

The bundled `AccountManager` cannot be used: it opens a Swing window even in console mode, which fails
in a container without a display.

## Configuration

- **`.env`** - chronicle, database credentials, `EXTERNAL_HOST`, ports, JVM options.
- **`overrides/`** - your own versions of any file under `dist/game` or `dist/login`
  (e.g. `overrides/game/config/Rates.ini`). They are copied over the defaults on every container
  start, so no rebuild is needed. See [overrides/README.md](overrides/README.md).

### Playing from other machines

Set `EXTERNAL_HOST` in `.env` to the LAN or public IP of the Docker host and run `./l2.sh up`.
For mixed local/LAN/internet setups put your own `ipconfig.xml` in `overrides/game/config/`.
Ports `2106` and `7777` must be reachable.

## Project layout

```
docker/Dockerfile     multi-stage build: Ant + JDK 27 -> runtime image with dist/
docker/entrypoint.sh  applies overrides, sets DB/network settings, starts login|game
docker/initdb.sh      imports dist/db_installer/sql on the first database start
docker-compose.yml    db, login, game (+ phpmyadmin with the "tools" profile)
l2.sh / l2.ps1        the single entry point
l2j_mobius/           submodule: MobiusDevelopment/L2J_Mobius (sparse checkout)
overrides/            your config overrides
data/logs/            server logs (git-ignored)
```

## Updating L2jMobius

```bash
./l2.sh update
./l2.sh up
git add l2j_mobius && git commit -m "Update L2J_Mobius"
```

The submodule commit recorded in this repository is what everybody cloning it will build,
so updates are explicit and reproducible.

## Modifying the server source

The submodule points to the upstream GitLab repository. To keep your own Java changes,
mirror it to a repository you own and switch the submodule URL:

```bash
gh repo create <you>/L2J_Mobius --private
git -C l2j_mobius remote add mine https://github.com/<you>/L2J_Mobius.git
git -C l2j_mobius fetch --unshallow origin master
git -C l2j_mobius push mine HEAD:refs/heads/master
git submodule set-url l2j_mobius https://github.com/<you>/L2J_Mobius.git
```

GitHub does not charge for repository storage (private repositories included); just keep within
GitHub's limits (no single file over 100 MB, repository ideally under a few GB).
Merge upstream changes into your mirror from time to time.

## Credits and license

- Inspired by [stsourlidakis/l2jmobius-docker](https://github.com/stsourlidakis/l2jmobius-docker) (WTFPL),
  rewritten for the current L2jMobius layout (`Database.ini`, Java 27, multi-chronicle monorepo).
- L2jMobius is licensed under the GNU GPL v3; see the upstream repository.
- This repository's own files may be used under the same terms as the original (WTFPL).
