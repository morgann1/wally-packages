--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local Cryo = require(ReplicatedStorage.Modules.cryo.cryo)

local function sorted(list: { any }): { any }
	local copy = table.clone(list)
	table.sort(copy)
	return copy
end

describe("Cryo.Dictionary", function()
	test("join merges left to right and Cryo.None removes keys", function()
		local joined = Cryo.Dictionary.join({ a = 1, b = 2 }, { b = 3, c = 4 }, { a = Cryo.None })
		expect(joined).toEqual({ b = 3, c = 4 })
	end)

	test("join with one argument returns a metatable-free copy", function()
		local source = setmetatable({ a = 1 }, { __index = { b = 2 } })
		local joined = Cryo.Dictionary.join(source :: any)
		expect(joined).never.toBe(source)
		expect(getmetatable(joined :: any)).toBe(nil)
		expect(joined).toEqual({ a = 1 })
	end)

	test("union keeps Cryo.None as a literal value", function()
		local unioned = Cryo.Dictionary.union({ a = 1 }, { b = Cryo.None })
		expect(unioned.a).toBe(1)
		expect(unioned.b).toBe(Cryo.None)
	end)

	test("keys and values enumerate the dictionary", function()
		local dictionary = { a = 1, b = 2, c = 3 }
		expect(sorted(Cryo.Dictionary.keys(dictionary))).toEqual({ "a", "b", "c" })
		expect(sorted(Cryo.Dictionary.values(dictionary))).toEqual({ 1, 2, 3 })
	end)

	test("map transforms values and can reassign keys or drop entries", function()
		local mapped = Cryo.Dictionary.map({ a = 1, b = 2 }, function(value: number, key: string)
			return value * 10, key .. key
		end)
		expect(mapped).toEqual({ aa = 10, bb = 20 })

		local dropped = Cryo.Dictionary.map({ a = 1, b = 2 }, function(value)
			return if value > 1 then value else nil
		end)
		expect(dropped).toEqual({ b = 2 })
	end)

	test("filter keeps entries matching the predicate", function()
		local filtered = Cryo.Dictionary.filter({ a = 1, b = 2, c = 3 }, function(value, key)
			return value >= 2 and key ~= "c"
		end)
		expect(filtered).toEqual({ b = 2 })
	end)

	test("omit removes the listed keys", function()
		expect(Cryo.Dictionary.omit({ a = 1, b = 2, c = 3 }, "a", "c")).toEqual({ b = 2 })
	end)

	test("equals compares dictionaries shallowly", function()
		expect(Cryo.Dictionary.equals({ a = 1 }, { a = 1 }, { a = 1 })).toBe(true)
		expect(Cryo.Dictionary.equals({ a = 1 }, { a = 1, b = 2 })).toBe(false)
		expect(Cryo.Dictionary.equals({ a = 1 }, { a = 2 })).toBe(false)
	end)
end)

describe("Cryo.List", function()
	test("map and filter pass value and index", function()
		expect(Cryo.List.map({ 1, 2, 3 }, function(value, index)
			return value + index
		end)).toEqual({ 2, 4, 6 })

		expect(Cryo.List.filter({ 10, 20, 30, 40 }, function(value, index)
			return value > 10 and index < 4
		end)).toEqual({ 20, 30 })
	end)

	test("filterMap drops nil results and keeps mapped values", function()
		expect(Cryo.List.filterMap({ 1, 2, 3, 4 }, function(value)
			return if value % 2 == 0 then value * 10 else nil
		end)).toEqual({ 20, 40 })
	end)

	test("find and findWhere locate the first match", function()
		expect(Cryo.List.find({ "a", "b", "c" }, "b")).toBe(2)
		expect(Cryo.List.find({ "a" }, "z")).toBe(nil)
		expect(Cryo.List.findWhere({ 5, 10, 15 }, function(value)
			return value > 5
		end)).toBe(2)
	end)

	test("foldLeft and foldRight visit in opposite orders", function()
		expect(Cryo.List.foldLeft({ "a", "b", "c" }, function(accum: string, value: string)
			return accum .. value
		end, "")).toBe("abc")
		expect(Cryo.List.foldRight({ "a", "b", "c" }, function(accum: string, value: string)
			return accum .. value
		end, "")).toBe("cba")
	end)

	test("join concatenates lists and skips Cryo.None entries", function()
		expect(Cryo.List.join({ 1, Cryo.None, 2 }, { 3 })).toEqual({ 1, 2, 3 })
	end)

	test("getRange clamps to the list bounds", function()
		expect(Cryo.List.getRange({ 1, 2, 3, 4 }, 2, 3)).toEqual({ 2, 3 })
		expect(Cryo.List.getRange({ 1, 2 }, 1, 10)).toEqual({ 1, 2 })
	end)

	test("removeIndex, removeRange, removeValue and replaceIndex", function()
		expect(Cryo.List.removeIndex({ 1, 2, 3 }, 2)).toEqual({ 1, 3 })
		expect(Cryo.List.removeRange({ 1, 2, 3, 4, 5 }, 2, 4)).toEqual({ 1, 5 })
		expect(Cryo.List.removeValue({ 1, 2, 1, 3 }, 1)).toEqual({ 2, 3 })
		expect(Cryo.List.replaceIndex({ 1, 2, 3 }, 2, 9)).toEqual({ 1, 9, 3 })
		expect(function()
			Cryo.List.replaceIndex({ 1 }, 5, 9)
		end).toThrow("index must be less")
	end)

	test("reverse, sort and toSet", function()
		expect(Cryo.List.reverse({ 1, 2, 3 })).toEqual({ 3, 2, 1 })
		expect(Cryo.List.sort({ 3, 1, 2 })).toEqual({ 1, 2, 3 })
		expect(Cryo.List.sort({ 1, 2, 3 }, function(a, b)
			return a > b
		end)).toEqual({ 3, 2, 1 })
		expect(Cryo.List.toSet({ "a", "b" })).toEqual({ a = true, b = true })
	end)

	test("equals compares element-wise", function()
		expect(Cryo.List.equals({ 1, 2 }, { 1, 2 })).toBe(true)
		expect(Cryo.List.equals({ 1, 2 }, { 1, 2, 3 })).toBe(false)
	end)
end)

describe("Cryo", function()
	test("isEmpty and the None sentinel", function()
		expect(Cryo.isEmpty({})).toBe(true)
		expect(Cryo.isEmpty({ 1 })).toBe(false)
		expect(tostring(Cryo.None)).toBe("Cryo.None")
	end)
end)
