--!strict
-- Publish every module under modules/ to the Wally registry.
-- Run with: `lune run publish`

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local MODULES_DIR = "modules"

for _, slug in fs.readDir(MODULES_DIR) do
	local moduleDir = `{MODULES_DIR}/{slug}`
	if not fs.isDir(moduleDir) then
		continue
	end
	stdio.write(`\n==> wally publish ({slug})\n`)
	local result = process.exec("wally", { "publish" }, {
		cwd = moduleDir,
		stdio = "forward",
	})
	if not result.ok then
		process.exit(result.code)
	end
end
