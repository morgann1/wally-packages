local Foundation = script:FindFirstAncestor("foundation")
local Packages = Foundation.Parent

local BuilderIcons = require(Packages.BuilderIcons)

local getBuilderIconForCurrentPlatform = BuilderIcons.getBuilderIconForCurrentPlatform

return getBuilderIconForCurrentPlatform
