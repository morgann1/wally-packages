--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

local IgnoreInvalid: Types.FnIgnoreInvalid = function<T>(innerDef: Types.Def)
	return Def.new(`@ignoreInvalid({innerDef.ExpectsType})`, function(self, x)
		return true
	end, function(self, x)
		local result = innerDef:Cast(x)
		return if result.some then result else Maybe.some(nil)
	end)
end

return IgnoreInvalid
