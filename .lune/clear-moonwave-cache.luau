--!strict
-- Wipe moonwave's per-project cache so the next `moonwave dev` rebuilds
-- from the current repo state. Useful after renaming or removing folders
-- under `docs/`, since moonwave's cache layer doesn't reconcile deletions.
-- Run with: `lune run clear-moonwave-cache`

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local PROJECT_NAME = "wally-packages"

local localAppData = process.env.LOCALAPPDATA
if not localAppData or localAppData == "" then
	stdio.ewrite("error: LOCALAPPDATA is not set; this script targets Windows\n")
	process.exit(1)
end

local cachePath = `{localAppData}/moonwave/Cache/{PROJECT_NAME}`

if not fs.isDir(cachePath) then
	stdio.write(`nothing to clear: {cachePath} does not exist\n`)
	process.exit(0)
end

local ok, err = pcall(fs.removeDir, cachePath)
if not ok then
	stdio.ewrite(`error: failed to remove {cachePath}: {err}\n`)
	stdio.ewrite("hint: stop `moonwave dev` first if it's running — it locks files in the cache\n")
	process.exit(1)
end

stdio.write(`cleared {cachePath}\n`)
