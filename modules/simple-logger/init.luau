--!strict
--[=[
	@class SimpleLogger

	A minimal logging utility that auto-prefixes messages with the calling
	module's name. `info` and `warn` always print; `debug` only prints when
	running inside Studio.

	Each method has the signature `(...any) -> ()` and forwards its
	arguments to the underlying `print` or `warn`.

	```lua
	local Log = require(path.to.SimpleLogger)
	Log.info("starting up")  -- [MyModule] INFO: starting up
	```
]=]

--[=[
	@within SimpleLogger
	@prop debug (...any) -> ()

	Studio-only debug logging — silent in published experiences.
]=]

--[=[
	@within SimpleLogger
	@prop info (...any) -> ()

	Informational logging via `print`.
]=]

--[=[
	@within SimpleLogger
	@prop warn (...any) -> ()

	Warning logging via `warn`.
]=]

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
