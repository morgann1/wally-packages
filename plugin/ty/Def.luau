--!strict
-- Originally (c) Daniel P H Fox.

local Types = require(script.Parent.Types)
local Maybe = require(script.Parent.Parent.Maybe)

local Def = {}

Def.methodMeta = { __index = nil :: Types.Methods? }

local function linkMethods(def): Types.Def
	setmetatable(def, Def.methodMeta)
	return def :: any
end

function Def.new<CastTo>(
	expectsType: string,
	matches: (self: Types.Def, unknown) -> boolean,
	cast: (self: Types.Def, unknown) -> Maybe.Maybe<any>
): Types.Def
	local def = {}
	def.Matches = matches
	def.ExpectsType = expectsType
	def.NotOfTypeError = `Type is not {expectsType}`
	def.Cast = cast
	return linkMethods(def)
end

return Def
