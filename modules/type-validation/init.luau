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
