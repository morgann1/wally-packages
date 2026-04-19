--!strict
-- Generate sourcemap and build the place file.
-- Run with: `lune run build`

local process = require("@lune/process")
local stdio = require("@lune/stdio")

local function run(program: string, args: { string })
	stdio.write(`$ {program} {table.concat(args, " ")}\n`)
	local result = process.exec(program, args, { stdio = "forward" })
	if not result.ok then
		process.exit(result.code)
	end
end

run("rojo", { "sourcemap", "-o", "sourcemap.json", "default.project.json" })
run("rojo", { "build", "-o", "place.rbxl" })
