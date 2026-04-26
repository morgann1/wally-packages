--!strict
-- Run the full lint/typecheck pipeline locally.
-- Run with: `lute run .lune/ci.luau`

local fs = require("@std/fs")
local io = require("@std/io")
local net = require("@std/net")
local process = require("@std/process")

local SOURCEMAP = "sourcemap.json"
local TYPES_DIR = ".ci"
local TYPES_PATH = `{TYPES_DIR}/globalTypes.d.luau`
local TYPES_URL = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"

local function run(program: string, args: { string }): number
	io.write(`\n$ {program} {table.concat(args, " ")}\n`)
	local cmd = { program }
	for _, a in args do
		table.insert(cmd, a)
	end
	local result = process.run(cmd, { stdio = "inherit" })
	return result.exitcode
end

local function ensureRobloxTypes()
	if fs.exists(TYPES_PATH) and fs.type(TYPES_PATH) == "file" then
		return
	end
	if not fs.exists(TYPES_DIR) then
		fs.createDirectory(TYPES_DIR, { makeParents = true })
	end
	io.write(`Fetching Roblox type definitions → {TYPES_PATH}\n`)
	local response = net.request(TYPES_URL)
	if not response.ok then
		io.write(`Failed to download {TYPES_URL}: status {response.status}\n`)
		process.exit(1)
	end
	fs.writeStringToFile(TYPES_PATH, response.body)
end

local steps: { { name: string, program: string, args: { string } } } = {
	{
		name = "sourcemap",
		program = "rojo",
		args = { "sourcemap", "-o", SOURCEMAP, "default.project.json" },
	},
	{
		name = "stylua",
		program = "stylua",
		args = { "--check", "modules", ".lune" },
	},
	{
		name = "selene",
		program = "selene",
		args = { "modules" },
	},
	{
		name = "luau-lsp",
		program = "luau-lsp",
		args = {
			"analyze",
			`--sourcemap={SOURCEMAP}`,
			"--base-luaurc=.luaurc",
			`--definitions={TYPES_PATH}`,
			"modules",
		},
	},
}

ensureRobloxTypes()

local failures: { string } = {}
for _, step in steps do
	local code = run(step.program, step.args)
	if code ~= 0 then
		table.insert(failures, `{step.name} (exit {code})`)
	end
end

io.write("\n")
if #failures > 0 then
	io.write(`CI failed: {table.concat(failures, ", ")}\n`)
	process.exit(1)
end
io.write("CI passed.\n")
