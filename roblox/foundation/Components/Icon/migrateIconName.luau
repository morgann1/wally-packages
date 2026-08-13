local Foundation = script:FindFirstAncestor("foundation")
local Packages = Foundation.Parent
local BuilderIcons = require(Packages.BuilderIcons)
type IconVariant = BuilderIcons.IconVariant
local migrationLookUp = BuilderIcons.Migration

local function migrateIconName(name: string): { name: string, variant: IconVariant? } | nil
	return migrationLookUp["uiblox"][name]
end

return migrateIconName
