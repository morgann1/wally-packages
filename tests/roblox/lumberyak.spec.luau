--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local Lumberyak = require(ReplicatedStorage.RobloxPackages.lumberyak.lumberyak)

describe("lumberyak", function()
	test("constructs a logger", function()
		expect(Lumberyak.Logger.new).toEqual(expect.any("function"))
		local logger = Lumberyak.Logger.new(nil, "spec")
		expect(logger).never.toBeNil()
	end)
end)
