--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local Motion = require(ReplicatedStorage.RobloxPackages.motion.motion)

describe("motion", function()
	test("exports the animation API", function()
		expect(Motion.animate).toEqual(expect.any("function"))
		expect(Motion.useMotion).toEqual(expect.any("function"))
		expect(Motion.AnimatePresence).never.toBeNil()
	end)

	test("transition presets are populated", function()
		expect((next(Motion.TransitionPreset :: any))).never.toBeNil()
	end)
end)
