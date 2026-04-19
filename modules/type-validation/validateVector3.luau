--!strict
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
