--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Types = require(Package.Types)

--[=[
	@within ty
	@function Retype

	Returns the def unchanged; exists purely so call sites can reassert the
	def's static Luau type. No runtime effect, like `Untyped`.

	@param def Def
	@return Def
]=]
local Retype: Types.FnRetype = function(def)
	return def
end

return Retype
