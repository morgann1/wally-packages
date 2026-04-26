--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

local Predicate: Types.FnPredicate = function(predicate)
	return Def.new(`@predicate`, function(self, x)
		return predicate(x)
	end, function(self, x)
		if predicate(x) then
			return Maybe.some(x)
		else
			return Maybe.none(`Type did not satisfy predicate`)
		end
	end)
end

return Predicate
