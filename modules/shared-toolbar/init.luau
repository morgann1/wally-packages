--!strict
local HttpService = game:GetService("HttpService")
local StudioService = game:GetService("StudioService")

local DEFAULT_PROTOCOL_VERSION = 1
-- Short quiet period after boot so peers can exchange hellos before any peer
-- creates a toolbar. Prevents a flicker where we build, then tear down on
-- learning a lower-sessioned peer exists.
local BOOT_SETTLE_SECONDS = 0.5

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

	local peers: { [string]: PeerRecord? } = {}

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
			if peer == nil then
				continue
			end
			if peer.peerId < winningPeerId then
				winningPeerId = peer.peerId
				winningTitle = peer.toolbarTitle
			end
		end
		return winningTitle
	end

	local function isLeader(): boolean
		for otherSessionId in peers do
			if otherSessionId < sessionId then
				return false
			end
		end
		return true
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

	local function createButtonOnToolbar(
		peerSessionId: string,
		serialized: SerializableButton
	): PluginToolbarButton
		assert(currentToolbar ~= nil, "no toolbar to create button on")
		local id = hybridId(peerSessionId, serialized.id)
		local button = currentToolbar:CreateButton(
			id,
			serialized.tooltip or "",
			serialized.iconId or "",
			serialized.title
		)
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

		-- Deterministic ordering: own buttons first, then peers sorted by peerId.
		for _, serialized in ownSerialButtons do
			currentButtons[hybridId(sessionId, serialized.id)] =
				createButtonOnToolbar(sessionId, serialized)
		end

		local sortedPeers: { PeerRecord } = {}
		for _, peer in peers do
			if peer ~= nil then
				table.insert(sortedPeers, peer)
			end
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

	local function reconcileLeadership()
		if destroyed or not bootSettled then
			return
		end
		local shouldLead = isLeader()
		if shouldLead then
			if currentToolbar == nil then
				buildToolbar()
			elseif currentToolbarTitle ~= resolveToolbarTitle() then
				-- A peer with a lower peerId joined/left and changed the winning
				-- title; rebuild so the toolbar reflects the new name.
				tearDownToolbar()
				buildToolbar()
			end
		elseif currentToolbar ~= nil then
			tearDownToolbar()
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
		if not hadPeer and currentToolbar ~= nil then
			-- Live-add the new peer's buttons to an existing toolbar.
			for _, serialized in record.buttons do
				currentButtons[hybridId(record.sessionId, serialized.id)] =
					createButtonOnToolbar(record.sessionId, serialized)
			end
		end
		reconcileLeadership()
	end

	local function removePeer(peerSessionId: string)
		if peers[peerSessionId] == nil then
			return
		end
		peers[peerSessionId] = nil
		if currentToolbar ~= nil then
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
		end
		reconcileLeadership()
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
		reconcileLeadership()
	end)

	plugin.Unloading:Connect(function()
		if destroyed then
			return
		end
		destroyed = true
		fire({ kind = "goodbye", sessionId = sessionId })
		conn:Disconnect()
		tearDownToolbar()
	end)

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
		if destroyed then
			return
		end
		destroyed = true
		fire({ kind = "goodbye", sessionId = sessionId })
		conn:Disconnect()
		tearDownToolbar()
	end

	return handle
end

return SharedToolbar
