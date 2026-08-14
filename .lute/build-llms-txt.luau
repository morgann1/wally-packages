--!strict
-- Generate the AI-consumable doc surface: moonwave/static/llms.txt (a short
-- index per the llms.txt convention) and moonwave/static/llms-full.txt (the
-- entire API reference plus every docs/ page as one markdown file, the thing
-- an agent actually wants to fetch). moonwave copies .moonwave/static/ into
-- the built site's root, so both publish at https://.../<name>.txt.
-- Requires moonwave-extractor, pinned in rokit.toml.
-- Run with: `lute run .lute/build-llms-txt.luau`

local fs = require("@std/fs")
local json = require("@std/json")
local process = require("@std/process")

local SITE_URL = "https://morgann1.github.io/wally-packages"
local REPO_URL = "https://github.com/morgann1/wally-packages"
local DEST = ".moonwave/static"
local BLURB = "Luau packages for Roblox game and Studio plugin development, "
	.. "published to the Wally registry under the morgann1/* scope."

type Param = { name: string, lua_type: string, desc: string }
type Return = { lua_type: string, desc: string }
type Field = { name: string, lua_type: string, desc: string }
type Fn = { name: string, desc: string, params: { Param }, returns: { Return }, function_type: string }
type Prop = { name: string, desc: string, lua_type: string }
type Type = { name: string, desc: string, lua_type: string?, fields: { Field }? }
type Class = { name: string, desc: string, functions: { Fn }, properties: { Prop }, types: { Type } }

local function extract(tree: string): { Class }
	local result = process.run({ "moonwave-extractor", "extract", tree })
	if not result.ok then
		error(`moonwave-extractor failed on {tree}: {result.stderr}`)
	end
	return json.deserialize(result.stdout) :: { Class }
end

local out: { string } = {}
local function emit(line: string): ()
	table.insert(out, line)
end

local function emitClass(class: Class): ()
	emit(`## {class.name}`)
	emit("")
	if class.desc ~= "" then
		emit(class.desc)
		emit("")
	end
	for _, prop in class.properties do
		emit(`### {class.name}.{prop.name}: {prop.lua_type}`)
		emit("")
		if prop.desc ~= "" then
			emit(prop.desc)
			emit("")
		end
	end
	for _, ty in class.types do
		if ty.fields ~= nil then
			emit(`### type {ty.name}`)
			emit("")
			for _, field in ty.fields :: { Field } do
				local suffix = if field.desc == "" then "" else ` -- {field.desc}`
				emit(`- {field.name}: {field.lua_type}{suffix}`)
			end
			emit("")
		else
			emit(`### type {ty.name} = {ty.lua_type or "unknown"}`)
			emit("")
		end
		if ty.desc ~= "" then
			emit(ty.desc)
			emit("")
		end
	end
	for _, fn in class.functions do
		local params = {}
		for _, param in fn.params do
			table.insert(params, `{param.name}: {param.lua_type}`)
		end
		local returns = {}
		for _, ret in fn.returns do
			table.insert(returns, ret.lua_type)
		end
		-- A function named after its class is the module itself (doCleanup,
		-- sortingBy); the qualified form would double the name.
		local sep = if fn.function_type == "method" then ":" else "."
		local prefix = if fn.name == class.name then "" else `{class.name}{sep}`
		local signature = `{prefix}{fn.name}({table.concat(params, ", ")})`
		if #returns > 0 then
			signature ..= ` -> {table.concat(returns, ", ")}`
		end
		emit(`### {signature}`)
		emit("")
		if fn.desc ~= "" then
			emit(fn.desc)
			emit("")
		end
		for _, param in fn.params do
			if param.desc ~= "" then
				emit(`- {param.name}: {param.desc}`)
			end
		end
		for _, ret in fn.returns do
			if ret.desc ~= "" then
				emit(`- returns: {ret.desc}`)
			end
		end
		if out[#out] ~= "" then
			emit("")
		end
	end
end

local function emitTree(title: string, tree: string): number
	local classes = extract(tree)
	table.sort(classes, function(a, b)
		return a.name:lower() < b.name:lower()
	end)
	emit(`# {title}`)
	emit("")
	for _, class in classes do
		emitClass(class)
	end
	return #classes
end

-- Docs pages, with any frontmatter reduced to a title for the section header.
local function emitDocsDir(dir: string, crumbs: { string }): number
	local pages = 0
	local entries = fs.listDirectory(dir)
	table.sort(entries, function(a, b)
		return a.name < b.name
	end)
	for _, entry in entries do
		local path = `{dir}/{entry.name}`
		if entry.type == "dir" then
			table.insert(crumbs, entry.name)
			pages += emitDocsDir(path, crumbs)
			table.remove(crumbs)
			continue
		end
		local name = entry.name:match("^(.+)%.md$")
		if name == nil then
			continue
		end
		local body = fs.readFileToString(path)
		local inner, rest = body:match("^%-%-%-\r?\n(.-)\r?\n%-%-%-\r?\n(.*)$")
		if inner ~= nil then
			name = (inner :: string):match("title:%s*(%S+)") or name
			body = (rest :: string):gsub("^%s+", "")
		end
		local crumb = if #crumbs > 0 then `{table.concat(crumbs, " / ")} / ` else ""
		emit(`## {crumb}{name}`)
		emit("")
		emit(body:gsub("%s+$", ""))
		emit("")
		pages += 1
	end
	return pages
end

local moduleCount = emitTree("API reference: modules (game runtime)", "modules")
local pluginCount = emitTree("API reference: plugin (Studio plugin libraries)", "plugin")
emit("# Guides")
emit("")
local pageCount = emitDocsDir("docs", {})

if not fs.exists(".moonwave") then
	fs.createDirectory(".moonwave")
end
if not fs.exists(DEST) then
	fs.createDirectory(DEST)
end
fs.writeStringToFile(`{DEST}/llms-full.txt`, table.concat(out, "\n"))

local index = {
	"# wally-packages",
	"",
	`> {BLURB}`,
	"",
	"## Docs",
	"",
	`- [Complete reference]({SITE_URL}/llms-full.txt): the full API of every package plus all guide pages, as one markdown file`,
	"",
	"## Source",
	"",
	`- [GitHub repository]({REPO_URL}): sources, doc comments, and guide markdown live in-repo`,
	"",
}
fs.writeStringToFile(`{DEST}/llms.txt`, table.concat(index, "\n"))

print(`llms-full.txt: {moduleCount} module classes, {pluginCount} plugin classes, {pageCount} guide pages`)
print(`wrote {DEST}/llms.txt and {DEST}/llms-full.txt`)
