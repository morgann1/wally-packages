--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local WideLogger = require(ReplicatedStorage.Modules["wide-logger"]["wide-logger"])

describe("wide-logger", function()
	test("span collects fields via set and merge", function()
		local span = WideLogger.span("spec.collect", { seeded = 1 })
		span:set("single", 2):merge({ merged = 3, seeded = 10 })

		expect(span._name).toBe("spec.collect")
		expect(span._fields).toEqual({ seeded = 10, single = 2, merged = 3 })
		span:finish()
	end)

	test("finish is terminal: later set/merge/fail are no-ops", function()
		local span = WideLogger.span("spec.terminal")
		span:finish()
		span:set("late", 1)
		span:merge({ later = 2 })
		span:fail("nope")

		expect(span._fields).toEqual({})
		expect(span._failed).toBe(false)
		expect(span._finished).toBe(true)
	end)

	test("withSpan returns the callback result and finishes the span", function()
		local seen: any = nil
		local result = WideLogger.withSpan("spec.success", nil, function(span)
			seen = span
			span:set("worked", true)
			return 42
		end)

		expect(result).toBe(42)
		expect(seen._finished).toBe(true)
		expect(seen._failed).toBe(false)
	end)

	test("withSpan marks the span failed and rethrows on error", function()
		local seen: any = nil
		expect(function()
			WideLogger.withSpan("spec.failure", nil, function(span)
				seen = span
				error("boom")
			end)
		end).toThrow("boom")

		expect(seen._finished).toBe(true)
		expect(seen._failed).toBe(true)
		expect(tostring(seen._err)).toContain("boom")
	end)
end)
