--!strict
-- Originally (c) Studio Elttob 2024.

local Packages = script.Parent.Parent
local ty = require(Packages.ty)

local Types = {}

export type IconVariant = "light" | "dark" | "mono"
Types.IconVariant = ty.Just("light"):Or(ty.Just("dark")):Or(ty.Just("mono")):Nicknamed("IconVariant")

export type Icon = {
	size: number,
	variants: {
		[IconVariant]: string,
	},
}
Types.Icon = ty.Struct({ exhaustive = true }, {
	size = ty.Number,
	variants = Types.IconVariant:MapOf(ty.String),
}):Nicknamed("Icon")

export type IconRamp = { Icon }
Types.IconRamp = Types.Icon:IgnoreInvalid():Array():Nicknamed("IconRamp")

return Types
