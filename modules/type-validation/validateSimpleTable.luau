--!strict
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
