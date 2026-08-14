---
name: publish-roblox-packages
description: Publish the vendored roblox/ packages to the Wally registry in dependency order, with index collision pre-flight and size-cap handling. Use when explicitly asked to publish the roblox/ tree, typically after a Foundation/Studio vendor bump.
---

# Publish the roblox/ packages

Publishes each `roblox/<pkg>` to the UpliftGames Wally index under
`morgann1/*`. Standing rules first:

- **Only on explicit request.** `wally publish` is permanent: no unpublish,
  versions are immutable.
- **Licensing caveat** in `roblox/README.md`: most of these are
  Roblox-authored sources without OSS licenses (only otter and dash have
  public MIT repos). Publishing is the developer's call, never yours.
- Dependencies before dependents. The safe order is the list in
  `roblox/README.md` under Publishing.

## Pre-flight

1. Auth: `~/.wally/auth.toml` must exist; otherwise ask the developer to run
   `wally login`.

2. Collect the tree's versions:

   ```
   for t in roblox/*/wally.toml; do grep -hE '^(name|version)' "$t"; done
   ```

3. Collect published versions per package (the index is a GitHub repo of
   newline-delimited JSON files):

   ```
   gh api "repos/UpliftGames/wally-index/contents/morgann1/<pkg>" \
     -H "Accept: application/vnd.github.raw" | grep -oE '"version":"[^"]+"'
   ```

   The scope carries **old junk versions** from early publish attempts
   (e.g. builder-icons 1.0.0, motion 1.0.0, lumberyak 1.0.0,
   foundation-cloud-assets 1.0.0). These are harmless as long as they fall
   outside the caret ranges the tree pins (`@0.1.32` means
   `>=0.1.32, <0.2.0`), which excludes a stray 1.0.0. Verify, don't assume.

4. **Exact version collision** → the publish will be rejected as a
   duplicate. Diff the published contents against the tree before deciding:

   ```
   curl -sL -H "Wally-Version: 0.3.2" -o pkg.zip \
     "https://api.wally.run/v1/package-contents/morgann1/<pkg>/<version>"
   unzip -q pkg.zip -d old && diff -r --strip-trailing-cr old roblox/<pkg>
   ```

   (Without the `Wally-Version` header the API returns 426.) Identical
   content → skip the package, dependents resolve to it correctly. As of
   Studio 0.716, `signal@1.0.0` is in this state. Different content → the
   version must change, which means fixing it in
   `.lute/vendor-roblox-packages.luau`, not hand-editing the tree.

## Publish

From the repo root (rokit shims only resolve inside the repo):

```
wally publish --project-path roblox/<pkg>
```

in the `roblox/README.md` order, skipping identical-collision packages.
Watch each result; a failed publish mid-list leaves dependents pinning a
version that does not exist yet.

**2MB size cap**: the registry rejects larger packages. foundation-images
trips this via its `SpriteSheets/*.png` (dead weight under Wally: only read
via `rbxasset://` paths when mounted under CorePackages; Wally consumers
always take the `FALLBACK_IMAGES` uploaded-asset branch). The fix is the
`PACKAGE_EXCLUDES` table in `.lute/vendor-roblox-packages.luau`, which
writes `exclude = [...]` into the generated manifest. Add new oversized
packages there, mirror the line into the generated `wally.toml`, and prove
it with `wally package --project-path roblox/<pkg> --list`.

## Verify

Prove the whole closure resolves with a scratch install (still run from the
repo root; `wally install` accepts an external project path):

```
printf '[package]\nname = "morgann1/smoke"\nversion = "0.1.0"\nregistry = "https://github.com/UpliftGames/wally-index"\nrealm = "shared"\n\n[dependencies]\nFoundation = "morgann1/foundation@<version>"\n' > <scratch>/wally.toml
wally install --project-path <scratch>
ls <scratch>/Packages/_Index
```

Every `morgann1/*` package should appear at the version the tree pins.
