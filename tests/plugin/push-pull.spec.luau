--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local PushPull = require(ReplicatedStorage.PluginLib["push-pull"]["push-pull"])

describe("push-pull", function()
	test("maybe: pull returns none when empty, then buffered values in order", function()
		local push, pull = PushPull.maybe()

		expect(pull().some).toBe(false)

		push("first")
		push("second")

		local first = pull()
		expect(first).toEqual({ some = true, value = "first" })
		expect(pull()).toEqual({ some = true, value = "second" })
		expect(pull().some).toBe(false)
	end)

	test("yield: buffered pushes are pulled without yielding", function()
		local push, pull = PushPull.yield()
		push(1, "one")
		push(2, "two")

		local number, word = pull()
		expect(number).toBe(1)
		expect(word).toBe("one")
		expect((pull())).toBe(2)
	end)

	test("yield: pull blocks until a value is pushed", function()
		local push, pull = PushPull.yield()
		local received: string? = nil

		task.spawn(function()
			received = pull()
		end)

		expect(received).toBe(nil)
		push("wake up")
		-- push resumes the waiter via task.spawn, which runs it synchronously.
		expect(received).toBe("wake up")
	end)
end)
