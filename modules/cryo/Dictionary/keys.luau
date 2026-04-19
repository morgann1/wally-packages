--!strict
--[=[
	Returns a list of the keys from the given dictionary.
]=]
local function keys<K, V>(dictionary: { [K]: V }): { K }
	local new = {}
	local index = 1

	for key in dictionary do
		new[index] = key
		index = index + 1
	end

	return new
end

return keys
