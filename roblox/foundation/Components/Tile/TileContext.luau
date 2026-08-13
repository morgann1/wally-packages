local Foundation = script:FindFirstAncestor("foundation")
local Packages = Foundation.Parent

local React = require(Packages.React)

return React.createContext({
	fillDirection = Enum.FillDirection.Vertical,
	isContained = false,
	testId = "",
})
