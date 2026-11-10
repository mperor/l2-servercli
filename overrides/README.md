# Overrides

Files here are copied over the chronicle's `dist/` directory every time a container starts,
so you can customise the server without touching the `l2j_mobius` submodule.

The layout mirrors `dist/<role>/`:

```
overrides/
  game/config/Rates.ini          -> dist/game/config/Rates.ini
  game/config/Custom/Banking.ini -> dist/game/config/Custom/Banking.ini
  game/config/ipconfig.xml       -> replaces the generated network config
  login/config/Server.ini        -> dist/login/config/Server.ini
```

Copy the original file from `l2j_mobius/<CHRONICLE>/dist/...`, edit it, then apply it with:

```
./l2.sh restart game
```

These settings are always set from `.env` and cannot be overridden here:
the database connection in `Database.ini`, `EnableGUI` in `Interface.ini`,
`LoginHost` (game) and `LoginHostname` (login) in `Server.ini`.
