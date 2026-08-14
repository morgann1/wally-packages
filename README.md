<h1 align="center">
  Wally Packages
</h1>

<div align="center">

  [![Docs](.github/assets/link-docs.svg)](https://morgann1.github.io/wally-packages/)
</div>

Luau packages published to the [Wally](https://wally.run) registry (UpliftGames index) under the `morgann1/*` scope.

## Modules

Shared runtime libraries.

<!-- modules-table:start -->
| Package                                                                                                            | Dependency                                                              | Description                                                                                          |
| ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| [bindToInstanceDestroyed](https://github.com/morgann1/wally-packages/tree/main/modules/bind-to-instance-destroyed) | `bindToInstanceDestroyed = "morgann1/bind-to-instance-destroyed@0.1.1"` | A reliable way to execute cleanup code when an instance is destroyed.                                |
| [CharacterPromiseUtils](https://github.com/morgann1/wally-packages/tree/main/modules/character-promise-utils)      | `CharacterPromiseUtils = "morgann1/character-promise-utils@0.1.1"`      | Wally port of Quenty's CharacterPromiseUtils.lua                                                     |
| [Cryo](https://github.com/morgann1/wally-packages/tree/main/modules/cryo)                                          | `Cryo = "morgann1/cryo@1.1.1"`                                          | A collection of methods for working with immutable data in a functional way.                         |
| [disconnectAndClear](https://github.com/morgann1/wally-packages/tree/main/modules/disconnect-and-clear)            | `disconnectAndClear = "morgann1/disconnect-and-clear@0.1.1"`            | Utility function that disconnects all given RBXScriptConnection objects and then clears the table.   |
| [IasWrapper](https://github.com/morgann1/wally-packages/tree/main/modules/ias-wrapper)                             | `IasWrapper = "morgann1/ias-wrapper@0.1.1"`                             | Port of the [upstream source](https://gist.github.com/alicesaidhi/383b04a42cad53acb27e017f50fd8086). |
| [safePlayerAdded](https://github.com/morgann1/wally-packages/tree/main/modules/safe-player-added)                  | `safePlayerAdded = "morgann1/safe-player-added@0.1.1"`                  | Utility function that runs a callback for all current players and connects it for future ones.       |
| [SimpleLogger](https://github.com/morgann1/wally-packages/tree/main/modules/simple-logger)                         | `SimpleLogger = "morgann1/simple-logger@0.1.2"`                         | Simple logging utility                                                                               |
| [TypeValidation](https://github.com/morgann1/wally-packages/tree/main/modules/type-validation)                     | `TypeValidation = "morgann1/type-validation@1.0.3"`                     | Runtime type validation                                                                              |
| [WideLogger](https://github.com/morgann1/wally-packages/tree/main/modules/wide-logger)                             | `WideLogger = "morgann1/wide-logger@0.1.0"`                             | Logger based on loggingsucks.com                                                                     |
| [zzlib](https://github.com/morgann1/wally-packages/tree/main/modules/zzlib)                                        | `zzlib = "morgann1/zzlib@0.1.1"`                                        | zlib decompression in Lua                                                                            |
<!-- modules-table:end -->

## Plugin

Libraries for Roblox Studio plugins.

<!-- plugin-table:start -->
| Package                                                                                         | Dependency                                            | Description                                                                                                         |
| ----------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| [doCleanup](https://github.com/morgann1/wally-packages/tree/main/plugin/do-cleanup)             | `doCleanup = "morgann1/do-cleanup@0.1.0"`             | Port of the [upstream source](https://github.com/Elttob/LibOpen/tree/main/LibOpen/doCleanup).                       |
| [ElttobLog](https://github.com/morgann1/wally-packages/tree/main/plugin/elttob-log)             | `ElttobLog = "morgann1/elttob-log@0.1.0"`             | Port of the [upstream source](https://github.com/Elttob/LibStudioElttob/tree/main/LibStudioElttob/Log).             |
| [Event](https://github.com/morgann1/wally-packages/tree/main/plugin/event)                      | `Event = "morgann1/event@0.1.0"`                      | Port of the [upstream source](https://github.com/Elttob/LibOpen/tree/main/LibOpen/Event).                           |
| [FinallyTask](https://github.com/morgann1/wally-packages/tree/main/plugin/finally-task)         | `FinallyTask = "morgann1/finally-task@0.1.0"`         | Port of the [upstream source](https://github.com/Elttob/LibOpen/tree/main/LibOpen/FinallyTask).                     |
| [IconRamp](https://github.com/morgann1/wally-packages/tree/main/plugin/icon-ramp)               | `IconRamp = "morgann1/icon-ramp@0.1.0"`               | Port of the [upstream source](https://github.com/Elttob/LibStudioElttob/tree/main/LibStudioElttob/IconRamp).        |
| [Interposer](https://github.com/morgann1/wally-packages/tree/main/plugin/interposer)            | `Interposer = "morgann1/interposer@0.1.1"`            | Port of the [upstream source](https://github.com/Elttob/LibStudioElttob/tree/main/LibStudioElttob/Interposer).      |
| [isLocalDev](https://github.com/morgann1/wally-packages/tree/main/plugin/is-local-dev)          | `isLocalDev = "morgann1/plugin-is-local-dev@0.1.1"`   | Port of the [upstream source](https://github.com/Elttob/LibStudioElttob/tree/main/LibStudioElttob/IsLocalDev).      |
| [Leader](https://github.com/morgann1/wally-packages/tree/main/plugin/leader)                    | `Leader = "morgann1/leader@0.1.3"`                    | Port of the [upstream source](https://github.com/Elttob/LibStudioElttob/tree/main/LibStudioElttob/Leader).          |
| [Maybe](https://github.com/morgann1/wally-packages/tree/main/plugin/maybe)                      | `Maybe = "morgann1/maybe@0.1.0"`                      | Port of the [upstream source](https://github.com/Elttob/LibOpen/tree/main/LibOpen/Maybe).                           |
| [OwnedToolbar](https://github.com/morgann1/wally-packages/tree/main/plugin/owned-toolbar)       | `OwnedToolbar = "morgann1/owned-toolbar@0.1.0"`       | Port of the [upstream source](https://github.com/Elttob/LibStudioElttob/tree/main/LibStudioElttob/OwnedToolbar).    |
| [PushPull](https://github.com/morgann1/wally-packages/tree/main/plugin/push-pull)               | `PushPull = "morgann1/push-pull@0.1.0"`               | Port of the [upstream source](https://github.com/Elttob/LibOpen/tree/main/LibOpen/PushPull).                        |
| [SensationSounds](https://github.com/morgann1/wally-packages/tree/main/plugin/sensation-sounds) | `SensationSounds = "morgann1/sensation-sounds@0.1.1"` | Port of the [upstream source](https://github.com/Elttob/LibStudioElttob/tree/main/LibStudioElttob/SensationSounds). |
| [SharedToolbar](https://github.com/morgann1/wally-packages/tree/main/plugin/shared-toolbar)     | `SharedToolbar = "morgann1/shared-toolbar@0.3.4"`     | Port of the [upstream source](https://github.com/Elttob/LibStudioElttob/tree/main/LibStudioElttob/SharedToolbar).   |
| [sortingBy](https://github.com/morgann1/wally-packages/tree/main/plugin/sorting-by)             | `sortingBy = "morgann1/sorting-by@0.1.0"`             | Port of the [upstream source](https://github.com/Elttob/LibOpen/tree/main/LibOpen/sortingBy).                       |
| [ty](https://github.com/morgann1/wally-packages/tree/main/plugin/ty)                            | `ty = "morgann1/ty@0.1.0"`                            | Port of the [upstream source](https://github.com/Elttob/LibOpen/tree/main/LibOpen/ty).                              |
<!-- plugin-table:end -->

## Roblox

`roblox/` vendors Roblox's Foundation UI library and the parts of its dependency tree Roblox does not publish, extracted from Studio builds. See [roblox/README.md](roblox/README.md) for provenance, the licensing caveat, and the publish order.
