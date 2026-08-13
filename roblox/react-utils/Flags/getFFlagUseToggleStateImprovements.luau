local ReactUtils = script:FindFirstAncestor("react-utils")

local SafeFlags = require(ReactUtils.Parent.SafeFlags)

return SafeFlags.createGetFFlag("UseToggleStateImprovements")
