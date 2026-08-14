# Wally Packages

A monorepo of Luau packages published to the Wally registry (the UpliftGames
index) under the `morgann1/*` scope. Three trees of packages: `modules/` for
shared runtime libraries, `plugin/` for Studio plugin libraries, and `roblox/`
for Roblox's Foundation UI library and the parts of its dependency tree Roblox
does not publish, vendored from Studio builds.

This file is the canonical agent guide; `AGENTS.md` is a git symlink to it, so
edit `CLAUDE.md`. Think of everything below as good defaults, not hard rules;
the developer's word overrides any of it.

## A note from Morgan

Keep it simple, channel yagni. Understand the real constraint, then fight for
the smallest model that makes the correct behavior unsurprising. Do not
preserve complexity because it already exists, and do not add machinery
because it looks architecturally impressive. Single responsibility per module,
depend on abstractions, extend rather than modify. Comments describe how a
thing is used, not what the next line does.

## A small glossary

- **wally** - the package manager. `wally.toml` per package, installs into
  `Packages/` (gitignored), one registry: the UpliftGames wally-index.
- **rokit** - toolchain manager; every tool version is pinned in `rokit.toml`.
  Run tools from the repo root so the shims resolve.
- **rojo** - maps on-disk files to a Roblox instance tree via
  `default.project.json`, and generates `sourcemap.json` from it.
- **lute** - Luau script runner; all repo automation lives in `.lute/`.
- **linker / trampoline** - the `Packages/<Alias>.lua` file wally generates
  per dependency; a one-line require redirect into `Packages/_Index`.
  `wally-package-types` rewrites linkers to also re-export types.
- **rotriever** - Roblox's internal package manager; its layout is what the
  `roblox-packages` CLI extracts from a Studio build.
- **moonwave** - doc generator; CI publishes docs from `modules/` and
  `plugin/` doc comments on every push to main.

## The ways to hurt yourself

1. **`io.write` in lute scripts.** Under an agent harness it blocks for
   minutes per call and looks like a hang; `print()` is instant. The same
   goes for `process.run` with captured stdio on commands with large output
   (`wally package --list`): pass `{ stdio = "none" }` or `"inherit"`.
2. **Hand-editing generated files.** `default.project.json` and
   `test.project.json` are written by `.lute/sync-projects.luau`, the
   `roblox/` tree and `roblox.project.json` by
   `.lute/vendor-roblox-packages.luau`, and the README module table by
   `.lute/update-readme.luau`. Edit the generator, then regenerate.
3. **Publishing.** `wally publish` is permanent: no unpublish, versions are
   immutable. Never publish unless explicitly asked. The `roblox/` packages
   additionally carry a licensing caveat (see `roblox/README.md`) and a
   dependency-ordered publish list.
4. **Long paths.** `roblox-packages` downloads nest ~130 chars deep; from a
   long prefix they cross Windows' 260-char MAX_PATH and lute file reads
   fail. Download to a short path such as `$env:TEMP/rp-download`.
5. **Linting vendored code.** `roblox/` is deliberately excluded from StyLua
   (`.styluaignore`) and selene (`selene.toml`); it is Roblox's code at
   pinned versions, not ours to reformat.

## Where code lives

- `modules/<pkg>` and `plugin/<pkg>` - one Wally package per directory:
  `wally.toml` next to `init.luau`. Scope names areas of the repo.
- `roblox/<pkg>` - vendored Foundation tree, regenerated wholesale; see
  `roblox/README.md` for provenance and `.claude/skills/` for the procedure.
- `.lute/` - repo automation (see Workflows). `.lute/batteries/` holds small
  shared libraries like the TOML parser.
- `docs/` + `moonwave.toml` - moonwave site config; content comes from doc
  comments in package sources.
- `Packages/` - wally install output, gitignored, recreated any time.

## Workflows

- **New package**: `lute run .lute/scaffold.luau <slug> [--plugin]`, then
  `lute run .lute/sync-projects.luau` so the rojo tree and luau-lsp know it.
- **Dependencies changed**: rerun `.lute/sync-projects.luau`; it injects each
  package's deps as instance siblings so `require(script.Parent.<Alias>)`
  resolves in Studio and in the editor.
- **Foundation / Studio version bump**: follow
  `.claude/skills/vendor-roblox-packages/SKILL.md`; the script downloads,
  converts, wires, and validates end to end.
- **README module table**: `lute run .lute/update-readme.luau`.
- **Local CI**: `lute run .lute/ci.luau` runs the full lint/typecheck
  pipeline; `lute run .lute/build.luau` builds the place file.
- **Tests**: `lute run .lute/test.luau` builds a place from
  `test.project.json` and runs the Jest specs (`tests/{roblox,modules,plugin}/
  *.spec.luau`) in Studio via run-in-roblox. `tests/roblox` specs live
  outside `roblox/` because that tree is wiped on regeneration, and they
  test the conversion (requires resolve, ancestor re-casing, external
  substitutions hold), not upstream behavior — Roblox already tests its
  own libraries. `tests/modules` and `tests/plugin` test our packages'
  behavior; specs that need plugin-security APIs (StudioService) or
  client-only globals guard with `test.skip` so the suite still passes in
  other run contexts.
- **Publish** (only on request): `lute run .lute/publish.luau [--plugin]` for
  the main trees; `roblox/` packages follow
  `.claude/skills/publish-roblox-packages/SKILL.md` (dependency order, index
  collision pre-flight, size cap).

## Verifying

Smallest proof first: `lute check` (strict typecheck), `stylua --check`, and
`selene` on the files you touched; `wally package --project-path <pkg> --list`
proves a manifest; `rojo sourcemap default.project.json -o sourcemap.json`
proves the project tree. The vendor script runs its own validation chain.
Note the pinned StyLua/selene cannot parse Luau `const` yet, so repo scripts
stay `local`-only until those bump.

## Git

- Conventional commits, scope = repo area: `fix(plugin/leader): ...`,
  `feat(modules/wide-logger): ...`, `feat(roblox): ...`. Bodies open with the
  problem, close with what was verified. No attribution trailers.
- Stage explicitly; never `git add -A`.
- `core.symlinks` may be false on Windows clones, in which case `AGENTS.md`
  materializes as a text file containing `CLAUDE.md`; the repo object is a
  real symlink either way.
