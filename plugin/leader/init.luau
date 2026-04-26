--!strict
-- (c) Studio Elttob 2024. All rights reserved, seek permission before use.

local Packages = script.Parent

local FinallyTask = require(Packages.FinallyTask)
local Event = require(Packages.Event)
local PushPull = require(Packages.PushPull)
local ty = require(Packages.ty)
local Maybe = require(Packages.Maybe)
local Interposer = require(Packages.Interposer)
local Types = require(script.Types)

export type LeaderApi = Types.LeaderApi

type Scope = { unknown }

local PROTOCOL = {
	id = "@StudioElttob/Leader",
	version = { major = 1, minor = 0, patch = 0 },
	staticInfo = ty.Nil,
	events = {
		leaderChanged = {
			argumentType = Interposer.Types.Peer,
		},
	},
	requests = {
		whoIsLeader = {
			argumentType = ty.Nil,
			returnType = Interposer.Types.Peer:Optional(),
		},
	},
}

local Leader = {}

function Leader.track(scope: Scope, interposer: Interposer.InterposerApi): Types.LeaderApi
	local currentLeader: Interposer.Peer? = nil
	local onLeaderChanged, doLeaderChanged: (Interposer.Peer?) -> () = Event()

	local protocolApi: Interposer.ProtocolApi<nil>

	local function changeLeader(
		newLeader: Interposer.Peer,
		options: {
			broadcastChange: boolean,
		}
	): boolean
		if options.broadcastChange then
			assert(protocolApi ~= nil, "Protocol needs to be connected to broadcast a leadership change")
			protocolApi.sendEvent("leaderChanged", "everyone", newLeader)
		end
		if currentLeader == newLeader then
			return false
		else
			currentLeader = newLeader
			doLeaderChanged(newLeader)
			return true
		end
	end

	protocolApi = interposer.connectProtocol(scope, PROTOCOL, nil, {
		events = {
			leaderChanged = function(fromPeer: Interposer.Peer, newLeader: Interposer.Peer): ()
				changeLeader(newLeader, {
					broadcastChange = false,
				})
			end,
		},
		requests = {
			whoIsLeader = function(fromPeer: Interposer.Peer): Interposer.Peer?
				return currentLeader
			end,
		},
	})

	local function searchForLeader(scope: Scope): ()
		task.wait(1) -- wait for other peers to arrive
		local pushPeer, pullPeer = PushPull.maybe()
		table.insert(scope, interposer.onPeerDiscovered(pushPeer))
		for peer in interposer.otherPeers do
			pushPeer(peer)
		end
		local possibleLeader: Interposer.Peer? = nil
		-- Important: this isn't just stopping the search when *we* decide a leader. Someone else might announce
		-- they're the leader now, or it might be set some other way, so we need to stop looking in that case too.
		while true do
			if currentLeader ~= nil then
				return
			end
			local nextPeer = if possibleLeader ~= nil then Maybe.some(possibleLeader) else pullPeer()
			if not nextPeer.some then
				-- Nobody knows who the leader is. We might be alone, or everyone might be confused. Best to just
				-- announce that we're the leader and get everyone on the same page.
				changeLeader(interposer.selfPeer, {
					broadcastChange = true,
				})
				return
			end
			local result = protocolApi.sendRequest("whoIsLeader", nextPeer.value)
			if result.ok then
				possibleLeader = result.value
				if possibleLeader ~= nil and possibleLeader == nextPeer.value then
					-- The peer has claimed they are their own leader. Let's believe them blindly!
					changeLeader(possibleLeader, {
						broadcastChange = false,
					})
					return
				end
			end
		end
	end

	local function stopLeading()
		if currentLeader == interposer.selfPeer then
			local nextLeader = next(interposer.otherPeers)
			if nextLeader ~= nil then
				changeLeader(nextLeader, {
					broadcastChange = true,
				})
			end
		end
	end

	table.insert(scope, {
		stopLeading,
		FinallyTask(task.spawn, searchForLeader),
	})

	local tracker = {}
	tracker.onLeaderChanged = onLeaderChanged

	function tracker.leader(): Interposer.Peer?
		return currentLeader
	end

	function tracker.selfIsLeader(): boolean?
		return if currentLeader == nil then nil else currentLeader == interposer.selfPeer
	end

	return tracker
end

return Leader
