# L2jMobius Docker

Run an [L2jMobius](https://l2jmobius.org/) server (C1 Harbingers of War, C4 Scions of Destiny, C6 Interlude)
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
Point your client to `127.0.0.1` (login port `2106`). Accounts are created automatically on first login
(`AutoCreateAccounts = True`).

## Commands

| Command | Description |
|---|---|
| `./l2.sh up` | Prepare submodule and `.env`, build and start (default command) |
| `./l2.sh down` | Stop containers (database volume is kept) |
| `./l2.sh restart game` | Restart a service, e.g. after editing `overrides/` |
| `./l2.sh logs game` | Follow logs of `db`, `login` or `game` |
| `./l2.sh ps` | Container status |
| `./l2.sh chronicle [name]` | Show or switch the chronicle |
| `./l2.sh update` | Move the submodule to the latest upstream `master` |
| `./l2.sh account` | Interactive AccountManager (e.g. to set access level) |
| `./l2.sh tools` | Start phpMyAdmin on http://localhost:8080 |

## Chronicles

Set with `./l2.sh chronicle <name>` (stops the running one, then run `./l2.sh up`):

- `L2J_Mobius_C1_HarbingersOfWar`
- `L2J_Mobius_C4_ScionsOfDestiny`
- `L2J_Mobius_CT_0_Interlude` (default)

Each chronicle gets its own image tag (`l2jmobius:<chronicle>`) and its own database volume
(`l2jmobius-db-<chronicle>`), so switching back and forth keeps characters intact.
Other chronicles from the upstream repository may work too, but they are not tested here.

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
