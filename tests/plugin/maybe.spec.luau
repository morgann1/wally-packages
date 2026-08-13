--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local Maybe = require(ReplicatedStorage.PluginLib.maybe.maybe)

describe("maybe", function()
	test("some wraps a value", function()
		expect(Maybe.some(42)).toEqual({ some = true, value = 42 })
		expect(Maybe.some(nil :: any)).toEqual({ some = true })
	end)

	test("none carries a reason", function()
		expect(Maybe.none("missing")).toEqual({ some = false, reason = "missing" })
	end)
end)
