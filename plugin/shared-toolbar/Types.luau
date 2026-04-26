--!strict
-- Originally (c) Studio Elttob 2024.

local Packages = script.Parent.Parent

local Event = require(Packages.Event)
local IconRamp = require(Packages.IconRamp)
local Interposer = require(Packages.Interposer)
local React = require(Packages.React)
local ty = require(Packages.ty)

local Types = {}

export type ButtonSpec = {
	toolTip: string,
	iconRamp: IconRamp.IconRamp,
	displayName: string,
	clickableWhenViewportHidden: boolean,
	creationOrder: number,
}
Types.ButtonSpec = ty.Struct({ exhaustive = false }, {
	toolTip = ty.String,
	iconRamp = IconRamp.Types.IconRamp,
	displayName = ty.String,
	clickableWhenViewportHidden = ty.Boolean,
	creationOrder = ty.Number,
})

export type ButtonState = {
	iconRamp: React.Binding<IconRamp.IconRamp>,
	clickableWhenViewportHidden: React.Binding<boolean>,
	active: React.Binding<boolean>,
}

export type SharedToolbarApi = {
	onClick: Event.Connect<string>,
	setActive: (buttonId: string, isActive: boolean) -> (),
	setClickableWhenViewportHidden: (buttonId: string, clickable: boolean) -> (),
	setIconRamp: (buttonId: string, iconRamp: IconRamp.IconRamp) -> (),
	trySendButtonClick: (peer: Interposer.Peer, buttonId: string) -> (),
}

export type ProtocolStaticInfo = {
	stableId: string,
	buttonSpecs: { [string]: ButtonSpec },
}
Types.ProtocolStaticInfo = ty.Struct({ exhaustive = false }, {
	stableId = ty.String,
	buttonSpecs = ty.String:MapOf(Types.ButtonSpec),
})

return Types
