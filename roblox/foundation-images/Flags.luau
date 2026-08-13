local Packages = script:FindFirstAncestor("foundation-images").Parent
local SafeFlags = require(Packages.SafeFlags)

return {
	FixBlurryImages = SafeFlags.createGetFFlag("FixBlurryImages")(),
	FoundationImagesRemoveDeprecatedIconAssets = SafeFlags.createGetFFlag("FoundationImagesRemoveDeprecatedIconAssets")(),
}
