--!strict
-- Originally (c) Studio Elttob 2024.

--[=[
	@class Interposer

	Cross-plugin RPC layer for Roblox Studio. A `BindableEvent` parented
	to `StudioService` acts as the public medium that every cooperating
	plugin shares. Each plugin calls [Interposer.logon] to join the
	medium, discover other peers, and register typed protocols.

	Slight deviation from the upstream: the dev-env name (used by
	[IsLocalDev] and the [ElttobLog] logger prefix) is a parameter rather
	than the hardcoded `"Suite"`, so plugins can stand up their own
	Interposer instances without colliding on log output.
]=]

local HttpService = game:GetService("HttpService")

local Package = script.Parent

local ElttobLog = require(Package.ElttobLog)
local Event = require(Package.Event)
local IsLocalDev = require(Package.IsLocalDev)

local Types = require(script.Types)
local channel = require(script.channel)
local protocol = require(script.protocol)

export type Peer = Types.Peer
export type NetworkSafe = Types.NetworkSafe
export type RespondCallback = Types.RespondCallback
export type ReceiveHandler = Types.ReceiveHandler
export type ResponseHandler = Types.ResponseHandler
export type ChannelApi = Types.ChannelApi
export type ProtocolEventDef = Types.ProtocolEventDef
export type ProtocolRequestDef = Types.ProtocolRequestDef
export type ProtocolDef = Types.ProtocolDef
export type ProtocolEventHandler = Types.ProtocolEventHandler
export type ProtocolRequestHandler = Types.ProtocolRequestHandler
export type ProtocolHandlers = Types.ProtocolHandlers
export type RequestOk<T> = Types.RequestOk<T>
export type RequestError = Types.RequestError
export type RequestTimeout = Types.RequestTimeout
export type RequestResult<T> = Types.RequestResult<T>
export type ProtocolApi<StaticInfo> = Types.ProtocolApi<StaticInfo>
export type InterposerApi = Types.InterposerApi

local function locatePublicMedium(mediumName: string): BindableEvent
	local MEDIUM_PARENT = game:GetService("StudioService")
	do
		local existingMedium = MEDIUM_PARENT:FindFirstChild(mediumName)
		if existingMedium ~= nil then
			if existingMedium:IsA("BindableEvent") then
				return existingMedium
			else
				existingMedium.Name ..= "_OLD"
			end
		end
	end
	local medium = Instance.new("BindableEvent")
	medium.Name = mediumName
	medium.Archivable = false
	medium.Parent = MEDIUM_PARENT
	return medium
end

local Interposer = {}

Interposer.Types = Types

--[=[
	@within Interposer
	@function logon

	Joins the shared Interposer medium and returns an [InterposerApi] for
	tracking peers and registering protocols.

	@param devEnvName string -- Identifier passed to [IsLocalDev] and used as the log prefix; lets plugins stand up isolated dev/prod instances.
	@param mediumName string -- Name of the `BindableEvent` parented under `StudioService` that peers communicate through. Plugins sharing a name see each other; plugins on different names form isolated channels.
	@param scope { unknown } -- Cleanup scope; teardown functions and connections are appended here.
	@return InterposerApi
]=]
function Interposer.logon(devEnvName: string, mediumName: string, scope: { unknown }): Types.InterposerApi
	local makeLog = ElttobLog(devEnvName)
	local logger = makeLog("Interposer", true)
	local isLocalDev = IsLocalDev(devEnvName)
	local INTERPOSER_VERSION = if isLocalDev then 0 else 1

	local publicMedium = locatePublicMedium(mediumName)
	local publicChannel = channel(publicMedium)
	local selfPeer: Types.Peer = HttpService:GenerateGUID()
	local otherPeers: { [Types.Peer]: true } = {}
	local onPeerDiscovered, doPeerDiscovered: (Types.Peer) -> () = Event()
	local onPeerForgetting, doPeerForgetting: (Types.Peer) -> () = Event()
	local protocols: { [string]: Types.ProtocolApi<unknown> } = {}

	local function tryDiscoverPeer(newPeer: Types.Peer, theirVersionNumber: number): boolean
		if theirVersionNumber < INTERPOSER_VERSION then
			logger.info(`[{selfPeer}] Sorry {newPeer} - too ancient`)
			return false
		elseif theirVersionNumber > INTERPOSER_VERSION then
			-- We're outdated - don't talk to more modern peers.
			if not isLocalDev then
				logger.warn(`[{selfPeer}] Sorry {newPeer} - too modern!`)
			end
			return false
		end
		logger.info(`[{selfPeer}] Greetings {newPeer}`)
		otherPeers[newPeer] = true
		doPeerDiscovered(newPeer)
		return true
	end

	local function forgetPeer(leavingPeer: Types.Peer): ()
		logger.info(`[{selfPeer}] Farewell {leavingPeer}`)
		doPeerForgetting(leavingPeer)
		otherPeers[leavingPeer] = nil
	end

	table.insert(
		scope,
		publicChannel.receive(
			function(args: { Types.NetworkSafe }, respond: Types.RespondCallback?): "continue" | "disconnect"
				local code = table.remove(args, 1)
				if code == "Interposer/join" then
					if
						#args == 2
						and typeof(args[1]) == "string"
						and typeof(args[2]) == "number"
						and respond ~= nil
					then
						local joinedPeer = args[1] :: Types.Peer
						local joinedVersionNumber = args[2] :: number
						if joinedPeer ~= selfPeer then
							task.spawn(tryDiscoverPeer, joinedPeer, joinedVersionNumber)
							respond({ selfPeer, INTERPOSER_VERSION })
						end
					end
				elseif code == "Interposer/leave" then
					if #args == 1 and typeof(args[1]) == "string" and respond == nil then
						local leavingPeerId = args[1] :: Types.Peer
						if leavingPeerId ~= selfPeer then
							task.spawn(forgetPeer, leavingPeerId)
						end
					end
				end

				return "continue"
			end
		)
	)

	table.insert(scope, function()
		logger.info(`[{selfPeer}] Goodbye`)
		publicChannel.send({ "Interposer/leave", selfPeer }, nil, 1.0)
	end)

	-- This absolutely *must* happen after connecting to receive
	-- "Interposer/join" codes, otherwise there is a span where we can
	-- miss joins in parallel.
	logger.info(`[{selfPeer}] Hello (Interposer version {INTERPOSER_VERSION})`)
	publicChannel.send(
		{ "Interposer/join" :: any, selfPeer, INTERPOSER_VERSION },
		function(args: { Types.NetworkSafe }): "continue" | "disconnect"
			if #args == 2 and typeof(args[1]) == "string" and typeof(args[2]) == "number" then
				local respondingPeer = args[1] :: Types.Peer
				local theirVersionNumber = args[2] :: number
				if respondingPeer ~= selfPeer then
					task.spawn(tryDiscoverPeer, respondingPeer, theirVersionNumber)
				end
			end
			return "continue"
		end,
		1.0
	)

	local interposerApi = {}
	interposerApi.selfPeer = selfPeer
	interposerApi.otherPeers = otherPeers
	interposerApi.onPeerDiscovered = onPeerDiscovered
	interposerApi.onPeerForgetting = onPeerForgetting

	function interposerApi.connectProtocol<StaticInfo>(
		scope: { unknown },
		protocolDef: ProtocolDef,
		staticInfo: StaticInfo,
		handlers: ProtocolHandlers
	): ProtocolApi<StaticInfo>
		assert(protocols[protocolDef.id] == nil, `Attempt to double-register the {protocolDef.id} protocol`)
		local thisProtocol =
			protocol(makeLog, scope, selfPeer, otherPeers, publicChannel, protocolDef, staticInfo, handlers)
		protocols[protocolDef.id] = thisProtocol
		table.insert(scope, function()
			protocols[protocolDef.id] = nil
		end)
		return thisProtocol
	end

	return interposerApi
end

return Interposer
