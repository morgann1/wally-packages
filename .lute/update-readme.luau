--!strict
-- Regenerate the package tables in README.md from modules/*/wally.toml
-- and plugin/*/wally.toml. Only the marked regions are rewritten; the
-- prose around them is hand-written and left alone.
-- Run with: `lute run .lute/update-readme.luau`

local fs = require("@std/fs")
local process = require("@std/process")

local REPO_URL = "https://github.com/morgann1/wally-packages"
local README_PATH = "README.md"

type Package = {
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

local function displayName(packageDir: string, slug: string): string
	local returned = findReturnIdentifier(`{packageDir}/init.luau`)
	-- A lowercase-leading identifier that spells the slug is a function
	-- export named after the package (doCleanup, sortingBy); use it
	-- verbatim. Generic factory names (create) don't qualify.
	if returned and returned:sub(1, 1):match("%l") and returned:lower() == slug:gsub("-", ""):lower() then
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

local function collectPackages(rootDir: string): { Package }
	local packages: { Package } = {}
	for _, entry in fs.listDirectory(rootDir) do
		local packageDir = `{rootDir}/{entry.name}`
		local tomlPath = `{packageDir}/wally.toml`
		if not isDir(packageDir) or not isFile(tomlPath) then
			continue
		end
		local pkg = readPackage(tomlPath)
		if not pkg.name or not pkg.version then
			continue
		end
		table.insert(packages, {
			alias = displayName(packageDir, entry.name),
			package = pkg.name,
			version = pkg.version,
			description = pkg.description or "",
			slug = entry.name,
		})
	end
	table.sort(packages, function(a, b)
		return a.alias:lower() < b.alias:lower()
	end)
	return packages
end

local function renderTable(rootDir: string, packages: { Package }): string
	local lines = {
		"| Package | Dependency | Description |",
		"| ------- | ---------- | ----------- |",
	}
	for _, m in packages do
		local link = `[{m.alias}]({REPO_URL}/tree/main/{rootDir}/{m.slug})`
		local dep = `\`{m.alias} = "{m.package}@{m.version}"\``
		-- Upstream ports carry their source URL as the description.
		local description = m.description
		if description:sub(1, 4) == "http" then
			description = `Port of the [upstream source]({description}).`
		end
		table.insert(lines, `| {link} | {dep} | {description} |`)
	end
	return table.concat(lines, "\n")
end

-- Splice `content` between `<!-- {name}:start -->` and `<!-- {name}:end -->`.
local function spliceRegion(readme: string, name: string, content: string): string
	local startMarker = `<!-- {name}:start -->`
	local endMarker = `<!-- {name}:end -->`
	local startAt = readme:find(startMarker, 1, true)
	local endAt = readme:find(endMarker, 1, true)
	if startAt == nil or endAt == nil then
		print(`error: {README_PATH} is missing the {startMarker} / {endMarker} markers`)
		process.exit(1)
	end
	local head = readme:sub(1, (startAt :: number) + #startMarker - 1)
	local tail = readme:sub(endAt :: number)
	return `{head}\n{content}\n{tail}`
end

local REGIONS: { { name: string, rootDir: string } } = {
	{ name = "modules-table", rootDir = "modules" },
	{ name = "plugin-table", rootDir = "plugin" },
}

local readme = fs.readFileToString(README_PATH)
for _, region in REGIONS do
	local packages = collectPackages(region.rootDir)
	if #packages == 0 then
		print(`No packages found in {region.rootDir}/.`)
		process.exit(1)
	end
	readme = spliceRegion(readme, region.name, renderTable(region.rootDir, packages))
	print(`{region.rootDir}: {#packages} packages`)
end

fs.writeStringToFile(README_PATH, readme)
print(`wrote {README_PATH}`)
