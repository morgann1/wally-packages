--!strict
--!nolint LocalShadow
-- Originally (c) Studio Elttob 2024.

local Package = script.Parent

local Event = require(Package.Parent.Event)
local PushPull = require(Package.Parent.PushPull)
local ty = require(Package.Parent.ty)
local Types = require(Package.Types)

type Logger = { info: (...any) -> (), warn: (...any) -> () }
type MakeLog = (tag: string, enabled: boolean) -> Logger

local AWAIT_JOIN_TIMEOUT = 1.0

local ProtocolRespondData = ty.Tuple({ exhaustive = true }, {
	ty.Boolean, -- ok
	ty.Unknown, -- result
})

local function protocol<StaticInfo>(
	makeLog: MakeLog,
	scope: { unknown },
	selfPeer: Types.Peer,
	otherPeers: { [Types.Peer]: true },
	publicChannelApi: Types.ChannelApi,
	protocolDef: Types.ProtocolDef,
	staticInfo: StaticInfo,
	handlers: Types.ProtocolHandlers
): Types.ProtocolApi<StaticInfo>
	local logger = makeLog("protocol", false)

	assert(Types.NetworkSafe:Matches(staticInfo), "Protocol static info must be network safe")
	for name in protocolDef.events do
		assert(handlers.events[name] ~= nil, `Missing handler for event {name}`)
	end
	for name in protocolDef.requests do
		assert(handlers.requests[name] ~= nil, `Missing handler for request {name}`)
	end

	logger.info(`{selfPeer} - Setting up protocol {protocolDef.id}`)

	local onJoinedProtocol, doProtocolJoined: (Types.Peer, StaticInfo) -> () = Event()
	local onLeavingProtocol, doProtocolLeaving: (Types.Peer, StaticInfo) -> () = Event()
	local staticInfoMap: { [Types.Peer]: { info: StaticInfo } } = {
		[selfPeer] = { info = staticInfo },
	}

	local function waitUntilJoined(waitForPeer: Types.Peer, logReason: string): boolean
		if waitForPeer == selfPeer or staticInfoMap[waitForPeer] ~= nil then
			if otherPeers[waitForPeer] == nil then
				return true
			else
				logger.warn(
					`{selfPeer} - Protocol {protocolDef.id} is waiting for {waitForPeer} who had static info but is not known. This is probably a bug.`
				)
			end
		end
		logger.info(
			`{selfPeer} - Protocol {protocolDef.id} is now waiting for {waitForPeer} to join for {logReason} 🔄️`
		)
		local pushTimedOut, pullTimedOut = PushPull.yield()
		local joinConnection = onJoinedProtocol(function(joinedPeer: Types.Peer): ()
			if joinedPeer == waitForPeer then
				pushTimedOut(false)
			end
		end)
		local timeoutTask = task.delay(AWAIT_JOIN_TIMEOUT, function()
			pushTimedOut(true)
		end)
		local timedOut = pullTimedOut()
		joinConnection()
		pcall(task.cancel, timeoutTask)
		if timedOut then
			logger.warn(
				`{selfPeer} - Protocol {protocolDef.id} timed out while waiting for {waitForPeer} to join for {logReason} ⌛`
			)
		else
			logger.info(
				`{selfPeer} - Protocol {protocolDef.id} has now witnessed {waitForPeer} join for {logReason} ✅`
			)
		end

		return timedOut
	end

	local thisProtocolJoinedCode = `protocol/{protocolDef.id}/v{protocolDef.version.major}/joined`
	local thisProtocolLeavingCode = `protocol/{protocolDef.id}/v{protocolDef.version.major}/leaving`
	local thisProtocolStaticInfoCode = `protocol/{protocolDef.id}/v{protocolDef.version.major}/staticInfo`
	local thisProtocolDataCode = `protocol/{protocolDef.id}/v{protocolDef.version.major}/data`

	local thisProtocolJoinedMsg = {
		send = ty.Tuple({ exhaustive = true }, {
			ty.Just(thisProtocolJoinedCode),
			ty.Just(selfPeer), -- peer id
			protocolDef.staticInfo, -- static info
		}),
		receive = ty.Tuple({ exhaustive = true }, {
			ty.Just(thisProtocolJoinedCode),
			Types.KnownPeer(nil, otherPeers), -- peer id
			protocolDef.staticInfo, -- static info
		}),
	}
	local thisProtocolLeavingMsg = {
		send = ty.Tuple({ exhaustive = true }, {
			ty.Just(thisProtocolLeavingCode),
			ty.Just(selfPeer), -- peer id
		}),
		receive = ty.Tuple({ exhaustive = true }, {
			ty.Just(thisProtocolLeavingCode),
			Types.KnownPeer(nil, otherPeers), -- peer id
		}),
	}
	local thisProtocolStaticInfoMsg = {
		send = ty.Tuple({ exhaustive = true }, {
			ty.Just(thisProtocolStaticInfoCode),
			Types.KnownPeer(nil, otherPeers), -- to peer
		}),
		receive = ty.Tuple({ exhaustive = true }, {
			ty.Just(thisProtocolStaticInfoCode),
			ty.Just(selfPeer), -- to peer
		}),
		respond = ty.Tuple({ exhaustive = true }, {
			protocolDef.staticInfo,
		}),
	}
	local thisProtocolDataMsg = {
		send = ty.Tuple({ exhaustive = true }, {
			ty.Just(thisProtocolDataCode),
			ty.Just(""):Or(Types.KnownPeer(nil, otherPeers)), -- to peer
			ty.Just(selfPeer), -- from peer
			ty.String, -- event/request id
			ty.Unknown:Optional(), -- args
		}),
		receive = ty.Tuple({ exhaustive = true }, {
			ty.Just(thisProtocolDataCode),
			ty.Just(""):Or(ty.Just(selfPeer)), -- to peer
			Types.KnownPeer(nil, otherPeers), -- from peer
			ty.String, -- event/request id
			ty.Unknown:Optional(), -- args
		}),
	}

	table.insert(scope, {
		publicChannelApi.receive(
			function(args: { Types.NetworkSafe }, respond: Types.RespondCallback?): "continue" | "disconnect"
				if respond == nil and thisProtocolJoinedMsg.receive:Matches(args) then
					local joiningPeer = args[2] :: Types.Peer
					local maybeStaticInfo = protocolDef.staticInfo:Cast(args[3])
					if maybeStaticInfo.some then
						local staticInfo = maybeStaticInfo.value :: StaticInfo
						staticInfoMap[joiningPeer] = { info = staticInfo }
						logger.info(
							`{selfPeer} sees {joiningPeer} later join protocol {protocolDef.id} with info {staticInfo}`
						)
						doProtocolJoined(joiningPeer, staticInfo)
					end
				elseif respond == nil and thisProtocolLeavingMsg.receive:Matches(args) then
					local leavingPeer = args[2] :: Types.Peer
					local staticInfo = staticInfoMap[leavingPeer]
					if staticInfo ~= nil then
						doProtocolLeaving(leavingPeer, staticInfoMap[leavingPeer].info)
						staticInfoMap[leavingPeer] = nil
					end
				elseif respond ~= nil and thisProtocolStaticInfoMsg.receive:Matches(args) then
					respond({ staticInfo :: any })
				elseif thisProtocolDataMsg.receive:Matches(args) then
					local fromPeer = args[3] :: Types.Peer
					local id = args[4] :: string
					local handlerArgs = args[5]
					if respond == nil then
						local def = protocolDef.events[id]
						local eventHandler = handlers.events[id]
						if def ~= nil and eventHandler ~= nil and def.argumentType:Matches(handlerArgs) then
							task.spawn(eventHandler, fromPeer, handlerArgs)
						end
					else
						local def = protocolDef.requests[id]
						local requestHandler = handlers.requests[id]
						if def ~= nil and requestHandler ~= nil and def.argumentType:Matches(handlerArgs) then
							respond({ pcall(requestHandler, fromPeer, handlerArgs) })
						end
					end
				else
					if args[1] == thisProtocolDataCode and args[2] == selfPeer then
						logger.warn("Protocol.receive() did not match arguments format")
						warn("Expected", thisProtocolDataMsg.receive.ExpectsType)
						warn("Got", args)
						warn("Peers", otherPeers)
					end
				end
				return "continue"
			end
		),
	})

	for peer in otherPeers do
		logger.info(`{selfPeer} - Asking {peer} for their {protocolDef.id} static info...`)
		publicChannelApi.send(
			thisProtocolStaticInfoMsg.send:CastOrError({ thisProtocolStaticInfoCode :: any, peer }) :: any,
			function(args: { Types.NetworkSafe }): "continue" | "disconnect"
				if thisProtocolStaticInfoMsg.respond:Matches(args) then
					staticInfoMap[peer] = { info = args[1] :: any }
					doProtocolJoined(peer, staticInfoMap[peer].info)
					logger.info(`{selfPeer} received initial {protocolDef.id} static info {staticInfo} from {peer}`)
				else
					logger.warn(
						`{selfPeer} - {protocolDef.id} static info response from {peer} did not match arguments format`
					)
				end
				return "disconnect"
			end,
			1.0,
			function()
				logger.warn(
					`{selfPeer} - Timed out while waiting for {peer} to send their {protocolDef.id} static info`
				)
			end
		)
	end

	local protocolApi = {}
	protocolApi.staticInfoMap = staticInfoMap
	protocolApi.onJoinedProtocol = onJoinedProtocol
	protocolApi.onLeavingProtocol = onLeavingProtocol

	onLeavingProtocol(function(joinedPeer, staticInfo)
		logger.info(`{selfPeer} sees {joinedPeer} leave protocol {protocolDef.id} with info {staticInfo}`)
	end)

	function protocolApi.sendEvent(id: string, toPeer: Types.Peer | "everyone", args: any): ()
		task.spawn(function()
			if toPeer == selfPeer then
				handlers.events[id](selfPeer, args)
			elseif toPeer == "everyone" or waitUntilJoined(toPeer, `event {id}`) then
				local ok, result = pcall(function()
					local def = protocolDef.events[id]
					assert(def ~= nil, `No {id} event defined for protocol {protocolDef.id}`)
					publicChannelApi.send(thisProtocolDataMsg.send:CastOrError({
						thisProtocolDataCode,
						if toPeer == "everyone" then "" else toPeer,
						selfPeer,
						id,
						def.argumentType:CastOrError(args) :: any,
					}) :: any)
				end)
				if not ok then
					error(`Error while sending protocol event {id} to {toPeer or "(everyone)"}: {result}`)
				end
			end
		end)
	end

	function protocolApi.sendRequest(id: string, toPeer: Types.Peer, args: any): Types.RequestResult<any>
		if toPeer == selfPeer then
			local ok, result = pcall(handlers.requests[id], selfPeer, args)
			if ok then
				return { ok = true, value = result }
			else
				return { ok = false, because = "error", err = result }
			end
		end
		local def = protocolDef.requests[id]
		assert(def ~= nil, `No {id} request defined for protocol {protocolDef.id}`)
		assert(def.argumentType:Matches(args), `Arguments of {id} request don't match the type definition`)
		if not waitUntilJoined(toPeer, `request {id}`) then
			return { ok = false, because = "timeout" }
		end
		local pushReturn, pullReturn: () -> Types.RequestResult<any> = PushPull.yield()
		publicChannelApi.send(
			thisProtocolDataMsg.send:CastOrError({ thisProtocolDataCode, toPeer, selfPeer, id, args }) :: any,
			function(args: { Types.NetworkSafe }): "continue" | "disconnect"
				if ProtocolRespondData:Matches(args) then
					local ok = args[1]
					local returned = args[2]
					if not ok then
						if typeof(returned) == "string" then
							pushReturn({ ok = false, because = "error", err = returned })
							return "disconnect"
						else
							logger.warn("Protocol.send() error response was expected to be string")
						end
					else
						if def.returnType:Matches(returned) then
							pushReturn({ ok = true, value = returned })
							return "disconnect"
						else
							logger.warn("Protocol.send() OK response did not match protocol schema")
						end
					end
				else
					logger.warn("Protocol.send() response did not match arguments format")
				end
				return "continue"
			end,
			1.0,
			function()
				pushReturn({ ok = false, because = "timeout" })
			end
		)
		return pullReturn()
	end

	logger.info(`{selfPeer} - Sending join code for protocol {protocolDef.id}`)
	publicChannelApi.send(
		thisProtocolJoinedMsg.send:CastOrError({ thisProtocolJoinedCode :: any, selfPeer, staticInfo }) :: any
	)

	table.insert(scope, function()
		logger.info(`{selfPeer} - Sending leave code for protocol {protocolDef.id}`)
		publicChannelApi.send(
			thisProtocolLeavingMsg.send:CastOrError({ thisProtocolLeavingCode :: any, selfPeer }) :: any
		)
	end)

	return protocolApi
end

return protocol
