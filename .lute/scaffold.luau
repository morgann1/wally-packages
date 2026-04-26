--!strict
-- Scaffold a new Wally package under modules/<slug> (default) or plugin/<slug>.
-- Run with: `lute run .lute/scaffold.luau <slug> [--plugin]`

local fs = require("@std/fs")
local io = require("@std/io")
local process = require("@std/process")

local AUTHOR = "morgann1"
local REGISTRY = "https://github.com/UpliftGames/wally-index"

local slug: string? = nil
local isPlugin = false
for _, arg in process.args do
	if arg == "--plugin" or arg == "-p" then
		isPlugin = true
	elseif arg:sub(1, 1) == "-" then
		io.write(`error: unknown flag "{arg}"\n`)
		process.exit(1)
	elseif slug == nil then
		slug = arg
	else
		io.write(`error: unexpected argument "{arg}"\n`)
		process.exit(1)
	end
end

if not slug or slug == "" then
	io.write("usage: lute run .lute/scaffold.luau <slug> [--plugin]\n")
	process.exit(1)
end

if not slug:match("^[a-z0-9]+%-?[a-z0-9]+[%-a-z0-9]*$") then
	io.write(`error: slug "{slug}" must be lowercase kebab-case (a-z, 0-9, '-')\n`)
	process.exit(1)
end

local rootDir = if isPlugin then "plugin" else "modules"
local packageDir = `{rootDir}/{slug}`
if fs.exists(packageDir) then
	io.write(`error: {packageDir} already exists\n`)
	process.exit(1)
end

local year = tostring(os.date("%Y"))

local pascalName = slug:gsub("%-(%w)", string.upper):gsub("^%w", string.upper)

local wallyToml = "[package]\n"
	.. `name = "{AUTHOR}/{slug}"\n`
	.. `description = "TODO: describe {slug}"\n`
	.. 'version = "0.1.0"\n'
	.. 'license = "MIT"\n'
	.. `authors = ["{AUTHOR}"]\n`
	.. `registry = "{REGISTRY}"\n`
	.. 'realm = "shared"\n'

local initLuau = "--!strict\n\nlocal " .. pascalName .. " = {}\n\nreturn " .. pascalName .. "\n"

local licenseBody = [[MIT License

Copyright (c) __YEAR__ __AUTHOR__

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local license = licenseBody:gsub("__YEAR__", year):gsub("__AUTHOR__", AUTHOR)

fs.createDirectory(packageDir, { makeParents = true })
fs.writeStringToFile(`{packageDir}/wally.toml`, wallyToml)
fs.writeStringToFile(`{packageDir}/init.luau`, initLuau)
fs.writeStringToFile(`{packageDir}/LICENSE`, license)

io.write(`scaffolded {packageDir}\n`)
