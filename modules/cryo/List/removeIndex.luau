--!strict
--[=[
	@within List
	@function removeIndex

	Remove the element at the given index.
]=]
local function removeIndex<T>(list: { T }, index: number): { T }
	local new = {}
	local removed = 0

	for i = 1, #list do
		if i == index then
			removed = 1
		else
			new[i - removed] = list[i]
		end
	end

	return new
end

return removeIndex
