--!strict
-- Regenerate the module table in README.md from modules/*/wally.toml.
-- Run with: `lune run update-readme`

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

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

local function kebabToPascal(name: string): string
	local out = {}
	for part in string.gmatch(name, "[^-]+") do
		table.insert(out, part:sub(1, 1):upper() .. part:sub(2))
	end
	return table.concat(out)
end

local function findReturnIdentifier(initPath: string): string?
	if not fs.isFile(initPath) then
		return nil
	end
	local lines = string.split(fs.readFile(initPath), "\n")
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
	for _, raw in string.split(fs.readFile(tomlPath), "\n") do
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
for _, slug in fs.readDir(MODULES_DIR) do
	local moduleDir = `{MODULES_DIR}/{slug}`
	local tomlPath = `{moduleDir}/wally.toml`
	if not fs.isDir(moduleDir) or not fs.isFile(tomlPath) then
		continue
	end
	local pkg = readPackage(tomlPath)
	if not pkg.name or not pkg.version then
		continue
	end
	table.insert(modules, {
		alias = displayName(moduleDir, slug),
		package = pkg.name,
		version = pkg.version,
		description = pkg.description or "",
		slug = slug,
	})
end

if #modules == 0 then
	stdio.ewrite("No modules found.\n")
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

fs.writeFile(README_PATH, table.concat(lines, "\n") .. "\n")
stdio.write(`Wrote {#modules} modules to {README_PATH}\n`)
