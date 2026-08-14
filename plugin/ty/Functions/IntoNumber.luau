--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

--[=[
	@within ty
	@function IntoNumber

	Casts through the inner def, then converts the result with `tonumber`.
	Fails when the conversion returns `nil`.

	@param innerDef Def
	@param base number? -- Numeric base for the conversion, as in `tonumber`.
	@return Def -- Casts to a number.
]=]
local IntoNumber: Types.FnIntoNumber = function(innerDef, base)
	return Def.new(`@tonumber({innerDef.ExpectsType}{if base == nil then "" else ", " .. base})`, function(self, x)
		local Cast = innerDef:Cast(x)
		return Cast.some and tonumber(Cast.value, base) ~= nil
	end, function(self, x)
		local result = innerDef:Cast(x)
		if not result.some then
			return Maybe.none(`{self.NotOfTypeError}\n...because of the inner type: {result.reason}`)
		else
			local num = tonumber(result.value, base)
			if num == nil then
				return Maybe.none(`Numeric conversion not possible for {self.ExpectsType}`)
			else
				return Maybe.some(num)
			end
		end
	end)
end

return IntoNumber
