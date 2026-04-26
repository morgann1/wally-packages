--!strict
-- Build the moonwave docs site for publishing, with this monorepo's
-- source paths. Pass `--publish` to deploy to the `gh-pages` branch.
-- Run with: `lute run .lune/moonwave-build.luau [--publish]`

local io = require("@std/io")
local process = require("@std/process")
local system = require("@std/system")

local args = { "build", "--code", "modules", "--code", "plugin" }
for _, arg in process.args do
	if arg ~= "--" then
		table.insert(args, arg)
	end
end

local program = if system.win32 then "moonwave.cmd" else "moonwave"
local cmd = { program }
for _, a in args do
	table.insert(cmd, a)
end
io.write(`$ {program} {table.concat(args, " ")}\n`)
local result = process.run(cmd, { stdio = "inherit" })
if not result.ok then
	process.exit(result.exitcode)
end
