--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

local IntoDefault: Types.FnIntoDefault = function(innerDef, defaultValue)
	return Def.new(`\@default<{defaultValue}>({innerDef.ExpectsType})`, function(self, x)
		return x == nil or innerDef:Matches(x)
	end, function(self, x)
		if x == nil then
			return Maybe.some(defaultValue)
		else
			return innerDef:Cast(x)
		end
	end)
end

return IntoDefault
