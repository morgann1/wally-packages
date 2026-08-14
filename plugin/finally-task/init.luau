--!strict
-- (c) Daniel P H Fox, licensed under MIT

local Package = script.Parent
local doCleanup = require(Package.doCleanup)

--[=[
	@class FinallyTask

	Runs a callback on a new thread and guarantees its cleanup scope is torn
	down exactly once, whether the callback errors, is cancelled from
	outside, or the returned destructor is called.
]=]

--[=[
	@within FinallyTask
	@function FinallyTask

	Spawns `callback` via `taskExec` (typically `task.spawn` or
	`task.defer`), passing it a fresh cleanup scope followed by the extra
	arguments. The callback registers its cleanup tasks into that scope; if
	it errors, the scope is passed to `doCleanup` before the error
	propagates.

	```lua
	local stop = FinallyTask(task.spawn, function(scope)
		table.insert(scope, workspace.ChildAdded:Connect(print))
		while true do task.wait(1) end
	end)
	-- later: cancels the thread and runs the scope's cleanup
	stop()
	```

	@param taskExec (callback, scope, Args...) -> thread -- Scheduler used to start the callback, e.g. `task.spawn`.
	@param callback (scope: { unknown }, Args...) -> () -- Work to run; receives the cleanup scope first.
	@param ... Args... -- Extra arguments forwarded to the callback.
	@return () -> () -- Destructor: cancels the thread (if still running) and cleans up the scope. Safe to call more than once.
]=]
local function FinallyTask<Args...>(
	taskExec: (
		callback: ({ unknown }, Args...) -> (),
		scope: { unknown },
		Args...
	) -> thread,
	callback: ({ unknown }, Args...) -> (),
	...: Args...
): () -> ()
	local destroyed = false
	local scope: { unknown } = {}
	local coro: thread = taskExec(function(scope, ...)
		local ok, result = xpcall(callback :: any, function(err)
			destroyed = true
			doCleanup(scope)
			return err
		end, scope, ...)
		if not ok then
			error(result)
		end
	end, scope, ...)
	return function()
		if destroyed then
			return
		end
		pcall(task.cancel, coro)
		destroyed = true
		doCleanup(scope)
	end
end

return FinallyTask
