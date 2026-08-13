--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local RbxDesignFoundations =
	require(ReplicatedStorage.RobloxPackages["rbx-design-foundations"]["rbx-design-foundations"])

describe("rbx-design-foundations", function()
	test("exports dark and light token generators", function()
		expect(RbxDesignFoundations.Tokens.Dark).toEqual(expect.any("function"))
		expect(RbxDesignFoundations.Tokens.Light).toEqual(expect.any("function"))
	end)
end)
