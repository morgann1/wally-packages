--!strict
-- Vendor a roblox-packages download as Wally packages under roblox/.
--
-- Parses the rotriever layout (_Index/<Key>/ = source dir + lock.toml + one
-- dependency linker per alias), audits declared deps against actual require
-- calls, resolves packages that are already published on Wally (repo-local
-- morgann1 packages, then the roblox/ scope) to external deps, and vendors
-- the remaining closure: sources copied as-is apart from .lua -> .luau and
-- FindFirstAncestor package-name re-casing (see copyRenamingToLuau), with
-- wally.toml aliases matching the require names. See
-- .claude/skills/vendor-roblox-packages/SKILL.md for the full procedure.
--
-- Run with: `lute run .lute/vendor-roblox-packages.luau <download-dir> <studio-pin> [roots...]`

local fs = require("@std/fs")
local process = require("@std/process")

local DEST_ROOT = "roblox"
local REGISTRY = "https://github.com/UpliftGames/wally-index"

-- Internal names that differ from the roblox/ scope's published names. The
-- luau-polyfill splits follow luau-polyfill's own wally.toml: the plain-name
-- publications (roblox/collections, roblox/boolean, ...) are stale and ship
-- without project files; roblox/symbol is the one exception it really uses.
local SCOPE_NAMES: { [string]: string } = {
	Boolean = "luau-polyfill-boolean",
	Collections = "luau-polyfill-collections",
	Console = "luau-polyfill-console",
	ES7Types = "luau-polyfill-es7-types",
	InstanceOf = "luau-polyfill-instance-of",
	Math = "luau-polyfill-math",
	Number = "luau-polyfill-number",
	Scheduler = "react-scheduler",
	Shared = "react-shared",
	String = "luau-polyfill-string",
	Timers = "luau-polyfill-timers",
}

-- Never map these to a same-named wally package: verified different libraries.
-- roblox/signals (0.x) is not the internal Signal (1.0.0).
local NEVER_EXTERNAL: { [string]: boolean } = {
	Signal = true,
}

-- Manifest exclude globs, keyed by published (kebab) name. The registry caps
-- packages at 2MB; foundation-images' sprite sheet PNGs only load under
-- CorePackages via rbxasset paths, so Wally consumers always take the
-- FALLBACK_IMAGES uploaded-asset branch and the PNGs can be dropped.
local PACKAGE_EXCLUDES: { [string]: { string } } = {
	["foundation-images"] = { "SpriteSheets", "SpriteSheets/**" },
}

type PackageInfo = {
	dir: string,
	source: string,
	name: string,
	version: string,
	aliases: { [string]: string }, -- alias -> target index key
}

type LocalPackage = {
	version: string,
	dir: string,
}

local downloadDir = process.args[2]
local studioVersion = process.args[3]
if downloadDir == nil or studioVersion == nil then
	print("usage: lute run .lute/vendor-roblox-packages.luau <download-dir> <studio-pin> [roots...]")
	process.exit(1)
end
local roots: { string } = {}
for i = 4, #process.args do
	table.insert(roots, process.args[i])
end
if #roots == 0 then
	roots = { "Foundation" }
end

local function kebab(name: string): string
	local s = string.gsub(name, "([%l%d])(%u)", "%1-%2")
	s = string.gsub(s, "(%u)(%u%l)", "%1-%2")
	return string.lower(s)
end

local function semver(v: string): { number }
	local parts = {}
	for part in string.gmatch((string.gsub(v, "%-.*$", "")), "[^.]+") do
		table.insert(parts, tonumber(part) or 0)
	end
	return parts
end

local function semverAtLeast(a: { number }, b: { number }): boolean
	for i = 1, math.max(#a, #b) do
		local x, y = a[i] or 0, b[i] or 0
		if x ~= y then
			return x > y
		end
	end
	return true
end

-- Wally-style caret compatibility, at or above the extracted version.
local function compatible(published: string, extracted: string): boolean
	local p, e = semver(published), semver(extracted)
	local same = if e[1] == 0 then p[1] == e[1] and p[2] == e[2] else p[1] == e[1]
	return same and semverAtLeast(p, e)
end

local function sortedKeys<V>(map: { [string]: V }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function parseIndex(packagesDir: string): { [string]: PackageInfo }
	local packages: { [string]: PackageInfo } = {}
	for _, entry in fs.listDirectory(`{packagesDir}/_Index`) do
		if entry.type ~= "dir" then
			continue
		end
		local dir = `{packagesDir}/_Index/{entry.name}`
		local source: string? = nil
		local aliases: { [string]: string } = {}
		for _, child in fs.listDirectory(dir) do
			if child.type == "dir" then
				source = child.name
			elseif string.match(child.name, "%.luau?$") then
				local target = string.match(fs.readFileToString(`{dir}/{child.name}`), 'PackageIndex%["([^"]+)"%]')
				if target ~= nil then
					aliases[(string.gsub(child.name, "%.luau?$", ""))] = target
				end
			end
		end
		if source == nil then
			error(`no source dir in {dir}`)
		end
		local lock = fs.readFileToString(`{dir}/lock.toml`)
		packages[entry.name] = {
			dir = dir,
			source = source,
			name = assert(string.match(lock, 'name = "([^"]+)"'), "lock.toml has no name"),
			version = assert(string.match(lock, 'version = "([^"]+)"'), "lock.toml has no version"),
			aliases = aliases,
		}
	end
	return packages
end

local function sourceText(info: PackageInfo): string
	local chunks: { string } = {}
	local function collect(dir: string)
		for _, entry in fs.listDirectory(dir) do
			if entry.type == "dir" then
				collect(`{dir}/{entry.name}`)
			elseif string.match(entry.name, "%.luau?$") then
				table.insert(chunks, fs.readFileToString(`{dir}/{entry.name}`))
			end
		end
	end
	collect(`{info.dir}/{info.source}`)
	return table.concat(chunks, "\n")
end

-- Aliases the source actually references (property or bracket access).
local function usedAliases(info: PackageInfo): { [string]: string }
	local text = sourceText(info)
	local used: { [string]: string } = {}
	for alias, target in info.aliases do
		if string.find(text, `[%.%[]%s*["']?{alias}%f[^%w_]`) ~= nil then
			used[alias] = target
		end
	end
	return used
end

-- Wally name -> version and directory for packages published from modules/
-- and plugin/.
local function localMorgann1Packages(): { [string]: LocalPackage }
	local locals: { [string]: LocalPackage } = {}
	for _, group in { "modules", "plugin" } do
		for _, entry in fs.listDirectory(group) do
			local toml = `{group}/{entry.name}/wally.toml`
			if entry.type == "dir" and fs.exists(toml) then
				local text = fs.readFileToString(toml)
				local name = string.match(text, 'name = "morgann1/([^"]+)"')
				local version = string.match(text, 'version = "([^"]+)"')
				if name ~= nil and version ~= nil then
					locals[name] = { version = version, dir = `{group}/{entry.name}` }
				end
			end
		end
	end
	return locals
end

local scopeCache: { [string]: { string } } = {}
-- Published versions of roblox/<name>, via `wally search`. Search shows each
-- package's latest version (plus, for some, older ones in parentheses); that
-- is enough, because wally resolves caret requirements to the latest
-- compatible version at install time anyway.
local function robloxScopeVersions(wallyName: string): { string }
	if scopeCache[wallyName] == nil then
		local versions: { string } = {}
		local result = process.run({ "wally", "search", `roblox/{wallyName}` })
		if result.ok then
			-- `-` quantifies in Lua patterns; escape it to match the name literally.
			local literalName = string.gsub(wallyName, "%-", "%%-")
			local plain = string.gsub(result.stdout, "\27%[[%d;]*m", "")
			for line in string.gmatch(plain, "[^\r\n]+") do
				local version, rest = string.match(line, `^roblox/{literalName}@([%w%.%+%-]+)%s*(.*)`)
				if version ~= nil then
					table.insert(versions, version)
					for extra in string.gmatch(string.match(rest, "%((.-)%)") or "", "[^,%s]+") do
						table.insert(versions, extra)
					end
				end
			end
		end
		scopeCache[wallyName] = versions
	end
	return scopeCache[wallyName]
end

-- Wally requirement string if a compatible published package exists.
local function resolveExternal(name: string, version: string, localPackages: { [string]: LocalPackage }): string?
	if NEVER_EXTERNAL[name] then
		return nil
	end
	local wallyName = kebab(name)
	local localPackage = localPackages[wallyName]
	if localPackage ~= nil and compatible(localPackage.version, version) then
		return `morgann1/{wallyName}@{version}`
	end
	local scopeName = SCOPE_NAMES[name] or wallyName
	local best: string? = nil
	local exact = false
	for _, published in robloxScopeVersions(scopeName) do
		exact = exact or published == version
		if compatible(published, version) and (best == nil or semverAtLeast(semver(best), semver(published))) then
			best = published
		end
	end
	if best == nil then
		return nil
	end
	return `roblox/{scopeName}@{if exact then version else best}`
end

-- Copies a package's sources, renaming .lua to .luau and re-casing
-- FindFirstAncestor names of vendored packages to the kebab instance names
-- the wally-installed layout actually has (rotriever used PascalCase
-- directories, so e.g. FindFirstAncestor("UsageTracker") would return nil at
-- runtime once installed as usage-tracker).
local ancestorRenames: { [string]: string } = {}
local ancestorPatches = 0
local function copyRenamingToLuau(src: string, dest: string, selfOriginal: string, selfWallyName: string)
	fs.createDirectory(dest)
	for _, entry in fs.listDirectory(src) do
		if entry.type == "dir" then
			copyRenamingToLuau(`{src}/{entry.name}`, `{dest}/{entry.name}`, selfOriginal, selfWallyName)
		elseif string.match(entry.name, "%.luau?$") ~= nil then
			local content = fs.readFileToString(`{src}/{entry.name}`)
			for original, wallyName in ancestorRenames do
				if original ~= wallyName then
					local patched, count =
						string.gsub(content, `FindFirstAncestor%("{original}"%)`, `FindFirstAncestor("{wallyName}")`)
					content = patched
					ancestorPatches += count
				end
			end
			-- A package's SELF-reference through the packages folder
			-- (Packages.Foundation.Enums...) must use the wally content
			-- name: unlike dependencies, there is no alias linker for
			-- yourself. Dependency accesses (Packages.Dash) stay alias-named.
			if selfOriginal ~= selfWallyName then
				local patched, count =
					string.gsub(content, `Packages%.{selfOriginal}%f[^%w_]`, `Packages["{selfWallyName}"]`)
				content = patched
				ancestorPatches += count
			end
			fs.writeStringToFile(`{dest}/{(string.gsub(entry.name, "%.lua$", ".luau"))}`, content)
		else
			fs.copy(`{src}/{entry.name}`, `{dest}/{entry.name}`)
		end
	end
end

local packagesDir = `{downloadDir}/Packages`
local packages = parseIndex(packagesDir)
local localPackages = localMorgann1Packages()

-- Collapse multiple downloaded versions of one package to the highest.
local bestByName: { [string]: string } = {}
for _, key in sortedKeys(packages) do
	local info = packages[key]
	local current = bestByName[info.name]
	if current == nil or semverAtLeast(semver(info.version), semver(packages[current].version)) then
		bestByName[info.name] = key
	end
end
local remap: { [string]: string } = {}
for _, key in sortedKeys(packages) do
	remap[key] = bestByName[packages[key].name]
	if remap[key] ~= key then
		print(`note: collapsing {key} -> {remap[key]}`)
	end
end

-- Audit: only actually-required deps become wally.toml entries.
local used: { [string]: { [string]: string } } = {}
for _, key in sortedKeys(packages) do
	used[key] = usedAliases(packages[key])
	for _, alias in sortedKeys(packages[key].aliases) do
		if used[key][alias] == nil then
			print(`note: {packages[key].name} declares but never requires {alias}; pruned`)
		end
	end
end

-- Walk the closure from the roots; stop at externally published packages.
-- Roots are always vendored: they are what this repo exists to publish.
local rootKeys: { [string]: boolean } = {}
for _, root in roots do
	local linker = fs.readFileToString(`{packagesDir}/{root}.lua`)
	rootKeys[remap[assert(string.match(linker, 'PackageIndex%["([^"]+)"%]'), "root linker has no PackageIndex")]] = true
end
local external: { [string]: string } = {}
local vendored: { [string]: boolean } = {}
local stack = sortedKeys(rootKeys)
while #stack > 0 do
	local key = assert(table.remove(stack), "Luau")
	if vendored[key] or external[key] ~= nil then
		continue
	end
	local info = packages[key]
	local requirement = if rootKeys[key] then nil else resolveExternal(info.name, info.version, localPackages)
	if requirement ~= nil then
		external[key] = requirement
	else
		vendored[key] = true
		for _, alias in sortedKeys(used[key]) do
			table.insert(stack, remap[used[key][alias]])
		end
	end
end

-- Wipe and regenerate roblox/<pkg>/.
if not fs.exists(DEST_ROOT) then
	fs.createDirectory(DEST_ROOT)
end
for _, entry in fs.listDirectory(DEST_ROOT) do
	if entry.type == "dir" then
		fs.removeDirectory(`{DEST_ROOT}/{entry.name}`, { recursive = true })
	end
end

local function requirementFor(targetKey: string): string
	local key = remap[targetKey]
	if external[key] ~= nil then
		return external[key]
	end
	local target = packages[key]
	return `morgann1/{kebab(target.name)}@{target.version}`
end

for _, key in sortedKeys(vendored) do
	ancestorRenames[packages[key].source] = kebab(packages[key].name)
end

for _, key in sortedKeys(vendored) do
	local info = packages[key]
	local name = kebab(info.name)
	local dest = `{DEST_ROOT}/{name}`
	if string.find(sourceText(info), [=[%.lua["']]=]) ~= nil then
		print(`WARNING: {name} source mentions '.lua' in a string; check before trusting the rename`)
	end
	copyRenamingToLuau(`{info.dir}/{info.source}`, dest, info.source, name)
	local lines = {
		"[package]",
		`name = "morgann1/{name}"`,
		`description = "Roblox {info.source} {info.version}, vendored from Studio {studioVersion} via roblox-packages"`,
		`version = "{info.version}"`,
		`registry = "{REGISTRY}"`,
		'realm = "shared"',
		'repository = "https://github.com/morgann1/wally-packages"',
	}
	if PACKAGE_EXCLUDES[name] ~= nil then
		local globs = {}
		for _, glob in PACKAGE_EXCLUDES[name] do
			table.insert(globs, `"{glob}"`)
		end
		table.insert(lines, `exclude = [{table.concat(globs, ", ")}]`)
	end
	if next(used[key]) ~= nil then
		table.insert(lines, "")
		table.insert(lines, "[dependencies]")
		for _, alias in sortedKeys(used[key]) do
			table.insert(lines, `{alias} = "{requirementFor(used[key][alias])}"`)
		end
	end
	fs.writeStringToFile(`{dest}/wally.toml`, table.concat(lines, "\n") .. "\n")
end

-- Editor wiring: generate roblox.project.json, which default.project.json
-- mounts at ReplicatedStorage.RobloxPackages, so the rojo sourcemap (and with
-- it luau-lsp) resolves every vendored require. Each vendored package gets a
-- folder holding the package plus its dependencies named by require alias:
-- sibling roblox/ dirs and repo-local packages directly, external wally deps
-- through the Packages/<Alias>.lua linker their root wally.toml alias makes.
local rootAliases: { [string]: string } = {}
for line in string.gmatch(fs.readFileToString("wally.toml"), "[^\r\n]+") do
	local alias, scopeName = string.match(line, '^(%w+) = "([^@"]+)@')
	if alias ~= nil and scopeName ~= nil then
		rootAliases[scopeName] = alias
	end
end

-- Rojo $path for a dependency node. Every dependency mounts through a
-- generated linker file in roblox/_linkers rather than directly: a directly
-- mounted package would be named after the consumer's alias (breaking its
-- re-cased FindFirstAncestor lookups) and cut off from its own dependency
-- siblings, and a per-folder copy of Packages/_Index would duplicate module
-- instances (two Reacts, broken hooks). Vendored linkers navigate to the
-- package's own kebab folder; external linkers point at the single shared
-- ReplicatedStorage.Packages tree, exactly like wally's [place] linkers.
local vendoredLinkers: { [string]: boolean } = {}
local externalLinkers: { [string]: boolean } = {}
local function editorPath(alias: string, targetKey: string): string
	local key = remap[targetKey]
	local requirement = external[key]
	if requirement == nil then
		local targetName = kebab(packages[key].name)
		vendoredLinkers[targetName] = true
		return `roblox/_linkers/{targetName}.luau`
	end
	local scopeName = assert(string.match(requirement, "^([^@]+)"), "Luau")
	local localName = string.match(scopeName, "^morgann1/(.+)$")
	if localName ~= nil then
		return localPackages[localName].dir
	end
	local rootAlias = rootAliases[scopeName]
	if rootAlias == nil then
		print(`WARNING: {scopeName} has no alias in the root wally.toml; add one and run wally install`)
		rootAlias = alias
	end
	externalLinkers[rootAlias] = true
	return `roblox/_linkers/{rootAlias}.luau`
end

local folderChunks: { string } = {}
for _, key in sortedKeys(vendored) do
	local name = kebab(packages[key].name)
	local nodes: { string } = {
		'            "$className": "Folder"',
		`            "{name}": \{\n                "$path": "roblox/{name}"\n            }`,
	}
	for _, alias in sortedKeys(used[key]) do
		local path = editorPath(alias, used[key][alias])
		table.insert(nodes, `            "{alias}": \{\n                "$path": "{path}"\n            }`)
	end
	table.insert(folderChunks, `        "{name}": \{\n{table.concat(nodes, ",\n")}\n        }`)
end
fs.writeStringToFile(
	"roblox.project.json",
	'{\n    "name": "RobloxPackages",\n    "tree": {\n        "$className": "Folder",\n'
		.. table.concat(folderChunks, ",\n")
		.. "\n    }\n}\n"
)

if next(vendoredLinkers) ~= nil or next(externalLinkers) ~= nil then
	fs.createDirectory(`{DEST_ROOT}/_linkers`)
	for _, targetName in sortedKeys(vendoredLinkers) do
		fs.writeStringToFile(
			`{DEST_ROOT}/_linkers/{targetName}.luau`,
			`return require(script.Parent.Parent["{targetName}"]["{targetName}"])\n`
		)
	end
	for _, rootAlias in sortedKeys(externalLinkers) do
		fs.writeStringToFile(
			`{DEST_ROOT}/_linkers/{rootAlias}.luau`,
			`return require(game:GetService("ReplicatedStorage").Packages.{rootAlias})\n`
		)
	end
end

-- Validate every manifest. Streams are discarded: `--list` output for large
-- packages overflows the capture pipe and deadlocks the child process.
local failures = 0
for _, key in sortedKeys(vendored) do
	local dir = `{DEST_ROOT}/{kebab(packages[key].name)}`
	local result = process.run({ "wally", "package", "--project-path", dir, "--list" }, { stdio = "none" })
	if not result.ok then
		failures += 1
		print(`FAIL wally package {dir}; rerunning with output shown:`)
		process.run({ "wally", "package", "--project-path", dir, "--list" }, { stdio = "inherit" })
	end
end

if ancestorPatches > 0 then
	print(`note: re-cased {ancestorPatches} FindFirstAncestor names to wally instance names`)
end

-- Regenerate the wally linkers from scratch: wally-package-types cannot
-- re-parse linkers it already patched, so each run starts from pristine ones.
local installArgs = { "wally", "install" }
if not process.run(installArgs, { stdio = "none" }).ok then
	failures += 1
	print("FAIL wally install; rerunning with output shown:")
	process.run(installArgs, { stdio = "inherit" })
end

-- The sourcemap build exercises every $path in the generated project file.
local sourcemapArgs = { "rojo", "sourcemap", "default.project.json", "-o", "sourcemap.json" }
if not process.run(sourcemapArgs, { stdio = "none" }).ok then
	failures += 1
	print("FAIL rojo sourcemap; rerunning with output shown:")
	process.run(sourcemapArgs, { stdio = "inherit" })
end

-- Wally's generated linkers return values but do not re-export types
-- (React.ReactElement etc. would be unknown); wally-package-types rewrites
-- them with export type lines, resolving targets through the sourcemap.
local typesArgs = { "wally-package-types", "--sourcemap", "sourcemap.json", "Packages" }
if not process.run(typesArgs, { stdio = "none" }).ok then
	failures += 1
	print("FAIL wally-package-types; rerunning with output shown:")
	process.run(typesArgs, { stdio = "inherit" })
end

local externalSet: { [string]: boolean } = {}
for _, requirement in external do
	externalSet[requirement] = true
end
local vendoredCount = #sortedKeys(vendored)
print(`\nvendored {vendoredCount} packages, {#sortedKeys(externalSet)} external deps, {failures} manifest failures`)
print(`external: {table.concat(sortedKeys(externalSet), ", ")}`)

-- Topological publish order: dependencies before dependents.
local order: { string } = {}
local seen: { [string]: boolean } = {}
local function visit(key: string)
	if seen[key] or not vendored[key] then
		return
	end
	seen[key] = true
	for _, alias in sortedKeys(used[key]) do
		visit(remap[used[key][alias]])
	end
	table.insert(order, kebab(packages[key].name))
end
for _, key in sortedKeys(vendored) do
	visit(key)
end
print(`publish order: {table.concat(order, ", ")}`)

process.exit(if failures > 0 then 1 else 0)
