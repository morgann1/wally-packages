--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local safePlayerAdded = require(ReplicatedStorage.Modules["safe-player-added"]["safe-player-added"])

-- No players exist in the test place, so this only exercises the shape of
-- the API: existing players are visited without error and the returned
-- PlayerAdded connection is live until disconnected.
describe("safe-player-added", function()
	test("returns a live PlayerAdded connection", function()
		local connection = safePlayerAdded(function() end)

		expect(typeof(connection)).toBe("RBXScriptConnection")
		expect(connection.Connected).toBe(true)

		connection:Disconnect()
		expect(connection.Connected).toBe(false)
	end)
end)
