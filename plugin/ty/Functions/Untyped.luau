--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Types = require(Package.Types)

--[=[
	@within ty
	@function Untyped

	Returns the def unchanged; exists purely to erase the def's static Luau
	type at call sites. No runtime effect, like `Retype`.

	@param def Def
	@return Def
]=]
local Untyped: Types.FnUntyped = function(def)
	return def
end

return Untyped
