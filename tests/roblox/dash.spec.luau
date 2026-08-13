--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local Dash = require(ReplicatedStorage.RobloxPackages.dash.dash)

describe("dash", function()
	test("map transforms values", function()
		local doubled = Dash.map({ 1, 2, 3 }, function(value)
			return value * 2
		end)
		expect(doubled).toEqual({ 2, 4, 6 })
	end)

	test("shallowEqual compares tables", function()
		expect(Dash.shallowEqual({ a = 1 }, { a = 1 })).toBe(true)
		expect(Dash.shallowEqual({ a = 1 }, { a = 2 })).toBe(false)
	end)
end)
