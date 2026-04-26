--!strict
--!nolint LocalShadow
-- Originally (c) Studio Elttob 2024.

--[=[
	@class SharedToolbar

	Cross-plugin shared toolbar built on top of [Interposer] and
	[Leader]. Every cooperating plugin calls [SharedToolbar.connect] with
	the same `toolbarId`; the leader builds a single `PluginToolbar`
	that mirrors every peer's buttons, and click/state events are
	forwarded back to the originating peer.

	Slight deviation from upstream: drops Fusion entirely. State lives in
	plain values that get re-applied to the underlying [OwnedToolbar]
	when they change, and lifetime is tracked through `{ unknown }`
	scopes cleaned up via [DoCleanup].
]=]

local DoCleanup = require(script.Parent.DoCleanup)
local ElttobLog = require(script.Parent.ElttobLog)
local Event = require(script.Parent.Event)
local FinallyTask = require(script.Parent.FinallyTask)
local IconRamp = require(script.Parent.IconRamp)
local Interposer = require(script.Parent.Interposer)
local Leader = require(script.Parent.Leader)
local OwnedToolbar = require(script.Parent.OwnedToolbar)
local PushPull = require(script.Parent.PushPull)
local React = require(script.Parent.React)
local SortingBy = require(script.Parent.SortingBy)
local ty = require(script.Parent.ty)

local Types = require(script.Types)

export type ButtonSpec = Types.ButtonSpec
export type ButtonState = Types.ButtonState
export type SharedToolbarApi = Types.SharedToolbarApi

type ButtonSpecWithId = {
	stableId: string,
	buttonId: string,
	spec: Types.ButtonSpec,
}
local BUTTON_SORTER = SortingBy(function(button: ButtonSpecWithId)
	return {
		button.spec.creationOrder,
		button.stableId,
		button.spec.displayName,
	}
end)

-- After discovering a button to add to the toolbar, wait this long for any
-- others to be added, so they can be sorted as a batch.
local OWNED_BUTTON_BATCH_PERIOD = 0.5

local UNBOUND_BUTTON_ICON: IconRamp.IconRamp = {
	{
		size = 64,
		variants = {
			light = "",
			dark = "",
			mono = "",
		},
	},
	{
		size = 512,
		variants = {
			light = "",
			dark = "",
			mono = "",
		},
	},
}

local SharedToolbar = {}

--[=[
	@within SharedToolbar
	@function connect

	Joins (or starts) the shared toolbar identified by `toolbarId`. The
	caller's `ourPrivateButtons` are buttons only this peer knows about;
	`ourSharedButtons` are advertised to every other peer via the
	Interposer protocol and clicks are routed back here.

	@param scope { unknown } -- Cleanup scope for connections, threads, and child scopes.
	@param plugin Plugin -- Used by the underlying [OwnedToolbar].
	@param devEnvName string -- Identifier for [IsLocalDev]/[ElttobLog].
	@param interposer Interposer.InterposerApi -- Already-connected Interposer.
	@param leader Leader.LeaderApi -- Already-connected Leader.
	@param protocolNamespace string -- Stable namespace for the underlying Interposer protocol id (e.g. `"@my-suite/SharedToolbar"`). Plugins sharing both `protocolNamespace` and `toolbarId` see each other.
	@param toolbarId string -- Stable identifier for this toolbar; every peer must agree on it.
	@param toolbarTitle string -- Human-readable name shown in Studio.
	@param thisStableId string -- Stable identifier for this peer; usually the plugin's package name.
	@param ourPrivateButtons { [string]: ButtonSpec }
	@param ourSharedButtons { [string]: ButtonSpec }
	@return SharedToolbarApi
]=]
function SharedToolbar.connect(
	scope: { unknown },
	plugin: Plugin,
	devEnvName: string,
	interposer: Interposer.InterposerApi,
	leader: Leader.LeaderApi,
	protocolNamespace: string,
	toolbarId: string,
	toolbarTitle: string,
	thisStableId: string,
	ourPrivateButtons: { [string]: Types.ButtonSpec },
	ourSharedButtons: { [string]: Types.ButtonSpec }
): Types.SharedToolbarApi
	local logger = ElttobLog(devEnvName)("SharedToolbar", false)

	for id in ourPrivateButtons do
		assert(ourSharedButtons[id] == nil, `Private and shared button share the same id: {id}`)
	end
	for id in ourSharedButtons do
		assert(ourPrivateButtons[id] == nil, `Private and shared button share the same id: {id}`)
	end

	local PROTOCOL: Interposer.ProtocolDef = {
		id = `{protocolNamespace}/{toolbarId}`,
		version = { major = 1, minor = 0, patch = 0 },
		staticInfo = Types.ProtocolStaticInfo,
		events = {
			onSharedClick = {
				argumentType = ty.Struct({ exhaustive = false }, {
					buttonId = ty.String,
				}),
			},
			setActive = {
				argumentType = ty.Struct({ exhaustive = false }, {
					buttonId = ty.String,
					isActive = ty.Boolean,
				}),
			},
			setClickableWhenViewportHidden = {
				argumentType = ty.Struct({ exhaustive = false }, {
					buttonId = ty.String,
					clickableWhenViewportHidden = ty.Boolean,
				}),
			},
			setIconRamp = {
				argumentType = ty.Struct({ exhaustive = false }, {
					buttonId = ty.String,
					iconRamp = IconRamp.Types.IconRamp,
				}),
			},
		},
		requests = {},
	}

	local onClick, doClick: (string) -> () = Event()
	local protocolApi: Interposer.ProtocolApi<Types.ProtocolStaticInfo>
	local currentOwnedToolbar: OwnedToolbar.OwnedToolbarApi? = nil

	type ButtonStateUpdaters = {
		iconRamp: React.BindingUpdater<IconRamp.IconRamp>,
		clickableWhenViewportHidden: React.BindingUpdater<boolean>,
		active: React.BindingUpdater<boolean>,
	}
	local buttonScopes: { [string]: { unknown } } = {}
	local buttonStates: { [string]: Types.ButtonState } = {}
	local buttonUpdaters: { [string]: ButtonStateUpdaters } = {}

	local function peerFromStableId(stableId: string): Interposer.Peer?
		for peer, staticInfo in protocolApi.staticInfoMap do
			if staticInfo.info.stableId == stableId then
				return peer
			end
		end
		return nil
	end

	local function stableIdFromPeer(peer: Interposer.Peer): string?
		local staticInfo = protocolApi.staticInfoMap[peer]
		if staticInfo == nil then
			return nil
		end
		return staticInfo.info.stableId
	end

	local function applyButtonStateToOwnedToolbar(hybridId: string)
		if currentOwnedToolbar == nil then
			return
		end
		local state = buttonStates[hybridId]
		if state == nil then
			return
		end
		-- Reuse path: displayName / tooltip params are unused once the
		-- button exists, so empty strings are safe sentinels.
		currentOwnedToolbar.initOrReuseButton(
			hybridId,
			state.iconRamp:getValue(),
			"",
			"",
			state.active:getValue(),
			state.clickableWhenViewportHidden:getValue()
		)
	end

	local function sendButtonClick(stableId: string, buttonId: string): ()
		if stableId == thisStableId then
			doClick(buttonId)
		else
			local sendToPeer = peerFromStableId(stableId)
			if sendToPeer == nil then
				logger.warn(`Couldn't figure out who {stableId} is`)
			else
				protocolApi.sendEvent("onSharedClick", sendToPeer, {
					buttonId = buttonId,
				})
			end
		end
	end

	local function setButtonActive(
		stableId: string,
		buttonId: string,
		isActive: boolean,
		options: { broadcastChange: boolean }
	): ()
		local hybridId = `{stableId}/{buttonId}`
		local updaters = buttonUpdaters[hybridId]
		assert(updaters ~= nil, `No button state for {hybridId}`)
		updaters.active(isActive)
		applyButtonStateToOwnedToolbar(hybridId)
		if options.broadcastChange then
			local sendToPeer = peerFromStableId(stableId)
			if sendToPeer == nil then
				logger.warn(`Couldn't figure out who {stableId} is`)
			else
				protocolApi.sendEvent("setActive", sendToPeer, {
					buttonId = buttonId,
					isActive = isActive,
				})
			end
		end
	end

	local function setButtonClickableWhenViewportHidden(
		stableId: string,
		buttonId: string,
		clickableWhenViewportHidden: boolean,
		options: { broadcastChange: boolean }
	): ()
		local hybridId = `{stableId}/{buttonId}`
		local updaters = buttonUpdaters[hybridId]
		assert(updaters ~= nil, `No button state for {hybridId}`)
		updaters.clickableWhenViewportHidden(clickableWhenViewportHidden)
		applyButtonStateToOwnedToolbar(hybridId)
		if options.broadcastChange then
			local sendToPeer = peerFromStableId(stableId)
			if sendToPeer == nil then
				logger.warn(`Couldn't figure out who {stableId} is`)
			else
				protocolApi.sendEvent("setClickableWhenViewportHidden", sendToPeer, {
					buttonId = buttonId,
					clickableWhenViewportHidden = clickableWhenViewportHidden,
				})
			end
		end
	end

	local function setButtonIconRamp(
		stableId: string,
		buttonId: string,
		iconRamp: IconRamp.IconRamp,
		options: { broadcastChange: boolean }
	): ()
		local hybridId = `{stableId}/{buttonId}`
		local updaters = buttonUpdaters[hybridId]
		assert(updaters ~= nil, `No button state for {hybridId}`)
		updaters.iconRamp(iconRamp)
		applyButtonStateToOwnedToolbar(hybridId)
		if options.broadcastChange then
			local sendToPeer = peerFromStableId(stableId)
			if sendToPeer == nil then
				logger.warn(`Couldn't figure out who {stableId} is`)
			else
				protocolApi.sendEvent("setIconRamp", sendToPeer, {
					buttonId = buttonId,
					iconRamp = iconRamp,
				})
			end
		end
	end

	local ownedButtonCreationQueue: { ButtonSpecWithId } = {}
	local ownedButtonCreatorTask: thread? = nil
	table.insert(scope, function()
		if ownedButtonCreatorTask ~= nil then
			task.cancel(ownedButtonCreatorTask)
			ownedButtonCreatorTask = nil
		end
	end)

	local function createOwnedButtonSoon(stableId: string, buttonId: string, spec: Types.ButtonSpec): ()
		table.insert(ownedButtonCreationQueue, { stableId = stableId, buttonId = buttonId, spec = spec })
		if ownedButtonCreatorTask == nil then
			ownedButtonCreatorTask = task.delay(OWNED_BUTTON_BATCH_PERIOD, function()
				ownedButtonCreatorTask = nil
				assert(currentOwnedToolbar ~= nil, "Attempt to create owned buttons without an owned toolbar")
				local thisQueue = ownedButtonCreationQueue
				ownedButtonCreationQueue = {}

				table.sort(thisQueue, BUTTON_SORTER)

				for _, queued in thisQueue do
					local queuedHybridId = `{queued.stableId}/{queued.buttonId}`
					logger.info(`[{interposer.selfPeer}] adding {queuedHybridId} button as an owned button`)
					local queuedButtonScope = buttonScopes[queuedHybridId]
					assert(queuedButtonScope ~= nil, `Attempt to create owned button for unknown {queuedHybridId}`)
					local queuedButtonState = buttonStates[queuedHybridId]
					local queuedButtonUpdaters = buttonUpdaters[queuedHybridId]
					local queuedOwnedButton = currentOwnedToolbar.initOrReuseButton(
						queuedHybridId,
						queuedButtonState.iconRamp:getValue(),
						queued.spec.displayName,
						queued.spec.toolTip,
						queuedButtonState.active:getValue(),
						queuedButtonState.clickableWhenViewportHidden:getValue()
					)
					table.insert(queuedButtonScope, {
						function()
							queuedButtonUpdaters.iconRamp(UNBOUND_BUTTON_ICON)
							applyButtonStateToOwnedToolbar(queuedHybridId)
						end :: any,
						queuedOwnedButton.instance.Click:Connect(function()
							sendButtonClick(queued.stableId, queued.buttonId)
						end),
					})
				end
			end)
		end
	end

	local function createOwnedToolbar()
		assert(currentOwnedToolbar == nil, "Attempt to double-create the owned toolbar")
		local ownedToolbar = OwnedToolbar.create(plugin, devEnvName, toolbarTitle)
		currentOwnedToolbar = ownedToolbar
		table.insert(scope, function()
			currentOwnedToolbar = nil
			ownedToolbar:destroy()
		end)

		for buttonId, spec in ourPrivateButtons do
			createOwnedButtonSoon(thisStableId, buttonId, spec)
		end
		for buttonId, spec in ourSharedButtons do
			createOwnedButtonSoon(thisStableId, buttonId, spec)
		end
		for peer, staticInfo in protocolApi.staticInfoMap do
			if peer ~= interposer.selfPeer then
				for buttonId, spec in staticInfo.info.buttonSpecs do
					createOwnedButtonSoon(staticInfo.info.stableId, buttonId, spec)
				end
			end
		end
	end

	local function discoverButton(stableId: string, buttonId: string, spec: Types.ButtonSpec): ()
		logger.info(`[{interposer.selfPeer}] adding {stableId}/{buttonId} button`)
		local hybridId = `{stableId}/{buttonId}`
		assert(buttonScopes[hybridId] == nil, `Attempt to double-discover button {hybridId}`)
		local buttonScope: { unknown } = {}
		buttonScopes[hybridId] = buttonScope
		local iconRampBinding, setIconRamp = React.createBinding(spec.iconRamp)
		local clickableBinding, setClickable = React.createBinding(spec.clickableWhenViewportHidden)
		local activeBinding, setActive = React.createBinding(false)
		buttonStates[hybridId] = {
			iconRamp = iconRampBinding,
			clickableWhenViewportHidden = clickableBinding,
			active = activeBinding,
		}
		buttonUpdaters[hybridId] = {
			iconRamp = setIconRamp,
			clickableWhenViewportHidden = setClickable,
			active = setActive,
		}
		table.insert(buttonScope, function()
			buttonStates[hybridId] = nil
			buttonUpdaters[hybridId] = nil
		end)
		if currentOwnedToolbar ~= nil then
			createOwnedButtonSoon(stableId, buttonId, spec)
		end
	end

	local function forgetButton(stableId: string, buttonId: string): ()
		local hybridId = `{stableId}/{buttonId}`
		local buttonScope = buttonScopes[hybridId]
		assert(buttonScope ~= nil, `No existing button {hybridId} to forget`)
		buttonScopes[hybridId] = nil
		DoCleanup(buttonScope)
	end

	table.insert(scope, function()
		for _, buttonScope in buttonScopes do
			DoCleanup(buttonScope)
		end
		table.clear(buttonScopes)
	end)

	protocolApi = interposer.connectProtocol(scope, PROTOCOL, {
		stableId = thisStableId,
		buttonSpecs = ourSharedButtons,
	} :: Types.ProtocolStaticInfo, {
		events = {
			onSharedClick = function(fromPeer: Interposer.Peer, args: { buttonId: string }): ()
				if ourSharedButtons[args.buttonId] == nil then
					return
				end
				doClick(args.buttonId)
			end,
			setActive = function(fromPeer: Interposer.Peer, args: { buttonId: string, isActive: boolean }): ()
				local stableId = stableIdFromPeer(fromPeer)
				if stableId ~= nil then
					setButtonActive(stableId, args.buttonId, args.isActive, { broadcastChange = false })
				end
			end,
			setClickableWhenViewportHidden = function(
				fromPeer: Interposer.Peer,
				args: { buttonId: string, clickableWhenViewportHidden: boolean }
			): ()
				local stableId = stableIdFromPeer(fromPeer)
				if stableId ~= nil then
					setButtonClickableWhenViewportHidden(
						stableId,
						args.buttonId,
						args.clickableWhenViewportHidden,
						{ broadcastChange = false }
					)
				end
			end,
			setIconRamp = function(
				fromPeer: Interposer.Peer,
				args: { buttonId: string, iconRamp: IconRamp.IconRamp }
			): ()
				local stableId = stableIdFromPeer(fromPeer)
				if stableId ~= nil then
					setButtonIconRamp(stableId, args.buttonId, args.iconRamp, { broadcastChange = false })
				end
			end,
		},
		requests = {},
	})

	table.insert(scope, {
		protocolApi.onJoinedProtocol(function(joiningPeer: Interposer.Peer, staticInfo: Types.ProtocolStaticInfo): ()
			for buttonId, spec in staticInfo.buttonSpecs do
				discoverButton(staticInfo.stableId, buttonId, spec)
			end
		end),
		protocolApi.onLeavingProtocol(function(leavingPeer: Interposer.Peer, staticInfo: Types.ProtocolStaticInfo): ()
			for buttonId, spec in staticInfo.buttonSpecs do
				forgetButton(staticInfo.stableId, buttonId)
			end
		end),
	})

	for buttonId, spec in ourPrivateButtons do
		discoverButton(thisStableId, buttonId, spec)
	end
	for buttonId, spec in ourSharedButtons do
		discoverButton(thisStableId, buttonId, spec)
	end
	for peer, staticInfo in protocolApi.staticInfoMap do
		if peer ~= interposer.selfPeer then
			for buttonId, spec in staticInfo.info.buttonSpecs do
				discoverButton(staticInfo.info.stableId, buttonId, spec)
			end
		end
	end

	table.insert(
		scope,
		FinallyTask(task.spawn, function(taskScope)
			task.wait(1) -- give other plugins an opportunity to load
			while true do
				local selfIsLeader = leader.selfIsLeader()
				if selfIsLeader == true then
					createOwnedToolbar()
					break
				else
					local push, pull = PushPull.yield()
					leader.onLeaderChanged(push)
					pull()
				end
			end
		end)
	)

	local sharedToolbarApi = {}
	sharedToolbarApi.onClick = onClick

	function sharedToolbarApi.setActive(buttonId: string, isActive: boolean): ()
		setButtonActive(thisStableId, buttonId, isActive, { broadcastChange = true })
	end

	function sharedToolbarApi.setClickableWhenViewportHidden(buttonId: string, clickableWhenViewportHidden: boolean): ()
		setButtonClickableWhenViewportHidden(
			thisStableId,
			buttonId,
			clickableWhenViewportHidden,
			{ broadcastChange = true }
		)
	end

	function sharedToolbarApi.setIconRamp(buttonId: string, iconRamp: IconRamp.IconRamp): ()
		setButtonIconRamp(thisStableId, buttonId, iconRamp, { broadcastChange = true })
	end

	function sharedToolbarApi.trySendButtonClick(peer: Interposer.Peer, buttonId: string): ()
		local stableId = stableIdFromPeer(peer)
		if stableId ~= nil then
			sendButtonClick(stableId, buttonId)
		end
	end

	return sharedToolbarApi
end

return SharedToolbar
