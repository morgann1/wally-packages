--!strict
local RunService = game:GetService("RunService")
local __DEV__ = RunService:IsStudio()

type LogFn = (...any) -> ()

local Log: {
	debug: LogFn,
	info: LogFn,
	warn: LogFn,
} = {} :: any

local function createLogFunction(levelName: string, logFn: (...string) -> (), printInDev: boolean): LogFn
	return function(...)
		if printInDev and not __DEV__ then
			return
		end

		-- Take the final segment of the module path as the display name.
		local modulePath = debug.info(2, "s")
		local moduleName = modulePath:match("[^.]+$") or "unknown"

		logFn(`[{moduleName}] {levelName}:`, ...)
	end
end

Log.debug = createLogFunction("DEBUG", print, false)
Log.info = createLogFunction("INFO", print, true)
Log.warn = createLogFunction("WARN", warn, true)

return Log
