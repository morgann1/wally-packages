--!strict
--[=[
	@class TypeValidation

	Runtime type validators for common Roblox value types. Each validator
	returns `true` when its input matches the expected shape and `false`
	otherwise, making it suitable for assertion-style precondition checks.

	Exposed validators:

	- `validateCFrame`
	- `validateInstance`
	- `validateNumber`
	- `validateSimpleTable`
	- `validateVector3`
]=]

local validateCFrame = require(script.validateCFrame)
local validateInstance = require(script.validateInstance)
local validateNumber = require(script.validateNumber)
local validateSimpleTable = require(script.validateSimpleTable)
local validateVector3 = require(script.validateVector3)

return table.freeze({
	validateCFrame = validateCFrame,
	validateInstance = validateInstance,
	validateNumber = validateNumber,
	validateSimpleTable = validateSimpleTable,
	validateVector3 = validateVector3,
})
