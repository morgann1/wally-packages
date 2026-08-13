--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local Otter = require(ReplicatedStorage.RobloxPackages.otter.otter)

describe("otter", function()
	test("exports the motor and goal constructors", function()
		expect(Otter.createSingleMotor).toEqual(expect.any("function"))
		expect(Otter.createGroupMotor).toEqual(expect.any("function"))
		expect(Otter.spring).toEqual(expect.any("function"))
	end)

	test("instant goal completes at its target", function()
		local state = Otter.instant(5).step({ value = 0, complete = false }, 1 / 60)
		expect(state.value).toBe(5)
		expect(state.complete).toBe(true)
	end)
end)
