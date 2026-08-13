--!strict
-- Build the test place from test.project.json and run the Jest specs in
-- it via run-in-roblox (requires a local Roblox Studio install).
-- Run with: `lute run .lute/test.luau [--build-only]`

local fs = require("@std/fs")
local process = require("@std/process")

local PROJECT = "test.project.json"
local OUTPUT = "tests/build/tests.rbxl"
local RUNNER = "tests/runTests.server.luau"

local buildOnly = false
for i = 2, #process.args do
	local arg = process.args[i]
	if arg == "--build-only" or arg == "-b" then
		buildOnly = true
	else
		print(`error: unknown argument "{arg}"`)
		print("usage: lute run .lute/test.luau [--build-only]")
		process.exit(1)
	end
end

if not (fs.exists("Packages") and fs.exists("DevPackages")) then
	print("installing wally packages")
	if not process.run({ "wally", "install" }, { stdio = "inherit" }).ok then
		process.exit(1)
	end
end

if not fs.exists("tests/build") then
	fs.createDirectory("tests/build")
end

print(`building {OUTPUT}`)
if not process.run({ "rojo", "build", PROJECT, "-o", OUTPUT }, { stdio = "inherit" }).ok then
	process.exit(1)
end

if buildOnly then
	print(`open {OUTPUT} in Studio and run {RUNNER} from the command bar`)
	process.exit(0)
end

print("running tests via run-in-roblox")
local result = process.run({ "run-in-roblox", "--place", OUTPUT, "--script", RUNNER }, { stdio = "inherit" })
process.exit(if result.ok then 0 else 1)
