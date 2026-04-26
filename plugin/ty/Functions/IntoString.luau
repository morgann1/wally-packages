--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

local IntoString: Types.FnIntoString = function(innerDef)
	return Def.new(`@tostring({innerDef.ExpectsType})`, function(self, x)
		local Cast = innerDef:Cast(x)
		return Cast.some and tostring(Cast.value) ~= nil
	end, function(self, x)
		local result = innerDef:Cast(x)
		if not result.some then
			return Maybe.none(`{self.NotOfTypeError}\n...because of the inner type: {result.reason}`)
		else
			local str = tostring(result.value)
			if str == nil then
				return Maybe.none(`{self.NotOfTypeError}\n...because it couldn't be turned into a string`)
			else
				return Maybe.some(str)
			end
		end
	end)
end

return IntoString
