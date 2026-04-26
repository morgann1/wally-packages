--!strict
--!nolint LocalShadow
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Maybe = require(Package.Parent.Maybe)
local Types = require(Package.Types)
local Def = require(Package.Def)

local Struct: Types.FnStruct = function<K, V>(options, struct: { [K & string]: Types.Def })
	local expectTypeParts = {}
	for key, value in struct do
		table.insert(expectTypeParts, `{key}: {value.ExpectsType}`)
	end
	return Def.new(`\{{table.concat(expectTypeParts, ", ")}}`, function(self, x)
		if typeof(x) ~= "table" then
			return false
		end
		local x = x :: { [unknown]: unknown }
		for key, value in x do
			if typeof(key) ~= "string" then
				return false
			end
			local key = key :: K & string
			local innerDef = struct[key]
			if innerDef == nil or not innerDef:Matches(value) then
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
		for key, innerDef in struct do
			local value = x[key]
			local castedValue = (innerDef :: any):Cast(value)
			if not castedValue.some then
				return Maybe.none(
					`{self.NotOfTypeError}\n...because of the value at key {tostring(key)}: {castedValue.reason}`
				)
			end
			modifiedReturn[key] = castedValue.value :: any
		end
		for key in x do
			if typeof(key) ~= "string" then
				return Maybe.none(`{self.NotOfTypeError}\n...because {tostring(key)} isn't a valid struct key`)
			elseif options.exhaustive and struct[key :: any] == nil then
				return Maybe.none(
					`{self.NotOfTypeError}\n...because the struct is exhaustive and {tostring(key)} isn't included`
				)
			end
		end
		return Maybe.some(modifiedReturn)
	end)
end

return Struct
