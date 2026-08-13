--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local FoundationImages = require(ReplicatedStorage.RobloxPackages["foundation-images"]["foundation-images"])

describe("foundation-images", function()
	test("exports the image set and resolution helper", function()
		expect((next(FoundationImages.Images))).never.toBeNil()
		expect(FoundationImages.getResolutionScale).toEqual(expect.any("function"))
	end)
end)
