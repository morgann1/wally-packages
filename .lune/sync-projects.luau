--!strict
-- Regenerate default.project.json so each package ModuleScript has its
-- in-monorepo wally dependencies injected as children. This lets
-- `require(script.Parent.<Dep>)` resolve at sourcemap time the same way
-- Wally lays them out post-install. Both modules/ and plugin/ are merged
-- into one project file because luau-lsp only consumes a single Rojo file.
-- Run with: `lune run sync-projects`

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local toml = require("./batteries/toml")

type PackageInfo = {
	folder: string,
	name: string,
}

local function readWallyToml(path: string): any
	return toml.deserialize(fs.readFile(path))
end

local function indexPackages(rootDir: string, into: { [string]: PackageInfo })
	if not fs.isDir(rootDir) then
		return
	end
	for _, slug in fs.readDir(rootDir) do
		local folder = `{rootDir}/{slug}`
		local toml = `{folder}/wally.toml`
		if not fs.isFile(toml) then
			continue
		end
		local data = readWallyToml(toml)
		if not data.package or not data.package.name then
			continue
		end
		into[data.package.name] = {
			folder = folder,
			name = data.package.name,
		}
	end
end

local function buildModulesTree(rootDir: string, packagesByName: { [string]: PackageInfo }): any?
	if not fs.isDir(rootDir) then
		return nil
	end
	local modulesTree: any = { ["$className"] = "Folder" }
	for _, slug in fs.readDir(rootDir) do
		local folder = `{rootDir}/{slug}`
		local toml = `{folder}/wally.toml`
		if not fs.isFile(toml) then
			continue
		end
		local data = readWallyToml(toml)
		local node: any = { ["$path"] = folder }
		if data.dependencies then
			for alias, spec in data.dependencies do
				local depName = (spec :: string):match("^([^@]+)")
				local info = depName and packagesByName[depName]
				if info then
					node[alias] = { ["$path"] = info.folder }
				end
			end
		end
		modulesTree[slug] = node
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

local project = {
	name = "wally-packages",
	tree = {
		["$className"] = "DataModel",
		ReplicatedStorage = replicatedStorage,
	},
}

fs.writeFile("default.project.json", serde.encode("json", project, true) .. "\n")
stdio.write("wrote default.project.json\n")
