--!strict
-- Originally (c) Studio Elttob 2024.

-- Limits to bound the runtime of these calls in case of bad data, because
-- these functions are involved in sanitising and verifying data received
-- from outside of this package.
local MAX_TABLE_SIZE = 250
local MAX_TABLE_DEPTH = 20

local function isNetworkSafeImpl(x: unknown, seen: { [{ [unknown]: unknown }]: true }, depth: number): boolean
	if depth > MAX_TABLE_DEPTH then
		return false
	end
	local ty = typeof(x)
	if ty == "number" or ty == "boolean" or ty == "string" or ty == "nil" then
		return true
	elseif ty == "table" then
		local x = x :: { [unknown]: unknown }
		if seen[x] or getmetatable(x :: any) ~= nil then
			return false
		end
		local arraySize, mapSize = #x, 0
		if arraySize > MAX_TABLE_SIZE then
			return false
		end
		for key, value in x do
			mapSize += 1
			if
				mapSize > MAX_TABLE_SIZE
				or not isNetworkSafeImpl(key, seen, depth + 1)
				or not isNetworkSafeImpl(value, seen, depth + 1)
			then
				return false
			end
		end
		if arraySize > 0 and arraySize ~= mapSize then
			return false
		end
		return true
	else
		return false
	end
end

local function isNetworkSafe(x: unknown): boolean
	return isNetworkSafeImpl(x, {}, 0)
end

return isNetworkSafe
