--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local doCleanup = require(ReplicatedStorage.PluginLib["do-cleanup"]["do-cleanup"])

describe("do-cleanup", function()
	test("destroys instances", function()
		local folder = Instance.new("Folder")
		folder.Parent = workspace
		doCleanup(folder)
		expect(folder.Parent).toBe(nil)
	end)

	test("disconnects connections", function()
		local bindable = Instance.new("BindableEvent")
		local connection = bindable.Event:Connect(function() end)
		doCleanup(connection)
		expect(connection.Connected).toBe(false)
		bindable:Destroy()
	end)

	test("calls functions and destroy/Destroy methods", function()
		local calls = {}
		doCleanup(function()
			table.insert(calls, "fn")
		end)
		doCleanup({
			destroy = function()
				table.insert(calls, "destroy")
			end,
		})
		doCleanup({
			Destroy = function()
				table.insert(calls, "Destroy")
			end,
		})
		expect(calls).toEqual({ "fn", "destroy", "Destroy" })
	end)

	test("cleans arrays in reverse order and empties them", function()
		local order = {}
		local scope: { unknown } = {
			function()
				table.insert(order, 1)
			end,
			function()
				table.insert(order, 2)
			end,
			{
				function()
					table.insert(order, 3)
				end,
			},
		}

		doCleanup(scope)

		expect(order).toEqual({ 3, 2, 1 })
		expect(#scope).toBe(0)
	end)

	test("accepts multiple tasks as varargs", function()
		local count = 0
		local function bump()
			count += 1
		end
		doCleanup(bump, bump, bump)
		expect(count).toBe(3)
	end)
end)
