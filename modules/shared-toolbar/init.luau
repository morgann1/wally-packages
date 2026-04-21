--!strict
local HttpService = game:GetService("HttpService")
local StudioService = game:GetService("StudioService")

local DEFAULT_PROTOCOL_VERSION = 2
-- Short quiet period after boot so we can hear from existing peers before
-- deciding whether to claim leadership. Prevents a new plugin from briefly
-- building its own toolbar next to an already-running one during reinstalls.
local BOOT_SETTLE_SECONDS = 1

export type ButtonSpec = {
	id: string,
	title: string,
	tooltip: string?,
	iconId: string?,
	clickableWhenViewportHidden: boolean?,
	onClick: () -> (),
}

export type RegisterOptions = {
	plugin: Plugin,
	mediumName: string,
	toolbarTitle: string,
	peerId: string,
	protocolVersion: number?,
	buttons: { ButtonSpec },
}

export type SharedToolbarHandle = {
	setActive: (self: SharedToolbarHandle, buttonId: string, isActive: boolean) -> (),
	setEnabled: (self: SharedToolbarHandle, buttonId: string, isEnabled: boolean) -> (),
	destroy: (self: SharedToolbarHandle) -> (),
}

type SerializableButton = {
	id: string,
	title: string,
	tooltip: string?,
	iconId: string?,
	clickableWhenViewportHidden: boolean?,
}

type PeerRecord = {
	sessionId: string,
	peerId: string,
	protocolVersion: number,
	toolbarTitle: string,
	buttons: { SerializableButton },
}

type Message = { [string]: any }

local function locateMedium(name: string): BindableEvent
	local existing = StudioService:FindFirstChild(name)
	if existing ~= nil then
		if existing:IsA("BindableEvent") then
			return existing
		end
		existing.Name = existing.Name .. "_OLD"
	end
	local medium = Instance.new("BindableEvent")
	medium.Name = name
	medium.Archivable = false
	medium.Parent = StudioService
	return medium
end

local function serializeButton(spec: ButtonSpec): SerializableButton
	return {
		id = spec.id,
		title = spec.title,
		tooltip = spec.tooltip,
		iconId = spec.iconId,
		clickableWhenViewportHidden = spec.clickableWhenViewportHidden,
	}
end

local SharedToolbar = {}

function SharedToolbar.register(options: RegisterOptions): SharedToolbarHandle
	local plugin = options.plugin
	local mediumName = options.mediumName
	local toolbarTitle = options.toolbarTitle
	local selfPeerId = options.peerId
	local protocolVersion = options.protocolVersion or DEFAULT_PROTOCOL_VERSION
	local sessionId = HttpService:GenerateGUID(false)

	local medium = locateMedium(mediumName)

	local ownSpecsById: { [string]: ButtonSpec } = {}
	local ownSerialButtons: { SerializableButton } = {}
	for _, spec in options.buttons do
		if ownSpecsById[spec.id] ~= nil then
			error(`duplicate button id: {spec.id}`)
		end
		ownSpecsById[spec.id] = spec
		table.insert(ownSerialButtons, serializeButton(spec))
	end

	local peers: { [string]: PeerRecord } = {}
	-- Sticky leader: once a peer is known to hold the toolbar, other peers
	-- defer to them regardless of sessionId ordering. This is what prevents
	-- the duplicate-toolbar symptom during local reinstalls — a new peer
	-- asks "who is leader?" and defers, rather than racing to claim it.
	local currentLeaderSessionId: string? = nil

	local currentToolbar: PluginToolbar? = nil
	local currentToolbarTitle: string? = nil
	local currentButtons: { [string]: PluginToolbarButton? } = {}
	local clickConns: { RBXScriptConnection } = {}

	local destroyed = false
	local bootSettled = false

	local fire: (Message) -> ()

	local function hybridId(peerSessionId: string, buttonId: string): string
		return `{peerSessionId}/{buttonId}`
	end

	-- The title is broadcast by every peer as a hint. The peer with the
	-- lowest peerId wins, so leadership reshuffles don't rename the toolbar
	-- and callers can have one plugin be authoritative for the name.
	local function resolveToolbarTitle(): string
		local winningPeerId = selfPeerId
		local winningTitle = toolbarTitle
		for _, peer in peers do
			if peer.peerId < winningPeerId then
				winningPeerId = peer.peerId
				winningTitle = peer.toolbarTitle
			end
		end
		return winningTitle
	end

	local function tearDownToolbar()
		for _, conn in clickConns do
			conn:Disconnect()
		end
		table.clear(clickConns)
		for _, button in currentButtons do
			if button ~= nil then
				button:Destroy()
			end
		end
		table.clear(currentButtons)
		if currentToolbar ~= nil then
			currentToolbar:Destroy()
			currentToolbar = nil
			currentToolbarTitle = nil
		end
	end

	local function dispatchClick(targetSessionId: string, buttonId: string)
		if targetSessionId == sessionId then
			local spec = ownSpecsById[buttonId]
			if spec ~= nil then
				task.spawn(spec.onClick)
			end
			return
		end
		fire({
			kind = "click",
			targetSessionId = targetSessionId,
			buttonId = buttonId,
		})
	end

	local function createButtonOnToolbar(peerSessionId: string, serialized: SerializableButton): PluginToolbarButton
		assert(currentToolbar ~= nil, "no toolbar to create button on")
		local id = hybridId(peerSessionId, serialized.id)
		local button =
			currentToolbar:CreateButton(id, serialized.tooltip or "", serialized.iconId or "", serialized.title)
		if serialized.clickableWhenViewportHidden ~= nil then
			button.ClickableWhenViewportHidden = serialized.clickableWhenViewportHidden
		end
		table.insert(
			clickConns,
			button.Click:Connect(function()
				dispatchClick(peerSessionId, serialized.id)
			end)
		)
		return button
	end

	local function buildToolbar()
		assert(currentToolbar == nil, "toolbar already built")
		local resolvedTitle = resolveToolbarTitle()
		currentToolbar = plugin:CreateToolbar(resolvedTitle)
		currentToolbarTitle = resolvedTitle

		for _, serialized in ownSerialButtons do
			currentButtons[hybridId(sessionId, serialized.id)] = createButtonOnToolbar(sessionId, serialized)
		end

		local sortedPeers: { PeerRecord } = {}
		for _, peer in peers do
			table.insert(sortedPeers, peer)
		end
		table.sort(sortedPeers, function(a, b)
			if a.peerId ~= b.peerId then
				return a.peerId < b.peerId
			end
			return a.sessionId < b.sessionId
		end)
		for _, peer in sortedPeers do
			for _, serialized in peer.buttons do
				currentButtons[hybridId(peer.sessionId, serialized.id)] =
					createButtonOnToolbar(peer.sessionId, serialized)
			end
		end
	end

	local function claimLeadership()
		currentLeaderSessionId = sessionId
		fire({ kind = "leaderClaim", sessionId = sessionId })
		if currentToolbar == nil then
			buildToolbar()
		elseif currentToolbarTitle ~= resolveToolbarTitle() then
			tearDownToolbar()
			buildToolbar()
		end
	end

	local function elect()
		if destroyed or not bootSettled then
			return
		end
		if currentLeaderSessionId ~= nil then
			-- Someone already leads. If it's us, make sure the toolbar is up.
			if currentLeaderSessionId == sessionId and currentToolbar == nil then
				buildToolbar()
			end
			return
		end
		-- No known leader. Lowest sessionId among self + peers wins. If every
		-- peer runs this deterministically, exactly one claims leadership.
		local lowestSessionId = sessionId
		for peerSessionId in peers do
			if peerSessionId < lowestSessionId then
				lowestSessionId = peerSessionId
			end
		end
		if lowestSessionId == sessionId then
			claimLeadership()
		end
	end

	local function upsertPeer(record: PeerRecord)
		if record.sessionId == sessionId then
			return
		end
		if record.protocolVersion ~= protocolVersion then
			warn(
				`[SharedToolbar] ignoring peer {record.peerId} with protocol `
					.. `v{record.protocolVersion} (we speak v{protocolVersion})`
			)
			return
		end
		local hadPeer = peers[record.sessionId] ~= nil
		peers[record.sessionId] = record
		if not hadPeer and currentLeaderSessionId == sessionId and currentToolbar ~= nil then
			-- We lead; mirror the new peer's buttons onto our toolbar.
			for _, serialized in record.buttons do
				currentButtons[hybridId(record.sessionId, serialized.id)] =
					createButtonOnToolbar(record.sessionId, serialized)
			end
			if currentToolbarTitle ~= resolveToolbarTitle() then
				tearDownToolbar()
				buildToolbar()
			end
		end
	end

	local function removePeer(peerSessionId: string)
		if peers[peerSessionId] == nil then
			return
		end
		peers[peerSessionId] = nil
		if currentLeaderSessionId == sessionId and currentToolbar ~= nil then
			local prefix = peerSessionId .. "/"
			local prefixLen = #prefix
			local toRemove: { string } = {}
			for id in currentButtons do
				if string.sub(id, 1, prefixLen) == prefix then
					table.insert(toRemove, id)
				end
			end
			for _, id in toRemove do
				local button = currentButtons[id]
				if button ~= nil then
					button:Destroy()
				end
				currentButtons[id] = nil
			end
			if currentToolbarTitle ~= resolveToolbarTitle() then
				tearDownToolbar()
				buildToolbar()
			end
		end
		if peerSessionId == currentLeaderSessionId then
			-- Leader left; run a fresh election.
			currentLeaderSessionId = nil
			elect()
		end
	end

	fire = function(msg)
		medium:Fire(msg)
	end

	local conn = medium.Event:Connect(function(msg)
		if typeof(msg) ~= "table" then
			return
		end
		local kind = msg.kind
		if kind == "hello" then
			if msg.sessionId == sessionId then
				return
			end
			upsertPeer({
				sessionId = msg.sessionId,
				peerId = msg.peerId,
				protocolVersion = msg.protocolVersion,
				toolbarTitle = msg.toolbarTitle,
				buttons = msg.buttons,
			})
			fire({
				kind = "welcome",
				toSessionId = msg.sessionId,
				sessionId = sessionId,
				peerId = selfPeerId,
				protocolVersion = protocolVersion,
				toolbarTitle = toolbarTitle,
				buttons = ownSerialButtons,
				leaderSessionId = currentLeaderSessionId,
			})
		elseif kind == "welcome" then
			if msg.toSessionId ~= sessionId then
				return
			end
			upsertPeer({
				sessionId = msg.sessionId,
				peerId = msg.peerId,
				protocolVersion = msg.protocolVersion,
				toolbarTitle = msg.toolbarTitle,
				buttons = msg.buttons,
			})
			-- Adopt the sender's view of who leads, if we don't already know.
			-- This is how a newly-booted peer discovers an existing toolbar
			-- owner without waiting for the next election cycle.
			if currentLeaderSessionId == nil and typeof(msg.leaderSessionId) == "string" then
				currentLeaderSessionId = msg.leaderSessionId
			end
		elseif kind == "leaderClaim" then
			if msg.sessionId == sessionId then
				return
			end
			local previousLeader = currentLeaderSessionId
			currentLeaderSessionId = msg.sessionId
			if previousLeader == sessionId and currentToolbar ~= nil then
				-- We thought we were leader; yield to the claimant.
				tearDownToolbar()
			end
		elseif kind == "goodbye" then
			if msg.sessionId == sessionId then
				return
			end
			removePeer(msg.sessionId)
		elseif kind == "click" then
			if msg.targetSessionId ~= sessionId then
				return
			end
			local spec = ownSpecsById[msg.buttonId]
			if spec ~= nil then
				task.spawn(spec.onClick)
			end
		elseif kind == "setActive" then
			local button = currentButtons[hybridId(msg.targetSessionId, msg.buttonId)]
			if button ~= nil then
				button:SetActive(msg.isActive)
			end
		elseif kind == "setEnabled" then
			local button = currentButtons[hybridId(msg.targetSessionId, msg.buttonId)]
			if button ~= nil then
				button.Enabled = msg.isEnabled
			end
		end
	end)

	fire({
		kind = "hello",
		sessionId = sessionId,
		peerId = selfPeerId,
		protocolVersion = protocolVersion,
		toolbarTitle = toolbarTitle,
		buttons = ownSerialButtons,
	})

	task.delay(BOOT_SETTLE_SECONDS, function()
		if destroyed then
			return
		end
		bootSettled = true
		elect()
	end)

	local function teardownEverything()
		if destroyed then
			return
		end
		destroyed = true
		fire({ kind = "goodbye", sessionId = sessionId })
		conn:Disconnect()
		tearDownToolbar()
	end

	plugin.Unloading:Connect(teardownEverything)

	local handle = {} :: SharedToolbarHandle

	function handle:setActive(buttonId, isActive)
		if ownSpecsById[buttonId] == nil then
			error(`not our button: {buttonId}`)
		end
		local button = currentButtons[hybridId(sessionId, buttonId)]
		if button ~= nil then
			button:SetActive(isActive)
		else
			fire({
				kind = "setActive",
				targetSessionId = sessionId,
				buttonId = buttonId,
				isActive = isActive,
			})
		end
	end

	function handle:setEnabled(buttonId, isEnabled)
		if ownSpecsById[buttonId] == nil then
			error(`not our button: {buttonId}`)
		end
		local button = currentButtons[hybridId(sessionId, buttonId)]
		if button ~= nil then
			button.Enabled = isEnabled
		else
			fire({
				kind = "setEnabled",
				targetSessionId = sessionId,
				buttonId = buttonId,
				isEnabled = isEnabled,
			})
		end
	end

	function handle:destroy()
		teardownEverything()
	end

	return handle
end

return SharedToolbar
