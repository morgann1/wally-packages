--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

--[=[
	@within ty
	@function IntoTagged

	Casts through the inner def, then stamps the result with a `__tag`
	field for discriminated unions. Table results are cloned before
	tagging; other values are wrapped as `{ value = result, __tag = tag }`.

	@param innerDef Def
	@param tag unknown -- Discriminant stored under `__tag`.
	@return Def
]=]
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
