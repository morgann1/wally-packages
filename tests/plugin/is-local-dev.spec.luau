--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local IsLocalDev = require(ReplicatedStorage.PluginLib["is-local-dev"]["is-local-dev"])

describe("is-local-dev", function()
	test("finds a marker that appears in the call stack", function()
		-- This spec lives under ReplicatedStorage.Tests, so "Tests" is on
		-- the traceback while a made-up name is not.
		expect(IsLocalDev("Tests")).toBe(true)
	end)

	test("rejects a marker that is absent from the call stack", function()
		expect(IsLocalDev("NotARealDevEnvName1234")).toBe(false)
	end)

	test("matches literally, not as a Lua pattern", function()
		expect(IsLocalDev("Tes%a")).toBe(false)
	end)
end)
