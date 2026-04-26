--!strict
-- Regenerate default.project.json so each package ModuleScript has its
-- in-monorepo wally dependencies injected as children. This lets
-- `require(script.Parent.<Dep>)` resolve at sourcemap time the same way
-- Wally lays them out post-install. Both modules/ and plugin/ are merged
-- into one project file because luau-lsp only consumes a single Rojo file.
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

-- Each package becomes a container folder holding the package itself
-- alongside its in-monorepo wally dependencies as siblings, mirroring
-- wally's _Index install layout. This makes `require(script.Parent.<Dep>)`
-- resolve the same way at sourcemap time as it does post-install.
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
		if data.dependencies then
			for alias, spec in data.dependencies do
				local depName = (spec :: string):match("^([^@]+)")
				local info = depName and packagesByName[depName]
				if info then
					container[alias] = { ["$path"] = info.folder }
				end
			end
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

local project = {
	name = "wally-packages",
	tree = {
		["$className"] = "DataModel",
		ReplicatedStorage = replicatedStorage,
	},
}

fs.writeStringToFile("default.project.json", json.serialize(project, true) .. "\n")
io.write("wrote default.project.json\n")
