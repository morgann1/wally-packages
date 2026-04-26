--!strict
-- Generate sourcemap and build the place file.
-- Run with: `lute run .lune/build.luau`

local io = require("@std/io")
local process = require("@std/process")

local function run(program: string, args: { string })
	io.write(`$ {program} {table.concat(args, " ")}\n`)
	local cmd = { program }
	for _, a in args do
		table.insert(cmd, a)
	end
	local result = process.run(cmd, { stdio = "inherit" })
	if not result.ok then
		process.exit(result.exitcode)
	end
end

run("rojo", { "sourcemap", "-o", "sourcemap.json", "default.project.json" })
run("rojo", { "build", "-o", "place.rbxl" })
