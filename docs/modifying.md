# Modifying a server

## Configuration and mods

Most changes need no code: rates, mods and other settings are configuration files, which you override in
`overrides/<server>/{game,login}/` (copied over the server's files on every container start, see
[overrides/README.md](../overrides/README.md)) and apply with `./l2server.sh restart game`. The server pages in
`servers/<server>/README.md` say where the original files are.

## Java changes

The submodules in `sources/` point to the upstream repositories. To keep your own Java changes, mirror the
server's repository to one you own and switch the submodule URL, e.g. for L2jMobius:

```bash
gh repo create <you>/L2J_Mobius --private
git -C sources/l2j_mobius remote add mine https://github.com/<you>/L2J_Mobius.git
git -C sources/l2j_mobius fetch --unshallow origin master
git -C sources/l2j_mobius push mine HEAD:refs/heads/master
git submodule set-url sources/l2j_mobius https://github.com/<you>/L2J_Mobius.git
```

The same works for `sources/acis` and the L2J Server submodules in `sources/l2j/` (one repository each for
login, game and datapack). Commit your changes in the submodule, push them to your mirror and record the new
submodule commit in this repository. Merge upstream changes into your mirror from time to time.

GitHub does not charge for repository storage (private repositories included); just keep within GitHub's
limits (no single file over 100 MB, repository ideally under a few GB).

## Updating to upstream

```bash
./l2server.sh update
./l2server.sh up
git add sources/<...> && git commit -m "Update <server>"
```

The submodule commits recorded in this repository are what everybody cloning it builds, so updates are
explicit and reproducible.
