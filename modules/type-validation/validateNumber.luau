--!strict
--[=[
	@within TypeValidation

	Validates a number that is not NaN. Note infinity passes; add a range
	check at the call site when bounds matter.

	@param value unknown
	@return boolean
]=]
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
