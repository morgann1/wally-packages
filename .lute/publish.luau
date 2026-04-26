--!strict
-- Publish every package under modules/ (default) or plugin/ to the
-- Wally registry. Pass `--plugin` to publish from plugin/ instead.
-- Run with: `lute run .lute/publish.luau [--plugin]`

local fs = require("@std/fs")
local io = require("@std/io")
local process = require("@std/process")

-- Lute's `process.args[1]` is the script path itself; user-supplied
-- arguments start at index 2.
local isPlugin = false
for i = 2, #process.args do
	local arg = process.args[i]
	if arg == "--plugin" or arg == "-p" then
		isPlugin = true
	elseif arg == "--modules" or arg == "-m" then
		isPlugin = false
	else
		io.write(`error: unknown argument "{arg}"\n`)
		io.write("usage: lute run .lute/publish.luau [--plugin]\n")
		process.exit(1)
	end
end

local rootDir = if isPlugin then "plugin" else "modules"

if not (fs.exists(rootDir) and fs.type(rootDir) == "dir") then
	io.write(`error: {rootDir}/ does not exist\n`)
	process.exit(1)
end

for _, entry in fs.listDirectory(rootDir) do
	if entry.type ~= "dir" then
		continue
	end
	local packageDir = `{rootDir}/{entry.name}`
	io.write(`\n==> wally publish ({rootDir}/{entry.name})\n`)
	local result = process.run({ "wally", "publish" }, {
		cwd = packageDir,
		stdio = "inherit",
	})
	if not result.ok then
		process.exit(result.exitcode)
	end
end
