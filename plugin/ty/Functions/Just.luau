--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

local Just: Types.FnJust = function(literal, type)
	return Def.new(type or tostring(literal), function(self, x)
		return rawequal(x, literal)
	end, function(self, x)
		if rawequal(x, literal) then
			return Maybe.some(x)
		else
			return Maybe.none(
				`{self.NotOfTypeError}\n...because only {tostring(literal)} is accepted, but received {tostring(x)}`
			)
		end
	end)
end

return Just
