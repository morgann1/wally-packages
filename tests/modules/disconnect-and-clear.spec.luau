--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local disconnectAndClear = require(ReplicatedStorage.Modules["disconnect-and-clear"]["disconnect-and-clear"])

describe("disconnect-and-clear", function()
	test("disconnects every connection and empties the array", function()
		local bindable = Instance.new("BindableEvent")
		local connections = {
			bindable.Event:Connect(function() end),
			bindable.Event:Connect(function() end),
		}

		disconnectAndClear(connections)

		expect(#connections).toBe(0)
		bindable:Destroy()
	end)

	test("tolerates an empty array", function()
		local connections: { RBXScriptConnection } = {}
		disconnectAndClear(connections)
		expect(#connections).toBe(0)
	end)
end)
