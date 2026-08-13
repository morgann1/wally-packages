--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local IconRamp = require(ReplicatedStorage.PluginLib["icon-ramp"]["icon-ramp"])

local function icon(size: number): IconRamp.Icon
	return {
		size = size,
		variants = { light = `light{size}`, dark = `dark{size}` },
	}
end

describe("icon-ramp", function()
	test("selectNearestSize picks the smallest icon at least as big as the target", function()
		local ramp: IconRamp.IconRamp = { icon(512), icon(64), icon(128) }

		expect((IconRamp.selectNearestSize(ramp, 64) :: any).size).toBe(64)
		expect((IconRamp.selectNearestSize(ramp, 65) :: any).size).toBe(128)
		expect((IconRamp.selectNearestSize(ramp, 16) :: any).size).toBe(64)
	end)

	test("selectNearestSize falls back to the largest icon", function()
		local ramp: IconRamp.IconRamp = { icon(64), icon(512) }
		expect((IconRamp.selectNearestSize(ramp, 1024) :: any).size).toBe(512)
	end)

	test("Types.IconRamp validates ramp shapes", function()
		expect(IconRamp.Types.IconRamp:Matches({ icon(64) })).toBe(true)
		expect(IconRamp.Types.Icon:Matches({ size = 64, variants = { light = "x" } })).toBe(true)
		expect(IconRamp.Types.Icon:Matches({ size = "64", variants = {} })).toBe(false)
		expect(IconRamp.Types.IconVariant:Matches("mono")).toBe(true)
		expect(IconRamp.Types.IconVariant:Matches("sepia")).toBe(false)
	end)
end)
