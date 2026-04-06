local Foundation = script:FindFirstAncestor("foundation")
local Packages = Foundation.Parent

local React = require(Packages.React)

local InputSize = require(Foundation.Enums.InputSize)

type InputSize = InputSize.InputSize

return React.createContext({
	hasDivider = false,
	isInset = false,
	size = InputSize.Medium :: InputSize,
	testId = "",
})
