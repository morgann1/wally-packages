--!strict
-- Originally (c) Studio Elttob 2024.

--[=[
	@class ElttobLog

	A tagged logger that only emits output in a local development
	environment, detected via [IsLocalDev]. Unbracketed and bracketed GUIDs
	are replaced with short emoji-based identifiers in log messages so they
	stay readable in the Output window.

	The module exports a factory: pass it your local dev environment name
	once, and it returns a `create(tag, enabled)` function for opening
	scoped loggers.

	```lua
	local makeLog = require(path.to.Log)("MyPlugin")
	local log = makeLog("Network", true)
	log.info("hello")  -- only prints in local dev
	```
]=]

local IsLocalDev = require(script.Parent.IsLocalDev)
local emoji = require(script.Emoji)

local GUID_REGEX_UNBRACKETED = "%w%w%w%w%w%w%w%w%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w%w%w%w%w%w%w%w%w"
local GUID_REGEX_BRACKETED = "{" .. GUID_REGEX_UNBRACKETED .. "}"

local function prettyGUID(guid: string): string
	local index1 = 0
	local index2 = 0
	for index = 1, #guid do
		index1 *= string.byte("z") - string.byte("0")
		index1 += (string.byte(string.sub(guid, index, index)) - string.byte("0"))
		index1 %= #guid
		index2 *= string.byte("z") - string.byte("0")
		index2 += (string.byte(string.sub(guid, -index, -index)) - string.byte("0"))
		index2 %= #guid
	end
	return `GUID{emoji[index1]}{emoji[index2]}`
end

local function tostringAll(...: unknown): { string }
	local parts: { string } = {}
	for index = 1, select("#", ...) do
		parts[index] = tostring(select(index, ...))
	end
	return parts
end

local function toLogMessage(devEnvName: string, tag: string, ...: unknown): string
	return `[{devEnvName}] [{tag}] `
		.. table
			.concat(tostringAll(...), " ")
			:gsub(GUID_REGEX_BRACKETED, prettyGUID)
			:gsub(GUID_REGEX_UNBRACKETED, prettyGUID)
end

--[=[
	@within ElttobLog
	@function create

	Returns a `(tag, enabled) -> { info, warn }` constructor bound to
	`devEnvName`. Loggers built from it only emit output when running
	inside a matching local dev environment **and** `enabled` is true.

	@param devEnvName string -- Identifier passed to [IsLocalDev] and used as the log prefix.
	@return (tag: string, enabled: boolean) -> { info: (...any) -> (), warn: (...any) -> () }
]=]
local function create(devEnvName: string)
	if IsLocalDev(devEnvName) then
		print(toLogMessage(devEnvName, "Log", "This is a local development environment!"))
	end
	return function(tag: string, enabled: boolean)
		local verbose = IsLocalDev(devEnvName) and enabled
		return {
			info = function(...)
				if verbose then
					print(toLogMessage(devEnvName, tag, ...))
				end
			end,
			warn = function(...)
				if verbose then
					warn(toLogMessage(devEnvName, tag, ...))
				end
			end,
		}
	end
end

return create
