--!strict
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local SimpleLogger = require(ReplicatedStorage.Modules["simple-logger"]["simple-logger"])

-- Runs `emit` while capturing LogService.MessageOut, and returns the first
-- captured message containing `marker` (or nil after ~2s). MessageOut is
-- deferred, so poll a few frames after emitting.
local function captureMessage(marker: string, emit: () -> ()): (string?, Enum.MessageType?)
	local foundMessage: string? = nil
	local foundType: Enum.MessageType? = nil
	local connection = LogService.MessageOut:Connect(function(message, messageType)
		if foundMessage == nil and message:find(marker, nil, true) ~= nil then
			foundMessage = message
			foundType = messageType
		end
	end)
	emit()
	local deadline = os.clock() + 2
	while foundMessage == nil and os.clock() < deadline do
		task.wait()
	end
	connection:Disconnect()
	return foundMessage, foundType
end

describe("simple-logger", function()
	-- The prefix derives from the calling script's debug.info source,
	-- whose exact spelling depends on how the module was loaded (Jest
	-- loads specs through loadstring), so only assert its stable shape.
	test("info prints a bracketed prefix through print", function()
		local message, messageType = captureMessage("marker-info-7f3a", function()
			SimpleLogger.info("marker-info-7f3a")
		end)
		expect(message).toEqual(expect.any("string"))
		expect((message :: string):sub(1, 1)).toBe("[")
		expect(message :: string).toContain("spec")
		expect(message :: string).toContain("INFO: marker-info-7f3a")
		expect(messageType).toBe(Enum.MessageType.MessageOutput)
	end)

	test("warn goes through warn", function()
		local message, messageType = captureMessage("marker-warn-7f3a", function()
			SimpleLogger.warn("marker-warn-7f3a")
		end)
		expect(message :: string).toContain("WARN: marker-warn-7f3a")
		expect(messageType).toBe(Enum.MessageType.MessageWarning)
	end)

	test("debug prints when running in Studio", function()
		local message = captureMessage("marker-debug-7f3a", function()
			SimpleLogger.debug("marker-debug-7f3a")
		end)
		expect(message :: string).toContain("DEBUG: marker-debug-7f3a")
	end)
end)
