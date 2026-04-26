--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Types = require(Package.Types)

local CastOrError: Types.FnCastOrError = function(def, x)
	local result = def:Cast(x)
	if result.some then
		return result.value
	else
		error(`Could not cast {typeof(x)}: {result.reason}`)
	end
end

return CastOrError