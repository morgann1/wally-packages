# Contributing

## Setup

Tools are pinned in `rokit.toml` and resolved through [rokit](https://github.com/rojo-rbx/rokit) shims, so run everything from the repo root.

```sh
rokit install
wally install
lute run .lute/sync-projects.luau
```

`sync-projects` writes `default.project.json` and `test.project.json`, which give luau-lsp and the test place an instance tree where every package's wally dependencies resolve.

## Layout

- `modules/` shared runtime libraries, one Wally package per directory (`wally.toml` next to `init.luau`).
- `plugin/` Roblox Studio plugin libraries, same shape.
- `roblox/` Roblox's Foundation UI library and its unpublished dependencies, vendored from Studio builds. Regenerated wholesale by `.lute/vendor-roblox-packages.luau`; never edit it by hand, and note the licensing caveat in [roblox/README.md](roblox/README.md).
- `.lute/` repo automation scripts.
- `tests/` Jest specs, split into `roblox/` (vendoring conversion), `modules/` and `plugin/` (package behavior).

## Making changes

- New package: `lute run .lute/scaffold.luau <slug> [--plugin]`, then `lute run .lute/sync-projects.luau`.
- Changed a package's dependencies: rerun `sync-projects`.
- Generated files (`default.project.json`, `test.project.json`, the README package tables, everything under `roblox/`): edit the generator in `.lute/`, then regenerate. Hand edits get overwritten.
- Public APIs carry moonwave doc comments; CI publishes the [docs site](https://morgann1.github.io/wally-packages/) from them on every push to `main`.

## Checks

```sh
lute run .lute/ci.luau    # stylua, selene, luau-lsp analyze
lute run .lute/test.luau  # builds the test place and runs the Jest specs
```

Tests need a local Roblox Studio install; the place is built from `test.project.json` and run through run-in-roblox. `roblox/` is deliberately excluded from StyLua and selene; it is Roblox's code at pinned versions.

## Commits

Conventional commits with the repo area as scope, e.g. `fix(plugin/leader): ...`, `feat(modules/wide-logger): ...`, `feat(roblox): ...`. Open the body with the problem, close with what was verified. Stage files explicitly.

## Publishing

Maintainers only. `wally publish` is permanent: versions are immutable and cannot be unpublished. `modules/` and `plugin/` go out through `lute run .lute/publish.luau [--plugin]`; `roblox/` packages are published individually in the dependency order listed in [roblox/README.md](roblox/README.md).
