# roblox

Roblox-authored packages that are not yet available on Wally (Foundation and
the parts of its dependency tree Roblox does not publish), vendored here and
publishable under `morgann1/*`.

## Provenance

Extracted from Roblox Studio `0.716.0.7160873` with
[roblox-packages](https://github.com/flipbook-labs/roblox-packages) (pinned in
`rokit.toml`), then restructured into Wally packages by
`.lute/vendor-roblox-packages.luau`: each package's rotriever dependency
linkers are expressed as Wally dependencies whose aliases match the
`require(script.Parent.<Alias>)` names the source uses. Sources are copied
as-is apart from two mechanical transforms: `.lua` renamed to `.luau`, and
`FindFirstAncestor("<PascalCase>")` package names re-cased to the kebab
instance names the wally-installed layout has (449 sites; rotriever's
PascalCase directories made those lookups return nil under Wally).

Everything Roblox already publishes on Wally is depended on instead of
vendored: the React 17.3 family (`roblox/react`, `react-is`, `react-roblox`,
`roact-compat`, ...), the LuauPolyfill family, `roblox/promise`, and
`roblox/safe-flags`. `Cryo` resolves to `morgann1/cryo` (from `modules/cryo`).
`signal` stays vendored because `roblox/signals` on Wally is a different
package (0.x) than the internal `Signal 1.0.0`.

Deliberate deviations from Roblox's lockfile, found by auditing actual
`require` calls: `motion` drops its unused `RoactCompat`/`tutils` deps and
`rbx-design-foundations` drops its unused `t` dep. React deps resolve to
17.3.9+ instead of the extracted 17.3.8, which Wally's semver would do anyway.

## Updating

Re-download at a newer Studio version and rebuild each package directory from
`<tmp>/Packages/_Index` the same way (source dir copied as-is, `wally.toml`
deps from the linker files, Wally-published deps mapped per above):

```
roblox-packages install <tmp> --version <pin> -d Foundation
```

## Publishing

Publish dependencies before dependents. A safe order: builder-icons, dash,
foundation-cloud-assets, rbx-design-foundations, signal, lumberyak,
foundation-images, otter, react-otter, motion, react-utils, usage-tracker,
foundation.

Note: these are Roblox-authored sources without OSS licenses (Roblox publishes
its own Wally packages under "SEE LICENSE IN LICENSE"). Publishing to the
public index is your call.
