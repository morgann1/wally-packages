--!strict
--[=[
	@within TypeValidation

	Validates a `Vector3` with no NaN components (a Vector3 compares
	unequal to itself when any component is NaN).

	@param value unknown
	@return boolean
]=]
local function validateVector3(value: unknown): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end

	-- NaN check (Vector3 == itself is false when any component is NaN)
	if value ~= value then
		return false
	end

	return true
end

return validateVector3
