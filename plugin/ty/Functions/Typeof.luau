--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

--[=[
	@within ty
	@function Typeof

	Matches values whose `typeof()` equals the given string. Works for
	Roblox datatypes too: `ty.Typeof("Vector2")`, `ty.Typeof("Instance")`.

	@param typeString string
	@return Def
]=]
local Typeof: Types.FnTypeof = function(typeString)
	return Def.new(typeString, function(self, x)
		return typeof(x) == typeString
	end, function(self, x)
		if typeof(x) == typeString then
			return Maybe.some(x)
		else
			return Maybe.none(`{self.NotOfTypeError}\n...because {tostring(x)} doesn't have typeof() == {typeString}`)
		end
	end)
end

return Typeof
