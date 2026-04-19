--!strict
--[=[
	Returns the index of the first value for which predicate(value, index) is truthy, or nil if not found.
]=]
local function findWhere<T>(list: { T }, predicate: (T, number) -> boolean): number?
	for i = 1, #list do
		if predicate(list[i], i) then
			return i
		end
	end
	return nil
end

return findWhere
