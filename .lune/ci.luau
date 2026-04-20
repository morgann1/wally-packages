--!strict
-- Run the full lint/typecheck pipeline locally.
-- Run with: `lune run ci`

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local SOURCEMAP = "sourcemap.json"
local TYPES_DIR = ".ci"
local TYPES_PATH = `{TYPES_DIR}/globalTypes.d.luau`
local TYPES_URL = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"

local function run(program: string, args: { string }): number
	stdio.write(`\n$ {program} {table.concat(args, " ")}\n`)
	local result = process.exec(program, args, { stdio = "forward" })
	return result.code
end

local function ensureRobloxTypes()
	if fs.isFile(TYPES_PATH) then
		return
	end
	if not fs.isDir(TYPES_DIR) then
		fs.writeDir(TYPES_DIR)
	end
	stdio.write(`Fetching Roblox type definitions → {TYPES_PATH}\n`)
	local response = net.request({ url = TYPES_URL })
	if not response.ok then
		stdio.ewrite(`Failed to download {TYPES_URL}: {response.statusCode} {response.statusMessage}\n`)
		process.exit(1)
	end
	fs.writeFile(TYPES_PATH, response.body)
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

stdio.write("\n")
if #failures > 0 then
	stdio.ewrite(`CI failed: {table.concat(failures, ", ")}\n`)
	process.exit(1)
end
stdio.write("CI passed.\n")
