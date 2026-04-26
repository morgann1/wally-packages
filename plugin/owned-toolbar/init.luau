--!strict
-- Originally (c) Studio Elttob 2024.

--[=[
	@class OwnedToolbar

	Wraps `plugin:CreateToolbar` with a registry that lets you create or
	reuse buttons by id and keeps each button's icon in sync with the
	current Studio theme. Plain values in, no Fusion state objects.

	Pair with [useToolbarButton] from React if you want declarative
	button lifecycle inside a component tree.
]=]

local React = require(script.Parent.React)

local IconRamp = require(script.Parent.IconRamp)
local IsLocalDev = require(script.Parent.IsLocalDev)

local Types = require(script.Types)

export type ToolbarButton = Types.ToolbarButton
export type ToolbarButtonProps = Types.ToolbarButtonProps
export type OwnedToolbarApi = Types.OwnedToolbarApi

local TARGET_ICON_SIZE = 64 -- 32x32 at 200% scaling

local function calcRibbonIconVariant(): IconRamp.IconVariant
	local ribbonBg = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
	local isDark = ribbonBg.R + ribbonBg.G + ribbonBg.B < 1.5
	return if isDark then "dark" else "light"
end

local function pickIconAssetId(ramp: IconRamp.IconRamp, variant: IconRamp.IconVariant, id: string): string
	local icon = IconRamp.selectNearestSize(ramp, TARGET_ICON_SIZE)
	assert(icon ~= nil, `No matching icon for toolbar button {id}`)
	local assetId = icon.variants[variant]
	assert(assetId ~= nil, `No matching variant for toolbar button {id}`)
	return assetId
end

local OwnedToolbar = {}

OwnedToolbar.Types = Types

--[=[
	@within OwnedToolbar
	@function create

	Creates a new plugin toolbar and returns an [OwnedToolbarApi] for
	registering buttons. Pass the plugin instance and the dev-env name
	used by [IsLocalDev] (a "Dev" marker button is added when matching).

	@param plugin Plugin
	@param devEnvName string
	@param toolbarTitle string
	@return OwnedToolbarApi
]=]
function OwnedToolbar.create(plugin: Plugin, devEnvName: string, toolbarTitle: string): Types.OwnedToolbarApi
	local toolbar = plugin:CreateToolbar(toolbarTitle)
	local buttons: { [string]: Types.ToolbarButton } = {}
	local connections: { RBXScriptConnection } = {}
	local destroyed = false
	local ribbonIconVariant: IconRamp.IconVariant = calcRibbonIconVariant()

	if IsLocalDev(devEnvName) then
		toolbar:CreateButton(
			"Dev",
			"This toolbar originated from a plugin running in the local development environment",
			"",
			" "
		)
	end

	table.insert(
		connections,
		settings().Studio.ThemeChanged:Connect(function()
			if destroyed then
				return
			end
			ribbonIconVariant = calcRibbonIconVariant()
			for id, button in buttons do
				button.instance.Icon = pickIconAssetId(button.iconRamp, ribbonIconVariant, id)
			end
		end)
	)

	local api = {} :: Types.OwnedToolbarApi
	api.buttons = buttons

	function api.initOrReuseButton(
		id: string,
		iconRamp: IconRamp.IconRamp,
		displayNameFirstTimeOnly: string,
		toolTipFirstTimeOnly: string,
		active: boolean,
		clickableWhenViewportHidden: boolean
	): (Types.ToolbarButton, boolean)
		assert(not destroyed, "Cannot initOrReuseButton after destroy")
		local existing = buttons[id]
		if existing ~= nil then
			existing.iconRamp = iconRamp
			existing.active = active
			existing.clickableWhenViewportHidden = clickableWhenViewportHidden
			existing.instance.Icon = pickIconAssetId(iconRamp, ribbonIconVariant, id)
			existing.instance.ClickableWhenViewportHidden = clickableWhenViewportHidden
			existing.instance:SetActive(active)
			return existing, false
		end

		local instance = toolbar:CreateButton(
			id,
			toolTipFirstTimeOnly,
			pickIconAssetId(iconRamp, ribbonIconVariant, id),
			displayNameFirstTimeOnly
		)
		instance.ClickableWhenViewportHidden = clickableWhenViewportHidden
		instance:SetActive(active)

		local button: Types.ToolbarButton = {
			instance = instance,
			iconRamp = iconRamp,
			active = active,
			clickableWhenViewportHidden = clickableWhenViewportHidden,
		}
		buttons[id] = button
		return button, true
	end

	function api:destroy()
		if destroyed then
			return
		end
		destroyed = true
		for _, conn in connections do
			conn:Disconnect()
		end
		table.clear(connections)
		for _, button in buttons do
			button.instance:Destroy()
		end
		table.clear(buttons)
		toolbar:Destroy()
	end

	return api
end

--[=[
	@within OwnedToolbar
	@function useToolbarButton

	React hook that ensures `toolbar` has a button matching `props` for
	the lifetime of the calling component. Reuses an existing button by
	id, applies `active` / `clickableWhenViewportHidden` updates, and
	wires `props.onClick` through the button's `Click` signal.

	Returns the live `PluginToolbarButton` instance, or `nil` until the
	first effect commit.

	@param toolbar OwnedToolbarApi
	@param props ToolbarButtonProps
	@return PluginToolbarButton?
]=]
function OwnedToolbar.useToolbarButton(
	toolbar: Types.OwnedToolbarApi,
	props: Types.ToolbarButtonProps
): PluginToolbarButton?
	local instance, setInstance = React.useState(nil :: PluginToolbarButton?)

	local active = props.active ~= false
	local clickable = props.clickableWhenViewportHidden == true

	React.useEffect(
		function(): (() -> ())?
			local button = toolbar.initOrReuseButton(
				props.id,
				props.iconRamp,
				props.displayNameFirstTimeOnly,
				props.toolTipFirstTimeOnly,
				active,
				clickable
			)
			setInstance(button.instance)
			return nil
		end,
		{
			toolbar,
			props.id,
			props.iconRamp,
			props.displayNameFirstTimeOnly,
			props.toolTipFirstTimeOnly,
			active,
			clickable,
		} :: { any }
	)

	React.useEffect(function(): (() -> ())?
		local onClick = props.onClick
		if (instance :: any) == nil or onClick == nil then
			return nil
		end
		local conn = (instance :: PluginToolbarButton).Click:Connect(onClick)
		return function()
			conn:Disconnect()
		end
	end, { instance, props.onClick } :: { any })

	return instance
end

return OwnedToolbar
