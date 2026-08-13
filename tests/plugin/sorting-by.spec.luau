--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local sortingBy = require(ReplicatedStorage.PluginLib["sorting-by"]["sorting-by"])

type Entry = { group: number, name: string }

describe("sorting-by", function()
	test("sorts by the extracted keys with later keys breaking ties", function()
		local entries: { Entry } = {
			{ group = 2, name = "b" },
			{ group = 1, name = "z" },
			{ group = 2, name = "a" },
			{ group = 1, name = "a" },
		}

		table.sort(
			entries,
			sortingBy(function(entry: Entry)
				return { entry.group, entry.name }
			end)
		)

		expect(entries).toEqual({
			{ group = 1, name = "a" },
			{ group = 1, name = "z" },
			{ group = 2, name = "a" },
			{ group = 2, name = "b" },
		})
	end)

	test("returns false for fully equal keys, keeping table.sort valid", function()
		local comparator = sortingBy(function(entry: Entry)
			return { entry.group, entry.name }
		end)
		local a: Entry = { group = 1, name = "same" }
		local b: Entry = { group = 1, name = "same" }

		expect(comparator(a, b)).toBe(false)
		expect(comparator(b, a)).toBe(false)
	end)

	test("asserts when extractors disagree on key count", function()
		local comparator = sortingBy(function(entry: any)
			return entry.keys
		end)

		expect(function()
			comparator({ keys = { 1 } }, { keys = { 1, 2 } })
		end).toThrow("same number of values")
	end)
end)
