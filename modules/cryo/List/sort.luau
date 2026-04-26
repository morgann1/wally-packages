--!strict
--[=[
	@within List
	@function sort

	Returns a new list, ordered with the given sort callback.
	If no callback is given, the default table.sort will be used.
]=]
local function sort<T>(list: { T }, callback: ((T, T) -> boolean)?): { T }
	local new = table.clone(list)
	table.sort(new, callback)
	return new
end

return sort
