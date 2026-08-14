--!strict
-- Originally (c) Studio Elttob 2024.

local Types = require(script.Types)

--[=[
	@class IconRamp

	Picks the right raster icon for a display size from a "ramp": an array
	of the same icon exported at multiple sizes, each with per-theme
	variants.
]=]

--[=[
	@within IconRamp
	@type IconVariant "light" | "dark" | "mono"

	Theme variant an icon asset is drawn for.
]=]
export type IconVariant = Types.IconVariant

--[=[
	@within IconRamp
	@type Icon { size: number, variants: { [IconVariant]: string } }

	One exported size of an icon; `variants` maps each theme to its asset id.
]=]
export type Icon = Types.Icon

--[=[
	@within IconRamp
	@type IconRamp { Icon }

	All exported sizes of one icon.
]=]
export type IconRamp = Types.IconRamp

local IconRamp = {}

--[=[
	@within IconRamp
	@prop Types { IconVariant: Def, Icon: Def, IconRamp: Def }

	`ty` runtime definitions matching the exported types, for validating
	ramps loaded from untrusted data. `IconRamp` drops invalid entries
	rather than rejecting the whole array.
]=]
IconRamp.Types = Types

--[=[
	@within IconRamp

	Returns the smallest icon in the ramp that is at least `targetSize`
	pixels, so icons are only ever downscaled, never blurred upward. Falls
	back to the largest icon when the ramp has nothing big enough; returns
	`nil` only for an empty ramp. `ramp` itself is left unsorted.

	@param ramp IconRamp
	@param targetSize number -- Size the icon will be displayed at, in pixels.
	@return Icon?
]=]
function IconRamp.selectNearestSize(ramp: Types.IconRamp, targetSize: number): Types.Icon?
	local sortedRamp = table.clone(ramp)
	table.sort(sortedRamp, function(a, b)
		return a.size < b.size
	end)
	for _, info in sortedRamp do
		if info.size >= targetSize then
			return info
		end
	end
	return sortedRamp[#sortedRamp]
end

return IconRamp
