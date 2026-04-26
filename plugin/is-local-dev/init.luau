--!strict
-- Originally (c) Studio Elttob 2024.

local function isLocalDev(devEnvName: string): boolean
	return debug.traceback():find(devEnvName, nil, true) ~= nil
end

return isLocalDev
