--!strict
--[=[
	Returns a list of the values of the given dictionary.
]=]
local function values<K, V>(dictionary: { [K]: V }): { V }
	local new = {}
	local index = 1

	for _, value in dictionary do
		new[index] = value
		index = index + 1
	end

	return new
end

return values
