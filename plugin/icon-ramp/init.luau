--!strict
-- Originally (c) Studio Elttob 2024.

local Types = require(script.Types)

export type IconVariant = Types.IconVariant
export type Icon = Types.Icon
export type IconRamp = Types.IconRamp

local IconRamp = {}
IconRamp.Types = Types

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
