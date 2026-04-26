--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

local Optional: Types.FnOptional = function<T>(innerDef: Types.Def)
	return Def.new(`({innerDef.ExpectsType})?`, function(self, x)
		if x == nil then
			return true
		end
		return innerDef:Matches(x)
	end, function(self, x)
		if x == nil then
			return Maybe.some(nil) :: Maybe.Maybe<T?>
		end
		local result = innerDef:Cast(x)
		return if result.some
			then result
			else Maybe.none(`{self.NotOfTypeError}\n...because of the inner type: {result.reason}`)
	end)
end

return Optional
