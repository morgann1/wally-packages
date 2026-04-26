---
sidebar_position: 1
---

# Introduction

`wally-packages` is a collection of Roblox Luau modules that I maintain for
both plugin and game development. Each package is published to the
[Wally registry](https://wally.run) under the `morgann1` scope and ships
with its own API documentation generated from in-source comments.

## Categories

The packages are split into two top-level groups:

- **Modules** — runtime libraries for Roblox experiences (immutable data,
  player utilities, type validation, decompression, and more).
- **Plugin Libraries** — helpers built specifically for Roblox Studio
  plugins.

Browse the **API** tab in the navigation bar for the full list, or jump
straight to a package via its sidebar entry.

## Installing

Add the packages you need to your `wally.toml`:

```toml
[dependencies]
Cryo = "morgann1/cryo@1.1.1"
SimpleLogger = "morgann1/simple-logger@0.1.2"
```

Then run `wally install` to fetch them into your project.
