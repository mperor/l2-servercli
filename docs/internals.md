# How it works

## Servers and projects

Each server is a directory `servers/<server>/`:

```
compose.yml     image, build, database name, SQL import and log paths of the server
provider.sh     sourced by l2server.sh: fetching the source, chronicles, client protocol, GM level
Dockerfile*     build -> runtime image
entrypoint.sh   applies overrides, sets the database/network settings, starts login|game in the foreground
initdb.sh       imports the server's SQL on the first database start
README.md       server-specific details
```

`docker-compose.yml` holds what all servers share (MariaDB, ports, overrides, geodata, phpMyAdmin); `l2server.sh`
merges the server's `compose.yml` over it by setting `COMPOSE_FILE` in `.env`, so plain `docker compose ...`
commands work as well.

Every server and chronicle is its own compose project, `l2server-<server>-<chronicle>` (`COMPOSE_PROJECT_NAME`
in `.env`, e.g. `l2server-acis-interlude`), with its own containers, network, database volume
(`<project>_db-data`) and game state volume (`<project>_game-state`, the game server's registration).
`./l2server.sh up` removes the containers of any other project first, since they use the same ports; their
volumes stay. `docker volume ls` lists them; delete one you no longer need with `docker volume rm <name>`.

## Sources

The server sources are git submodules in `sources/`, cloned shallow and blob-less on first use, L2jMobius
also sparse (one directory per chronicle). `l2server.sh` clones them itself instead of
`git submodule update --init`, which would download every chronicle. Nothing is written into a submodule:
configuration happens at container start.

## Earlier versions

All L2jMobius chronicles used to share one project `l2jmobius` with volumes `l2jmobius-db-<chronicle>` /
`l2jmobius-state-<chronicle>`. `./l2server.sh up` copies them once into the chronicle's new volumes; the old ones
are not touched and can be deleted afterwards.
