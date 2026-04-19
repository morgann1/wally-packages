--!strict
local function isEmpty(object: { [unknown]: unknown }): boolean
	return next(object) == nil
end

return isEmpty
