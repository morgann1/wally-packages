--!strict
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local Interposer = require(ReplicatedStorage.PluginLib.interposer.interposer)
local Leader = require(ReplicatedStorage.PluginLib.leader.leader)
local doCleanup = require(ReplicatedStorage.PluginLib["do-cleanup"]["do-cleanup"])

-- Leader runs over Interposer, whose medium lives under StudioService;
-- skip when the runner lacks plugin-level security.
local canUseStudioService = pcall(function()
	game:GetService("StudioService"):FindFirstChild("LeaderSpecProbe")
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

describe("leader", function()
	testWhenElevated("a lone peer elects itself and reports leadership", function()
		local scope: { unknown } = {}
		local api = Interposer.logon("Tests", `LeaderSpec-{HttpService:GenerateGUID(false)}`, scope)
		local tracker = Leader.track(scope, api)

		-- The search waits ~1s for other peers before self-electing.
		expect(tracker.leader()).toBe(nil)
		expect(tracker.selfIsLeader()).toBe(nil)

		local changes: { string? } = {}
		local disconnect = tracker.onLeaderChanged(function(newLeader)
			table.insert(changes, newLeader)
		end)

		expect(waitUntil(5, function()
			return tracker.leader() ~= nil
		end)).toBe(true)

		expect(tracker.leader()).toBe(api.selfPeer)
		expect(tracker.selfIsLeader()).toBe(true)
		expect(changes).toEqual({ api.selfPeer })

		disconnect()
		doCleanup(scope)
	end, 15000)
end)
