--!strict
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local ElttobLog = require(ReplicatedStorage.PluginLib["elttob-log"]["elttob-log"])

-- "Tests" appears in this spec's script path, so IsLocalDev("Tests") is
-- true here and loggers created below are verbose.
local makeLog = ElttobLog("Tests")

local function captureMessage(marker: string, emit: () -> ()): string?
	local found: string? = nil
	local connection = LogService.MessageOut:Connect(function(message)
		if found == nil and message:find(marker, nil, true) ~= nil then
			found = message
		end
	end)
	emit()
	local deadline = os.clock() + 2
	while found == nil and os.clock() < deadline do
		task.wait()
	end
	connection:Disconnect()
	return found
end

describe("elttob-log", function()
	test("info prints with the dev-env and tag prefix", function()
		local log = makeLog("SpecTag", true)
		local message = captureMessage("marker-elttob-91c2", function()
			log.info("marker-elttob-91c2")
		end)
		expect(message).toBe("[Tests] [SpecTag] marker-elttob-91c2")
	end)

	test("GUIDs are replaced with short emoji identifiers", function()
		local log = makeLog("SpecGuid", true)
		local guid = "0f8fad5b-d9cb-469f-a165-70867728950e"
		local message = captureMessage("marker-guid-91c2", function()
			log.info("marker-guid-91c2", `\{{guid}}`)
		end)

		expect(message).toEqual(expect.any("string"))
		expect(message :: string).toContain("GUID")
		expect((message :: string):find(guid, nil, true)).toBe(nil)
	end)

	test("disabled loggers stay callable", function()
		local log = makeLog("SpecQuiet", false)
		expect(function()
			log.info("quiet")
			log.warn("quiet")
		end).never.toThrow()
	end)
end)
