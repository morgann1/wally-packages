--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Types = require(Package.Types)

--[=[
	@within ty
	@function CastOrError

	Casts `x` through the def and returns the converted value directly,
	erroring with the cast's reason chain instead of returning a [Maybe].
	The assertion-style entry point at trust boundaries.

	@param def Def
	@param x unknown
	@return unknown -- The cast value.
	@error Could not cast -- When `x` does not fit the def.
]=]
local CastOrError: Types.FnCastOrError = function(def, x)
	local result = def:Cast(x)
	if result.some then
		return result.value
	else
		error(`Could not cast {typeof(x)}: {result.reason}`)
	end
end

return CastOrError
