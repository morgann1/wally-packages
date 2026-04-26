--!strict
-- Publish every module under modules/ to the Wally registry.
-- Run with: `lute run .lute/publish.luau`

local fs = require("@std/fs")
local io = require("@std/io")
local process = require("@std/process")

local MODULES_DIR = "modules"

for _, entry in fs.listDirectory(MODULES_DIR) do
	if entry.type ~= "dir" then
		continue
	end
	local moduleDir = `{MODULES_DIR}/{entry.name}`
	io.write(`\n==> wally publish ({entry.name})\n`)
	local result = process.run({ "wally", "publish" }, {
		cwd = moduleDir,
		stdio = "inherit",
	})
	if not result.ok then
		process.exit(result.exitcode)
	end
end
