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

--[=[
	@class Leader

	Elects a single leader among plugin instances running in the same Studio
	session, over an [Interposer] peer network. Used when several copies of
	a plugin coexist (local dev rig plus installed copy) and exactly one
	should own a shared resource such as a toolbar.

	Election: each peer first asks the others `whoIsLeader`; a peer that
	claims itself is believed. If nobody knows, only the peer with the
	lexicographically lowest id self-elects (ids are GUIDs, so every peer
	agrees), which avoids the co-arrival race where all peers elect
	themselves in the same tick. A leader that shuts down hands leadership
	to another peer on the way out.
]=]

--[=[
	@within Leader
	@interface LeaderApi
	.leader () -> Peer? -- Current leader, or `nil` while undecided.
	.selfIsLeader () -> boolean? -- Whether this peer leads; `nil` while undecided.
	.onLeaderChanged Connect<Peer?> -- Fires whenever a different leader takes over.
]=]
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

--[=[
	@within Leader

	Joins the election and starts tracking leadership. The search runs on a
	background task registered into `scope`; cleaning up the scope stops
	tracking and, if this peer is the leader, hands leadership over first.

	@param scope { unknown } -- Cleanup scope (see doCleanup) owning the tracker's connections and task.
	@param interposer InterposerApi -- A logged-on Interposer session to elect over.
	@return LeaderApi
]=]
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
		-- pullWake yields, so the tie-break wait branch below actually sleeps instead of busy-looping.
		-- Fed by both peer discovery and leader-change events so the loop wakes for either signal.
		local pushWake, pullWake = PushPull.yield()
		table.insert(
			scope,
			interposer.onPeerDiscovered(function(peer: Interposer.Peer)
				pushPeer(peer)
				pushWake()
			end)
		)
		table.insert(
			scope,
			onLeaderChanged(function()
				pushWake()
			end)
		)
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
				-- Nobody knows who the leader is. To avoid a co-arrival race where every peer self-elects in the
				-- same tick (and each builds its own toolbar before any leaderChanged broadcast is observed), only
				-- the peer with the lexicographically lowest id self-elects. Everyone else loops and waits for the
				-- winner's broadcast. Peer ids are GUIDs (see Interposer.logon), so the ordering is stable and
				-- agreed by every peer.
				local shouldSelfElect = true
				for otherPeer in interposer.otherPeers do
					if otherPeer < interposer.selfPeer then
						shouldSelfElect = false
						break
					end
				end
				if shouldSelfElect then
					changeLeader(interposer.selfPeer, {
						broadcastChange = true,
					})
					return
				end
				-- Wait for the lower-id peer to broadcast or for a new peer to discover.
				pullWake()
				continue
			end
			possibleLeader = nil
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
