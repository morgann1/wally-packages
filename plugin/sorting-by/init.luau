--!strict
-- (c) Daniel P H Fox, licensed under MIT

--[=[
	@class sortingBy

	Builds `table.sort` comparators from a key-extraction function, so
	multi-level sorts read declaratively instead of as nested ifs.
]=]

--[=[
	@within sortingBy
	@function sortingBy

	Returns a comparator that orders two values by comparing their extracted
	keys pairwise: the first unequal key decides. Every call of `extract`
	must return the same number of keys, and mixing types at the same
	position will error inside `table.sort`.

	```lua
	table.sort(items, sortingBy(function(item)
		return { item.category, item.price }
	end))
	```

	@param extract (T) -> { number | string } -- Maps a value to its sort keys, most significant first.
	@return (T, T) -> boolean -- Comparator for `table.sort`.
]=]
local function sortingBy<T>(extract: (T) -> { number | string }): (T, T) -> boolean
	return function(a, b)
		local extractA = extract(a)
		local extractB = extract(b)
		assert(#extractA == #extractB, "sortingBy expects the same number of values to be provided at all times")
		local comparison = false
		for index, valueA in extractA do
			local valueB = extractB[index]
			comparison = valueA < valueB
			if valueA ~= valueB then
				break
			end
		end
		return comparison
	end
end

return sortingBy
