--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local SensationSounds = require(ReplicatedStorage.PluginLib["sensation-sounds"]["sensation-sounds"])

describe("sensation-sounds", function()
	test("returns the same table it was given", function()
		local sounds = {
			generic = "rbxassetid://0",
			success = "rbxassetid://0",
		}
		local result = SensationSounds(sounds) :: any

		expect(result).toBe(sounds)
		expect(result.generic).toBe("rbxassetid://0")
		expect(result.attention).toBe(nil)
	end)

	test("accepts an empty table", function()
		local empty = {}
		expect(SensationSounds(empty)).toBe(empty)
	end)
end)
