--!strict
--[=[
	Returns the index of the first value found or nil if not found.
]=]
local function find<T>(list: { T }, value: T): number?
	for i = 1, #list do
		if list[i] == value then
			return i
		end
	end
	return nil
end

return find
