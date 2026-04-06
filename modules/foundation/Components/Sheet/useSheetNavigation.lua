local Foundation = script:FindFirstAncestor("foundation")

local SheetContext = require(script.Parent.SheetContext)
local createUseModalNavigation = require(Foundation.Utility.createUseModalNavigation)

return createUseModalNavigation(SheetContext)
