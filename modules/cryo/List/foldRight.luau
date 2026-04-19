--!strict
--[=[
	Performs a right-fold of the list with the given initial value and callback.
]=]
local function foldRight<T, A>(list: { T }, callback: (A, T, number) -> A, initialValue: A): A
	local accum = initialValue

	for i = #list, 1, -1 do
		accum = callback(accum, list[i], i)
	end

	return accum
end

return foldRight
