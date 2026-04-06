local Foundation = script:FindFirstAncestor("foundation")
local Packages = Foundation.Parent

local FoundationCloudAssets = require(Packages.FoundationCloudAssets).Assets

return function(img: string)
	return FoundationCloudAssets[img] ~= nil
end
