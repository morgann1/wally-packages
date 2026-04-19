--!strict
local validateVector3 = require(script.Parent.validateVector3)

local function validateCFrame(value: unknown): boolean
	if typeof(value) ~= "CFrame" then
		return false
	end

	if not validateVector3(value.Position) then
		return false
	end

	if not validateVector3(value.LookVector) then
		return false
	end

	return true
end

return validateCFrame
