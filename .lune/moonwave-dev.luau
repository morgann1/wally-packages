--!strict
-- Start moonwave's dev server with the source paths this monorepo uses.
-- Moonwave's default `--code` is ["lib", "src"]; ours live under
-- `modules` and `plugin`, so the API tab is empty without these flags.
-- Run with: `lune run moonwave-dev`

local process = require("@lune/process")
local stdio = require("@lune/stdio")

local args = { "dev", "--code", "modules", "--code", "plugin" }
for _, arg in process.args do
	if arg ~= "--" then
		table.insert(args, arg)
	end
end

local program = if process.os == "windows" then "moonwave.cmd" else "moonwave"
stdio.write(`$ {program} {table.concat(args, " ")}\n`)
local result = process.exec(program, args, { stdio = "forward" })
if not result.ok then
	process.exit(result.code)
end
