---
name: vendor-roblox-packages
description: Regenerate the roblox/ directory by vendoring Roblox's Foundation (and deps) from a Studio build as Wally packages. Use when updating Foundation to a new Studio version, re-vendoring roblox-packages output, or adding another Roblox-internal package to roblox/.
---

# Vendor roblox-packages as Wally packages

Converts a [roblox-packages](https://github.com/flipbook-labs/roblox-packages)
download (Roblox's internal rotriever packages, extracted from a Studio build)
into publishable Wally packages under `roblox/`. The rotriever layout is
mechanically identical to Wally's (`_Index` dirs, sibling linkers, sources
requiring deps via `require(script.Parent.<Alias>)`), so sources are copied
unchanged and only the dependency metadata is translated.

## Procedure

1. Pick the Studio pin: `roblox-packages list | tail -1` for the latest, or
   match the pin a consuming project uses (studio-discover pins one in its
   `.lute/lib/install/init.luau`).

2. Download (run from the repo root so the rokit shim resolves). Use a SHORT
   temp path, e.g. `$env:TEMP/rp-download` — Foundation's deepest files sit
   ~130 chars below the download root, and a long prefix pushes them past
   Windows' 260-char MAX_PATH, which lute's file reads do not survive:

   ```
   roblox-packages install $env:TEMP/rp-download --version <pin> -d Foundation
   ```

3. Convert (wipes and regenerates every package dir under `roblox/`):

   ```
   lute run .lute/vendor-roblox-packages.luau <scratch>/rp-download <pin>
   ```

   Extra positional args after the pin override the default `Foundation` root.

4. Review the script's output:
   - `note: ... pruned` lines are declared-but-never-required deps (audited
     against actual `require` calls). Expected from past runs: motion's
     RoactCompat/tutils, rbx-design-foundations' t.
   - `external:` lists what resolved to already-published Wally packages
     instead of being vendored.
   - Any `WARNING` or `FAIL` needs investigation before committing.

5. Update `roblox/README.md`: the Studio pin, and the publish order if the
   package set changed (the script prints the topological order).

6. Editor wiring is mostly automatic: the script regenerates
   `roblox.project.json` (mounted by `default.project.json` at
   `ReplicatedStorage.RobloxPackages`), runs `wally install` to regenerate
   pristine linkers (wally-package-types cannot re-parse already-patched
   ones), builds the sourcemap with `rojo`, and runs `wally-package-types` so
   the linkers re-export types (otherwise `React.ReactElement` etc. are
   unknown to luau-lsp). The one manual piece is the root `wally.toml`: each
   external `roblox/*` requirement needs an aliased dep there so its
   `Packages/<Alias>.lua` linker exists — the script prints a WARNING naming
   any that are missing; add the alias and re-run the script.

7. Run the Jest suite: `lute run .lute/test.luau` (builds a place and runs
   it in Studio via run-in-roblox). The specs in `tests/roblox/` require
   every vendored package and mount Foundation, which is the real proof the
   conversion holds; regeneration is not done until this is green.

8. Regenerate the docs pages: `lute run .lute/sync-foundation-docs.luau`
   rebuilds `docs/foundation/` from the tree's `*.code.md` files.

9. `git diff` the regenerated tree; commit only when asked.

10. Publishing (only on request): `wally publish --project-path roblox/<pkg>`
    in the printed order, dependencies before dependents; the full
    procedure (index pre-flight, size cap) is the publish-roblox-packages
    skill. Licensing is the user's call — these are Roblox-authored sources
    without OSS licenses.

## Judgment calls the script automates (and their limits)

- **Vendor vs. external.** A package becomes an external dep when a
  compatible version (same major, or same minor for 0.x, at or above the
  extracted version) is published either from this repo (`modules/`,
  `plugin/`) or under the `roblox/` Wally scope. Roblox publishes the React
  17.3 family, the LuauPolyfill family, promise, and safe-flags there.
- **Identity, not name.** A same-named Wally package is not necessarily the
  same library: `roblox/signals` (0.x) is NOT the internal `Signal` (1.0.0),
  so Signal is hardcoded NEVER_EXTERNAL. When the script starts externalizing
  a package that a previous run vendored, verify the Wally package is really
  the same code before trusting it, and extend NEVER_EXTERNAL if not.
- **React must be shared.** Foundation's React deps resolve to the official
  `roblox/react` on Wally. Consumers must use `roblox/react` /
  `roblox/react-roblox` for their own UI too, or they get two React instances
  and broken contexts across the Foundation boundary.
- **Multiple downloaded versions** of one package collapse to the highest
  (the download can contain e.g. Motion 0.0.7 and 0.1.0; Foundation uses the
  newer one).
- **FindFirstAncestor re-casing.** Rotriever's directories are PascalCase but
  wally installs content under the kebab package name, so ancestor lookups
  like `FindFirstAncestor("Foundation")` are rewritten to the kebab name
  during copy. Only names of vendored packages are rewritten — internal
  folders (`Sheet`, `Providers`) and engine guards (`CorePackages`) are not.
  A package's self-reference through its packages folder
  (`Packages.Foundation.Enums...`) is re-cased too — there is no alias
  linker for yourself — but dependency accesses (`Packages.Dash`) stay
  alias-named.
- **roblox/_linkers/ is generated indirection.** In the editor/test tree,
  every dependency mounts through a linker file so each package instance
  lives once under its own kebab folder (alias-named direct mounts break
  re-cased ancestor lookups) and externals resolve through the single shared
  `ReplicatedStorage.Packages` (per-folder `_Index` copies duplicate module
  instances — two Reacts, broken hooks).
