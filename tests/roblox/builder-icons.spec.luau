--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local BuilderIcons = require(ReplicatedStorage.RobloxPackages["builder-icons"]["builder-icons"])

describe("builder-icons", function()
	test("exports the icon component and helpers", function()
		expect(BuilderIcons.Icon).never.toBeNil()
		expect(BuilderIcons.Font).never.toBeNil()
		expect(BuilderIcons.getBuilderIconForKeycode).toEqual(expect.any("function"))
	end)

	test("migration table maps legacy icon names", function()
		expect((next(BuilderIcons.Migration))).never.toBeNil()
	end)
end)
