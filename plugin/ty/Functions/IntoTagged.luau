--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

local IntoTagged: Types.FnIntoTagged = function(innerDef, tag)
	return Def.new(`\@tagged<{tag}>({innerDef.ExpectsType})`, function(self, x)
		return innerDef:Matches(x)
	end, function(self, x)
		local result = innerDef:Cast(x)
		if not result.some then
			return Maybe.none(`{self.NotOfTypeError}\n...because of the inner type: {result.reason}`)
		else
			local value = if typeof(result.value) == "table"
				then table.clone(result.value :: any) :: any
				else { value = result.value }
			value.__tag = tag
			return Maybe.some(value)
		end
	end)
end

return IntoTagged
