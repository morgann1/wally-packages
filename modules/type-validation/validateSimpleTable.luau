--!strict
--[=[
	@within TypeValidation

	Validates a homogeneous table: every key must have the given `typeof`
	and every value must pass the validator. Compose with the other
	validators, e.g. `validateSimpleTable(value, "number", validateVector3)`.

	@param value unknown
	@param keyType string -- Required `typeof` of every key, e.g. `"string"`.
	@param validator (unknown) -> boolean -- Validates each value.
	@return boolean
]=]
local function validateSimpleTable(value: unknown, keyType: string, validator: (unknown) -> boolean): boolean
	if typeof(value) ~= "table" then
		return false
	end

	for key, item in value :: { [unknown]: unknown } do
		if typeof(key) ~= keyType then
			return false
		end

		if not validator(item) then
			return false
		end
	end

	return true
end

return validateSimpleTable
