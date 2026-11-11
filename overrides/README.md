# Overrides

Files here are copied over the server's `dist/` directory every time a container starts,
so you can customise the server without touching its submodule in `sources/`.

There is one directory per server (`SERVER` in `.env`); inside, the layout mirrors `dist/<role>/`.
For L2jMobius:

```
overrides/l2jmobius/
  game/config/Rates.ini          -> dist/game/config/Rates.ini
  game/config/Custom/Banking.ini -> dist/game/config/Custom/Banking.ini
  game/config/ipconfig.xml       -> replaces the generated network config
  login/config/Server.ini        -> dist/login/config/Server.ini
```

Copy the original file from `sources/l2j_mobius/<CHRONICLE>/dist/...`, edit it, then apply it with:

```
./l2.sh restart game
```

These L2jMobius settings are always set from `.env` and cannot be overridden here:
the database connection in `Database.ini`, `EnableGUI` in `Interface.ini`,
`LoginHost` (game) and `LoginHostname` (login) in `Server.ini`.

Overrides from before the multi-server layout (`overrides/game/`, `overrides/login/`) belong in
`overrides/l2jmobius/` now.
