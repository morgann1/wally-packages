--!strict
--[=[
	@within List
	@function foldLeft

	Performs a left-fold of the list with the given initial value and callback.
]=]
local function foldLeft<T, A>(list: { T }, callback: (A, T, number) -> A, initialValue: A): A
	local accum = initialValue

	for i = 1, #list do
		accum = callback(accum, list[i], i)
	end

	return accum
end

return foldLeft
