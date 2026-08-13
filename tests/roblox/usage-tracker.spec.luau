--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

-- Requiring this package at all proves the FindFirstAncestor re-casing:
-- isReactComponent resolves its Packages folder via
-- script:FindFirstAncestor("usage-tracker") at require time.
local UsageTracker = require(ReplicatedStorage.RobloxPackages["usage-tracker"]["usage-tracker"])

describe("usage-tracker", function()
	test("isReactComponent answers for plain values", function()
		expect(typeof(UsageTracker.isReactComponent(function() end))).toBe("boolean")
		expect(UsageTracker.isReactComponent(5)).toBe(false)
	end)

	test("exports the usage graph API", function()
		expect(UsageTracker.trackMemberAccess).toEqual(expect.any("function"))
		expect(UsageTracker.getUsageGraph).toEqual(expect.any("function"))
	end)
end)
