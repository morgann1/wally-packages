local Foundation = script:FindFirstAncestor("foundation")
local Packages = Foundation.Parent

local React = require(Packages.React)

return React.createContext(0 :: number)
