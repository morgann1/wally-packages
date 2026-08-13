--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local ty = require(ReplicatedStorage.PluginLib.ty.ty)

describe("ty constants", function()
	test("Typeof-based constants match their type and nothing else", function()
		expect(ty.String:Matches("hi")).toBe(true)
		expect(ty.String:Matches(5)).toBe(false)
		expect(ty.Number:Matches(5)).toBe(true)
		expect(ty.Boolean:Matches(false)).toBe(true)
		expect(ty.Table:Matches({})).toBe(true)
		expect(ty.Function:Matches(print)).toBe(true)
	end)

	test("Unknown accepts everything, Never accepts nothing", function()
		expect(ty.Unknown:Matches(newproxy())).toBe(true)
		expect(ty.Never:Matches(nil)).toBe(false)
		expect(ty.Never:Cast(5).some).toBe(false)
	end)

	test("literal constants use exact equality", function()
		expect(ty.True:Matches(true)).toBe(true)
		expect(ty.True:Matches(1)).toBe(false)
		expect(ty.Nil:Matches(nil)).toBe(true)
		expect(ty.Nil:Matches(false)).toBe(false)
	end)
end)

describe("ty combinators", function()
	test("Just matches one literal", function()
		local justFive = ty.Just(5)
		expect(justFive:Matches(5)).toBe(true)
		expect(justFive:Matches(6)).toBe(false)
		expect(justFive:Cast(6).some).toBe(false)
	end)

	test("Optional lets nil through", function()
		local maybeString = ty.String:Optional()
		expect(maybeString:Matches(nil)).toBe(true)
		expect(maybeString:Matches("hi")).toBe(true)
		expect(maybeString:Matches(5)).toBe(false)
	end)

	test("Or and And compose defs", function()
		local stringOrNumber = ty.String:Or(ty.Number)
		expect(stringOrNumber:Matches("hi")).toBe(true)
		expect(stringOrNumber:Matches(5)).toBe(true)
		expect(stringOrNumber:Matches(true)).toBe(false)

		local positiveNumber = ty.Number:And(ty.Predicate(function(x)
			return (x :: number) > 0
		end))
		expect(positiveNumber:Matches(5)).toBe(true)
		expect(positiveNumber:Matches(-5)).toBe(false)
		expect(positiveNumber:Matches("5")).toBe(false)
	end)

	test("Array requires contiguous numeric keys of the value type", function()
		local numbers = ty.Number:Array()
		expect(numbers:Matches({ 1, 2, 3 })).toBe(true)
		expect(numbers:Matches({})).toBe(true)
		expect(numbers:Matches({ 1, "2" } :: { any })).toBe(false)
		expect(numbers:Matches({ a = 1 })).toBe(false)
		expect(numbers:Matches("nope")).toBe(false)
	end)

	test("MapOf checks keys and values", function()
		local scores = ty.String:MapOf(ty.Number)
		expect(scores:Matches({ alice = 1, bob = 2 })).toBe(true)
		expect(scores:Matches({ alice = "1" })).toBe(false)
		expect(scores:Matches({ [1] = 1 })).toBe(false)
	end)

	test("Struct casts field-wise and honors exhaustive", function()
		local open = ty.Struct({ exhaustive = false }, { name = ty.String })
		local closed = ty.Struct({ exhaustive = true }, { name = ty.String })
		local value = { name = "x", extra = 1 }

		expect(open:Cast(value).some).toBe(true)
		expect(closed:Cast(value).some).toBe(false)
		expect(open:Cast({ name = 5 }).some).toBe(false)

		-- Cast rebuilds the table from the declared fields only.
		local casted = open:Cast(value)
		expect((casted :: any).value).toEqual({ name = "x" })
	end)

	test("Tuple casts positional values", function()
		local pair = ty.Tuple({ exhaustive = true }, { ty.String, ty.Number })
		expect(pair:Cast({ "x", 1 } :: { any }).some).toBe(true)
		expect(pair:Cast({ "x", "y" } :: { any }).some).toBe(false)
		expect(pair:Cast({ "x", 1, true } :: { any }).some).toBe(false)
	end)
end)

describe("ty conversions", function()
	test("CastOrError returns the casted value or throws", function()
		expect(ty.Number:CastOrError(5)).toBe(5)
		expect(function()
			ty.Number:CastOrError("hi")
		end).toThrow("Could not cast")
	end)

	test("IntoNumber converts through tonumber with optional base", function()
		local numberish = ty.String:IntoNumber()
		expect(numberish:Cast("42")).toEqual({ some = true, value = 42 })
		expect(numberish:Cast("nope").some).toBe(false)

		local hex = ty.String:IntoNumber(16)
		expect(hex:Cast("ff")).toEqual({ some = true, value = 255 })
	end)

	test("IntoString converts through tostring", function()
		expect(ty.Number:IntoString():Cast(42)).toEqual({ some = true, value = "42" })
	end)

	test("IntoDefault substitutes nil", function()
		local withDefault = ty.Number:IntoDefault(7)
		expect(withDefault:Cast(nil)).toEqual({ some = true, value = 7 })
		expect(withDefault:Cast(3)).toEqual({ some = true, value = 3 })
		expect(withDefault:Cast("x").some).toBe(false)
	end)

	test("IgnoreInvalid maps failures to some(nil)", function()
		local lax = ty.Number:IgnoreInvalid()
		expect(lax:Cast(3)).toEqual({ some = true, value = 3 })
		expect(lax:Cast("x")).toEqual({ some = true })
	end)

	test("IntoTagged stamps a __tag and boxes scalars", function()
		local tagged = ty.Number:IntoTagged("count")
		expect(tagged:Cast(3)).toEqual({ some = true, value = { value = 3, __tag = "count" } })

		local taggedTable = ty.String:MapOf(ty.Number):IntoTagged("scores")
		local original = { a = 1 }
		local result = taggedTable:Cast(original)
		expect((result :: any).value).toEqual({ a = 1, __tag = "scores" })
		-- The original table is cloned, not mutated.
		expect((original :: any).__tag).toBe(nil)
	end)

	test("Nicknamed only renames the def", function()
		local nicknamed = ty.Number:Nicknamed("Count")
		expect(nicknamed.ExpectsType).toBe("Count")
		expect(nicknamed:Matches(5)).toBe(true)
	end)
end)
