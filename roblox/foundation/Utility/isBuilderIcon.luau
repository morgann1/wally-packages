local Foundation = script:FindFirstAncestor("foundation")
local Packages = Foundation.Parent

local Dash = require(Packages.Dash)

local function isBuilderIcon(icon: string?)
	return icon ~= nil and icon ~= "" and icon:find("[^%l%d%-]") == nil
end

return Dash.memoize(isBuilderIcon)
