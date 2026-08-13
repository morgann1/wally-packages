--!strict
-- ReactRoblox.act refuses to run without the mock scheduler; the global
-- must be set before ReactRoblox is required into this module registry.
_G.__ROACT_17_MOCK_SCHEDULER__ = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

-- Requiring Foundation loads the entire vendored graph (every sibling
-- package plus the external roblox/react family), so this spec is the
-- broadest proof that the wally conversion holds together.
local foundationFolder = ReplicatedStorage.RobloxPackages.foundation
local Foundation = require(foundationFolder.foundation)
local React = require(foundationFolder.React)
local ReactRoblox = require(foundationFolder.ReactRoblox)

describe("foundation", function()
	test("exports components and the provider", function()
		expect(Foundation.View).never.toBeNil()
		expect(Foundation.Text).never.toBeNil()
		expect(Foundation.Button).never.toBeNil()
		expect(Foundation.FoundationProvider).never.toBeNil()
	end)

	test("components create valid React elements", function()
		local element = React.createElement(Foundation.Text, { Text = "hello" })
		expect(React.isValidElement(element)).toBe(true)
	end)

	test("mounts Text under FoundationProvider", function()
		local container = Instance.new("Folder")
		local root = ReactRoblox.createRoot(container)

		ReactRoblox.act(function()
			root:render(React.createElement(Foundation.FoundationProvider, {}, {
				Label = React.createElement(Foundation.Text, { Text = "hello" }),
			}))
		end)

		local label = container:FindFirstChildWhichIsA("TextLabel", true)
		expect(label).never.toBeNil()
		expect((label :: TextLabel).Text).toBe("hello")

		ReactRoblox.act(function()
			root:unmount()
		end)
	end)
end)
