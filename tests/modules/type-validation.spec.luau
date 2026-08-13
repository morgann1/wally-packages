--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local TypeValidation = require(ReplicatedStorage.Modules["type-validation"]["type-validation"])

local NAN = 0 / 0

describe("type-validation", function()
	test("validateNumber rejects non-numbers and NaN", function()
		expect(TypeValidation.validateNumber(5)).toBe(true)
		expect(TypeValidation.validateNumber(-0.5)).toBe(true)
		expect(TypeValidation.validateNumber(NAN)).toBe(false)
		expect(TypeValidation.validateNumber("5")).toBe(false)
		expect(TypeValidation.validateNumber(nil)).toBe(false)
	end)

	test("validateVector3 rejects non-vectors and NaN components", function()
		expect(TypeValidation.validateVector3(Vector3.new(1, 2, 3))).toBe(true)
		expect(TypeValidation.validateVector3(Vector3.new(NAN, 0, 0))).toBe(false)
		expect(TypeValidation.validateVector3({ X = 1, Y = 2, Z = 3 })).toBe(false)
	end)

	test("validateCFrame rejects non-CFrames and NaN positions", function()
		expect(TypeValidation.validateCFrame(CFrame.new(1, 2, 3))).toBe(true)
		expect(TypeValidation.validateCFrame(CFrame.new(NAN, 0, 0))).toBe(false)
		expect(TypeValidation.validateCFrame(Vector3.new())).toBe(false)
	end)

	test("validateInstance rejects imposter tables and wrong classes", function()
		local part = Instance.new("Part")
		expect(TypeValidation.validateInstance(part, "BasePart")).toBe(true)
		expect(TypeValidation.validateInstance(part, "Folder")).toBe(false)
		expect(TypeValidation.validateInstance({ Position = Vector3.new() }, "BasePart")).toBe(false)
		part:Destroy()
	end)

	test("validateSimpleTable checks key types and item validator", function()
		local validateNumber = TypeValidation.validateNumber
		expect(TypeValidation.validateSimpleTable({ a = 1, b = 2 }, "string", validateNumber)).toBe(true)
		expect(TypeValidation.validateSimpleTable({ a = 1, [1] = 2 }, "string", validateNumber)).toBe(false)
		expect(TypeValidation.validateSimpleTable({ a = "x" }, "string", validateNumber)).toBe(false)
		expect(TypeValidation.validateSimpleTable("not a table", "string", validateNumber)).toBe(false)
	end)
end)
