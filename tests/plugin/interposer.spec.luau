--!strict
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local Interposer = require(ReplicatedStorage.PluginLib.interposer.interposer)
local doCleanup = require(ReplicatedStorage.PluginLib["do-cleanup"]["do-cleanup"])

-- Interposer's shared medium lives under StudioService, which needs
-- plugin-level security. Skip (rather than fail) when the test runner
-- doesn't have it.
local canUseStudioService = pcall(function()
	game:GetService("StudioService"):FindFirstChild("InterposerSpecProbe")
end)
local testWhenElevated: typeof(test) = if canUseStudioService then test else test.skip :: any

local function waitUntil(deadlineSeconds: number, condition: () -> boolean): boolean
	local deadline = os.clock() + deadlineSeconds
	while os.clock() < deadline do
		if condition() then
			return true
		end
		task.wait()
	end
	return condition()
end

describe("interposer", function()
	testWhenElevated("two logons on the same medium discover each other", function()
		local mediumName = `InterposerSpec-{HttpService:GenerateGUID(false)}`
		local scope1: { unknown } = {}
		local scope2: { unknown } = {}

		local api1 = Interposer.logon("Tests", mediumName, scope1)
		expect(api1.selfPeer).toEqual(expect.any("string"))

		local api2 = Interposer.logon("Tests", mediumName, scope2)

		expect(waitUntil(5, function()
			return api1.otherPeers[api2.selfPeer] == true and api2.otherPeers[api1.selfPeer] == true
		end)).toBe(true)

		-- Logging off broadcasts a leave; the remaining peer forgets it.
		doCleanup(scope2)
		expect(waitUntil(5, function()
			return api1.otherPeers[api2.selfPeer] == nil
		end)).toBe(true)

		doCleanup(scope1)
	end, 15000)

	testWhenElevated("logons on different mediums stay isolated", function()
		local scope1: { unknown } = {}
		local scope2: { unknown } = {}

		local api1 = Interposer.logon("Tests", `InterposerSpecA-{HttpService:GenerateGUID(false)}`, scope1)
		local api2 = Interposer.logon("Tests", `InterposerSpecB-{HttpService:GenerateGUID(false)}`, scope2)

		expect(waitUntil(1, function()
			return api1.otherPeers[api2.selfPeer] ~= nil
		end)).toBe(false)

		doCleanup(scope2)
		doCleanup(scope1)
	end, 15000)
end)
