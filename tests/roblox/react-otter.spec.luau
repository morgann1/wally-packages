--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local ReactOtter = require(ReplicatedStorage.RobloxPackages["react-otter"]["react-otter"])

describe("react-otter", function()
	test("exports hooks and re-exports otter goals", function()
		expect(ReactOtter.useAnimatedBinding).toEqual(expect.any("function"))
		expect(ReactOtter.useMotor).toEqual(expect.any("function"))
		expect(ReactOtter.spring).toEqual(expect.any("function"))
	end)
end)
