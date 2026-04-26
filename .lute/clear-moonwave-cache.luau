--!strict
-- Wipe moonwave's per-project cache so the next `moonwave dev` rebuilds
-- from the current repo state. Useful after renaming or removing folders
-- under `docs/`, since moonwave's cache layer doesn't reconcile deletions.
-- Run with: `lute run .lute/clear-moonwave-cache.luau`

local fs = require("@std/fs")
local io = require("@std/io")
local process = require("@std/process")

local PROJECT_NAME = "wally-packages"

local localAppData = process.env.LOCALAPPDATA
if not localAppData or localAppData == "" then
	io.write("error: LOCALAPPDATA is not set; this script targets Windows\n")
	process.exit(1)
end

local cachePath = `{localAppData}/moonwave/Cache/{PROJECT_NAME}`

if not fs.exists(cachePath) then
	io.write(`nothing to clear: {cachePath} does not exist\n`)
	process.exit(0)
end

local ok, err = pcall(fs.removeDirectory, cachePath, { recursive = true })
if not ok then
	io.write(`error: failed to remove {cachePath}: {err}\n`)
	io.write("hint: stop `moonwave dev` first if it's running — it locks files in the cache\n")
	process.exit(1)
end

io.write(`cleared {cachePath}\n`)
