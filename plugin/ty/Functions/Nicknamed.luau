--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Types = require(Package.Types)
local Def = require(Package.Def)

local Nicknamed: Types.FnNicknamed = function<T>(innerDef, newName)
	return Def.new(newName, innerDef.Matches, innerDef.Cast)
end

return Nicknamed
