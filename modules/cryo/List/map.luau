--!strict
--[=[
	@within List
	@function map

	Create a copy of a list where each value is transformed by `callback`.
]=]
local function map<T, U>(list: { T }, callback: (T, number) -> U): { U }
	local new = {}

	for i = 1, #list do
		new[i] = callback(list[i], i)
	end

	return new
end

return map
