--!strict
-- Build the moonwave docs site for publishing, with this monorepo's
-- source paths. Pass `--publish` to deploy to the `gh-pages` branch.
-- Run with: `lune run moonwave-build [--publish]`

local process = require("@lune/process")
local stdio = require("@lune/stdio")

local args = { "build", "--code", "modules", "--code", "plugin" }
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
