--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Types = require(Package.Types)
local Def = require(Package.Def)

--[=[
	@within ty
	@function Nicknamed

	Renames a def's `ExpectsType` so error messages read as your domain
	name instead of the expanded structural type.

	@param innerDef Def
	@param newName string
	@return Def
]=]
local Nicknamed: Types.FnNicknamed = function<T>(innerDef, newName)
	return Def.new(newName, innerDef.Matches, innerDef.Cast)
end

return Nicknamed
