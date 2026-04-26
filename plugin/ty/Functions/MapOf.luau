--!strict
--!nolint LocalShadow
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

local MapOf: Types.FnMapOf = function<K, V>(keys: Types.Def, values: Types.Def)
	return Def.new(`\{[{keys.ExpectsType}]: {values.ExpectsType}}`, function(self, x)
		if typeof(x) ~= "table" then
			return false
		end
		local x = x :: { [unknown]: unknown }
		for key, value in x do
			if not keys:Matches(key) or not values:Matches(value) then
				return false
			end
		end
		return true
	end, function(self, x)
		if typeof(x) ~= "table" then
			return Maybe.none(`{self.NotOfTypeError}\n...because {tostring(x)} isn't a table`)
		end
		local x = x :: { [unknown]: unknown }
		local modifiedReturn = {}
		for key, value in x do
			local castedKey = keys:Cast(key)
			if not castedKey.some then
				return Maybe.none(`{self.NotOfTypeError}\n...because of the key {tostring(key)}: {castedKey.reason}`)
			end
			local castedValue = values:Cast(value)
			if not castedValue.some then
				return Maybe.none(
					`{self.NotOfTypeError}\n...because of the value at key {tostring(key)}: {castedValue.reason}`
				)
			end
			modifiedReturn[castedKey.value :: any] = castedValue.value :: any
		end
		return Maybe.some(modifiedReturn)
	end)
end

return MapOf
