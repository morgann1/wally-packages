--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

-- TODO: ensure arrays have no holes, and empty arrays are allowed
local Array: Types.FnArray = function<V>(values: Types.Def)
	return Def.new(`\{{values.ExpectsType}}`, function(self, x)
		if typeof(x) ~= "table" then
			return false
		end
		local x = x :: { [unknown]: unknown }
		local expected = #x
		local encountered = 0
		for key, value in x do
			encountered += 1
			if encountered > expected or typeof(key) ~= "number" or not values:Matches(value) then
				return false
			end
		end
		return true
	end, function(self, x)
		if typeof(x) ~= "table" then
			return Maybe.none(`{self.NotOfTypeError}\n...because {tostring(x)} isn't an array`)
		end
		local x = x :: { [unknown]: unknown }
		local modifiedReturn = {}
		local expected = #x
		local encountered = 0
		for key, value in x do
			encountered += 1
			if encountered > expected or typeof(key) ~= "number" then
				return Maybe.none(`{self.NotOfTypeError}\n...because {tostring(key)} isn't a valid array index`)
			end
			local castedValue = values:Cast(value)
			if not castedValue.some then
				return Maybe.none(`{self.NotOfTypeError}\n...because, at key {tostring(key)}: {castedValue.reason}`)
			end
			table.insert(modifiedReturn, castedValue.value :: any)
		end
		return Maybe.some(modifiedReturn)
	end)
end

return Array
