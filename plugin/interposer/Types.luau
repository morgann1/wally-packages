--!strict
-- Originally (c) Studio Elttob 2024.

local Package = script.Parent

local Event = require(Package.Parent.Event)
local ty = require(Package.Parent.ty)
local isNetworkSafe = require(Package.isNetworkSafe)

local Types = {}

export type Peer = string
Types.Peer = ty.String
Types.KnownPeer = function(selfPeer: Peer?, otherPeers: { [Peer]: true }): ty.Def
	local isKnown = if selfPeer == nil
		then function(x: any)
			return otherPeers[x] == true
		end
		else function(x: any)
			return x == selfPeer or otherPeers[x] == true
		end
	return Types.Peer:And(ty.Predicate(isKnown))
end

export type NetworkSafe = number | boolean | string | nil | { NetworkSafe } | { [string]: NetworkSafe }
Types.NetworkSafe = ty.Predicate(isNetworkSafe)

export type RespondCallback = (args: { NetworkSafe }) -> ()

export type ReceiveHandler = (args: { NetworkSafe }, respond: RespondCallback?) -> "continue" | "disconnect"

export type ResponseHandler = (args: { NetworkSafe }) -> "continue" | "disconnect"

export type ChannelApi = {
	send: (
		args: { NetworkSafe },
		responseHandler: ResponseHandler?,
		timeout: number?,
		timeoutHandler: (() -> ())?
	) -> (() -> ())?,
	receive: (receiveHandler: ReceiveHandler) -> () -> (),
}

export type ProtocolEventDef = {
	argumentType: ty.Def,
}
export type ProtocolRequestDef = {
	argumentType: ty.Def,
	returnType: ty.Def,
}
export type ProtocolDef = {
	id: string,
	version: { major: number, minor: number, patch: number },
	staticInfo: ty.Def,
	events: { [string]: ProtocolEventDef },
	requests: { [string]: ProtocolRequestDef },
}

export type ProtocolEventHandler = (fromPeer: Peer, args: any) -> ()
export type ProtocolRequestHandler = (fromPeer: Peer, args: any) -> any
export type ProtocolHandlers = {
	events: { [string]: ProtocolEventHandler },
	requests: { [string]: ProtocolRequestHandler },
}

export type RequestOk<Value> = { ok: true, value: Value }
export type RequestError = { ok: false, because: "error", err: string }
export type RequestTimeout = { ok: false, because: "timeout" }
export type RequestResult<Value> = RequestOk<Value> | RequestError | RequestTimeout

export type ProtocolApi<StaticInfo> = {
	onJoinedProtocol: Event.Connect<Peer, StaticInfo>,
	onLeavingProtocol: Event.Connect<Peer, StaticInfo>,
	staticInfoMap: { [Peer]: { info: StaticInfo } },
	sendEvent: (id: string, toPeer: Peer | "everyone", args: any) -> (),
	sendRequest: (id: string, toPeer: Peer, args: any) -> RequestResult<any>,
}

export type InterposerApi = {
	selfPeer: Peer,
	otherPeers: { [Peer]: true },
	onPeerDiscovered: Event.Connect<Peer>,
	onPeerForgetting: Event.Connect<Peer>,

	connectProtocol: <StaticInfo>(
		scope: { unknown },
		protocolDef: ProtocolDef,
		staticInfo: StaticInfo,
		handlers: ProtocolHandlers
	) -> ProtocolApi<StaticInfo>,
}

return Types
