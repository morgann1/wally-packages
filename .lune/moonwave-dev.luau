--!strict
-- Start moonwave's dev server with the source paths this monorepo uses.
-- Moonwave's default `--code` is ["lib", "src"]; ours live under
-- `modules` and `plugin`, so the API tab is empty without these flags.
-- Run with: `lute run .lune/moonwave-dev.luau`

local io = require("@std/io")
local process = require("@std/process")
local system = require("@std/system")

local args = { "dev", "--code", "modules", "--code", "plugin" }
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
