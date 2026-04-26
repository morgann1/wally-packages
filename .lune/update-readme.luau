--!strict
-- Regenerate the module table in README.md from modules/*/wally.toml.
-- Run with: `lute run .lune/update-readme.luau`

local fs = require("@std/fs")
local io = require("@std/io")
local process = require("@std/process")

local REPO_URL = "https://github.com/morgann1/wally-packages"
local MODULES_DIR = "modules"
local README_PATH = "README.md"

type Module = {
	alias: string,
	package: string,
	version: string,
	description: string,
	slug: string,
}

local function isFile(path: string): boolean
	return fs.exists(path) and fs.type(path) == "file"
end

local function isDir(path: string): boolean
	return fs.exists(path) and fs.type(path) == "dir"
end

local function kebabToPascal(name: string): string
	local out = {}
	for part in string.gmatch(name, "[^-]+") do
		table.insert(out, part:sub(1, 1):upper() .. part:sub(2))
	end
	return table.concat(out)
end

local function findReturnIdentifier(initPath: string): string?
	if not isFile(initPath) then
		return nil
	end
	local lines = string.split(fs.readFileToString(initPath), "\n")
	for i = #lines, 1, -1 do
		local line = lines[i]:match("^%s*(.-)%s*$")
		if line == "" or line:sub(1, 2) == "--" then
			continue
		end
		return line:match("^return%s+([%a_][%w_]*)%s*$")
	end
	return nil
end

local function displayName(moduleDir: string, slug: string): string
	local returned = findReturnIdentifier(`{moduleDir}/init.luau`)
	-- Lowercase-leading identifier = function export; use it verbatim.
	if returned and returned:sub(1, 1):match("%l") then
		return returned
	end
	-- Otherwise prefer the PascalCase alias derived from the dir name.
	return kebabToPascal(slug)
end

-- Minimal TOML reader: pulls string values from the [package] table.
local function readPackage(tomlPath: string): { [string]: string }
	local result: { [string]: string } = {}
	local inPackage = false
	for _, raw in string.split(fs.readFileToString(tomlPath), "\n") do
		local line = raw:match("^%s*(.-)%s*$")
		if line == "" or line:sub(1, 1) == "#" then
			continue
		end
		local section = line:match("^%[(.+)%]$")
		if section then
			inPackage = section == "package"
			continue
		end
		if not inPackage then
			continue
		end
		local key, value = line:match('^(%w+)%s*=%s*"(.*)"%s*$')
		if key then
			result[key] = value
		end
	end
	return result
end

local modules: { Module } = {}
for _, entry in fs.listDirectory(MODULES_DIR) do
	local moduleDir = `{MODULES_DIR}/{entry.name}`
	local tomlPath = `{moduleDir}/wally.toml`
	if not isDir(moduleDir) or not isFile(tomlPath) then
		continue
	end
	local pkg = readPackage(tomlPath)
	if not pkg.name or not pkg.version then
		continue
	end
	table.insert(modules, {
		alias = displayName(moduleDir, entry.name),
		package = pkg.name,
		version = pkg.version,
		description = pkg.description or "",
		slug = entry.name,
	})
end

if #modules == 0 then
	io.write("No modules found.\n")
	process.exit(1)
end

table.sort(modules, function(a, b)
	return a.alias:lower() < b.alias:lower()
end)

local lines = {
	"# wally-packages",
	"",
	"| Module | Dependency | Description |",
	"| ------ | ---------- | ----------- |",
}
for _, m in modules do
	local link = `[{m.alias}]({REPO_URL}/tree/main/{MODULES_DIR}/{m.slug})`
	local dep = `\`{m.alias} = "{m.package}@{m.version}"\``
	table.insert(lines, `| {link} | {dep} | {m.description} |`)
end

fs.writeStringToFile(README_PATH, table.concat(lines, "\n") .. "\n")
io.write(`Wrote {#modules} modules to {README_PATH}\n`)
