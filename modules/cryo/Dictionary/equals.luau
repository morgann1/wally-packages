--!strict
local equalObjects = require(script.Parent.Parent.equalObjects)

local function compare<K, V>(a: { [K]: V }, b: { [K]: V }): boolean
	for key, value in a do
		if b[key] ~= value then
			return false
		end
	end

	for key, value in b do
		if a[key] ~= value then
			return false
		end
	end

	return true
end

local function equals<K, V>(...: { [K]: V }): boolean
	if equalObjects(...) then
		return true
	end

	local argCount = select("#", ...)
	local firstObject = select(1, ...)

	for i = 2, argCount do
		local object = select(i, ...)

		if not compare(firstObject, object) then
			return false
		end
	end

	return true
end

return equals
