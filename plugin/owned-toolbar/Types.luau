--!strict
-- Originally (c) Studio Elttob 2024.

local Package = script.Parent

local IconRamp = require(Package.Parent.IconRamp)

local Types = {}

export type ToolbarButton = {
	instance: PluginToolbarButton,
	iconRamp: IconRamp.IconRamp,
	active: boolean,
	clickableWhenViewportHidden: boolean,
}

export type ToolbarButtonProps = {
	id: string,
	iconRamp: IconRamp.IconRamp,
	displayNameFirstTimeOnly: string,
	toolTipFirstTimeOnly: string,
	active: boolean?,
	clickableWhenViewportHidden: boolean?,
	onClick: (() -> ())?,
}

export type OwnedToolbarApi = {
	buttons: { [string]: ToolbarButton },
	initOrReuseButton: (
		id: string,
		iconRamp: IconRamp.IconRamp,
		displayNameFirstTimeOnly: string,
		toolTipFirstTimeOnly: string,
		active: boolean,
		clickableWhenViewportHidden: boolean
	) -> (ToolbarButton, boolean),
	destroy: (self: OwnedToolbarApi) -> (),
}

return Types
