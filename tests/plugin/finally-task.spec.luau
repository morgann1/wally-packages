--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local FinallyTask = require(ReplicatedStorage.PluginLib["finally-task"]["finally-task"])

describe("finally-task", function()
	test("passes the scope and extra arguments to the callback", function()
		local gotScope: { unknown }? = nil
		local gotArg: string? = nil

		local destroy = FinallyTask(task.spawn, function(scope, arg: string)
			gotScope = scope
			gotArg = arg
		end, "hello")

		expect(gotScope).toEqual(expect.any("table"))
		expect(gotArg).toBe("hello")
		destroy()
	end)

	test("destroy cancels the task and cleans the scope exactly once", function()
		local cleanups = 0

		local destroy = FinallyTask(task.spawn, function(scope)
			table.insert(scope, function()
				cleanups += 1
			end)
			task.wait(60)
		end)

		expect(cleanups).toBe(0)
		destroy()
		expect(cleanups).toBe(1)
		destroy()
		expect(cleanups).toBe(1)
	end)

	test("an erroring callback cleans its scope", function()
		local cleanups = 0

		-- Resume through a bare coroutine so the error is swallowed by
		-- coroutine.resume instead of surfacing in a task.spawn thread.
		local destroy = FinallyTask(function(callback, scope, ...)
			local thread = coroutine.create(callback)
			coroutine.resume(thread, scope, ...)
			return thread
		end, function(scope)
			table.insert(scope, function()
				cleanups += 1
			end)
			error("expected failure")
		end)

		expect(cleanups).toBe(1)
		-- The failure already destroyed the task; destroy must not re-clean.
		destroy()
		expect(cleanups).toBe(1)
	end)
end)
