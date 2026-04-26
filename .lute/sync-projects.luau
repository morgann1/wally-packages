--!strict
-- Regenerate default.project.json so each package ModuleScript has its
-- wally dependencies injected as children. In-monorepo deps point at
-- their on-disk package; external deps (e.g. jsdotlua/react) mount the
-- corresponding `Packages/<Alias>.lua` trampoline plus `Packages/_Index`
-- so the trampoline's `script.Parent._Index[...]` lookup resolves.
-- Both modules/ and plugin/ are merged into one project file because
-- luau-lsp only consumes a single Rojo file.
-- Run with: `lute run .lute/sync-projects.luau`

local fs = require("@std/fs")
local io = require("@std/io")
local json = require("@std/json")
local toml = require("./batteries/toml")

type PackageInfo = {
	folder: string,
	name: string,
}

local function readWallyToml(path: string): any
	return toml.deserialize(fs.readFileToString(path))
end

local function isDir(path: string): boolean
	return fs.exists(path) and fs.type(path) == "dir"
end

local function isFile(path: string): boolean
	return fs.exists(path) and fs.type(path) == "file"
end

local function indexPackages(rootDir: string, into: { [string]: PackageInfo })
	if not isDir(rootDir) then
		return
	end
	for _, entry in fs.listDirectory(rootDir) do
		local folder = `{rootDir}/{entry.name}`
		local tomlPath = `{folder}/wally.toml`
		if not isFile(tomlPath) then
			continue
		end
		local data = readWallyToml(tomlPath)
		if not data.package or not data.package.name then
			continue
		end
		into[data.package.name] = {
			folder = folder,
			name = data.package.name,
		}
	end
end

local PACKAGES_DIR = "Packages"
local PACKAGES_INDEX_DIR = `{PACKAGES_DIR}/_Index`

local function findExternalTrampoline(alias: string): string?
	local lua = `{PACKAGES_DIR}/{alias}.lua`
	if isFile(lua) then
		return lua
	end
	local luau = `{PACKAGES_DIR}/{alias}.luau`
	if isFile(luau) then
		return luau
	end
	return nil
end

-- Walk an in-monorepo package's dependency graph and return every
-- transitive in-monorepo package keyed by the alias under which it
-- should appear (i.e. the alias used by the package that depends on
-- it). When a transitive dep collides with the consumer's own alias
-- choice, the consumer wins.
local function collectTransitiveInMonorepoDeps(
	packageName: string,
	packagesByName: { [string]: PackageInfo },
	into: { [string]: PackageInfo },
	seen: { [string]: true }
)
	if seen[packageName] then
		return
	end
	seen[packageName] = true
	local info = packagesByName[packageName]
	if info == nil then
		return
	end
	local data = readWallyToml(`{info.folder}/wally.toml`)
	if data.dependencies == nil then
		return
	end
	for alias, spec in data.dependencies do
		local depName = (spec :: string):match("^([^@]+)")
		local depInfo = depName and packagesByName[depName]
		if depInfo ~= nil and into[alias] == nil then
			into[alias] = depInfo
			collectTransitiveInMonorepoDeps(depName, packagesByName, into, seen)
		end
	end
end

-- Each package becomes a container folder holding the package itself
-- alongside its wally dependencies as siblings, mirroring wally's _Index
-- install layout. In-monorepo deps point at on-disk packages (with
-- transitive in-monorepo deps mounted as additional siblings so each
-- ported package's internal `script.Parent.Parent.<TransitiveDep>`
-- resolves); external deps mount the `Packages/` trampoline plus
-- `Packages/_Index`.
local function buildModulesTree(rootDir: string, packagesByName: { [string]: PackageInfo }): any?
	if not isDir(rootDir) then
		return nil
	end
	local modulesTree: any = { ["$className"] = "Folder" }
	for _, entry in fs.listDirectory(rootDir) do
		local folder = `{rootDir}/{entry.name}`
		local tomlPath = `{folder}/wally.toml`
		if not isFile(tomlPath) then
			continue
		end
		local data = readWallyToml(tomlPath)
		local container: any = {
			["$className"] = "Folder",
			[entry.name] = { ["$path"] = folder },
		}
		local needsExternalIndex = false
		local directInMonorepoDeps: { [string]: PackageInfo } = {}
		if data.dependencies then
			for alias, spec in data.dependencies do
				local depName = (spec :: string):match("^([^@]+)")
				local info = depName and packagesByName[depName]
				if info then
					container[alias] = { ["$path"] = info.folder }
					directInMonorepoDeps[alias] = info
				else
					local trampolinePath = findExternalTrampoline(alias)
					if trampolinePath ~= nil then
						container[alias] = { ["$path"] = trampolinePath }
						needsExternalIndex = true
					end
				end
			end
		end
		local transitive: { [string]: PackageInfo } = {}
		local seen: { [string]: true } = {}
		for _, info in directInMonorepoDeps do
			collectTransitiveInMonorepoDeps(info.name, packagesByName, transitive, seen)
		end
		for alias, info in transitive do
			if container[alias] == nil then
				container[alias] = { ["$path"] = info.folder }
			end
		end
		if needsExternalIndex and isDir(PACKAGES_INDEX_DIR) then
			container._Index = { ["$path"] = PACKAGES_INDEX_DIR }
		end
		modulesTree[entry.name] = container
	end
	return modulesTree
end

local packagesByName: { [string]: PackageInfo } = {}
indexPackages("modules", packagesByName)
indexPackages("plugin", packagesByName)

local replicatedStorage: any = { ["$className"] = "ReplicatedStorage" }
local modulesTree = buildModulesTree("modules", packagesByName)
local pluginsTree = buildModulesTree("plugin", packagesByName)
if modulesTree then
	replicatedStorage.Modules = modulesTree
end
if pluginsTree then
	replicatedStorage.PluginLib = pluginsTree
end
if isDir(PACKAGES_DIR) then
	replicatedStorage.Packages = { ["$path"] = PACKAGES_DIR }
end

local project = {
	name = "wally-packages",
	tree = {
		["$className"] = "DataModel",
		ReplicatedStorage = replicatedStorage,
	},
}

fs.writeStringToFile("default.project.json", json.serialize(project, true) .. "\n")
io.write("wrote default.project.json\n")
