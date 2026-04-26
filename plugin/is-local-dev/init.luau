--!strict
-- Originally (c) Studio Elttob 2024.

--[=[
	@class IsLocalDev

	Detects whether code is running inside a local development environment
	by inspecting the call stack for a known marker name (typically the
	folder/script name your local dev rig wraps things in).
]=]

--[=[
	@within IsLocalDev
	@function IsLocalDev

	Returns `true` when `devEnvName` appears anywhere in the current stack
	traceback. The check is a literal substring match, not a pattern.

	@param devEnvName string -- Identifier of the local dev environment to look for.
	@return boolean
]=]
local function isLocalDev(devEnvName: string): boolean
	return debug.traceback():find(devEnvName, nil, true) ~= nil
end

return isLocalDev
