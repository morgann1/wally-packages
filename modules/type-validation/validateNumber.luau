--!strict
local function validateNumber(value: unknown): boolean
	if typeof(value) ~= "number" then
		return false
	end

	-- NaN check
	if value ~= value then
		return false
	end

	return true
end

return validateNumber
