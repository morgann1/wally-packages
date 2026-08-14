--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

--[=[
	@within ty
	@function IgnoreInvalid

	Makes a def infallible: values that fit the inner def cast normally,
	anything else casts to `nil` instead of failing. Inside `Array`, this
	drops invalid elements from the result.

	@param innerDef Def
	@return Def
]=]
local IgnoreInvalid: Types.FnIgnoreInvalid = function<T>(innerDef: Types.Def)
	return Def.new(`@ignoreInvalid({innerDef.ExpectsType})`, function(self, x)
		return true
	end, function(self, x)
		local result = innerDef:Cast(x)
		return if result.some then result else Maybe.some(nil)
	end)
end

return IgnoreInvalid
