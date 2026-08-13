--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local ReactUtils = require(ReplicatedStorage.RobloxPackages["react-utils"]["react-utils"])

describe("react-utils", function()
	test("exports hooks and ContextStack", function()
		expect(ReactUtils.ContextStack).never.toBeNil()
		expect(ReactUtils.useForwardRef).toEqual(expect.any("function"))
		expect(ReactUtils.useToggleState).toEqual(expect.any("function"))
	end)
end)
