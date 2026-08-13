--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local Event = require(ReplicatedStorage.PluginLib.event.event)

describe("event", function()
	test("fire reaches every connected listener with the arguments", function()
		local connect, fire = Event()
		local seen = {}
		connect(function(value: number)
			table.insert(seen, `a{value}`)
		end)
		connect(function(value: number)
			table.insert(seen, `b{value}`)
		end)

		fire(1)

		table.sort(seen)
		expect(seen).toEqual({ "a1", "b1" })
	end)

	test("disconnecting stops future deliveries", function()
		local connect, fire = Event()
		local received = {}
		local disconnect = connect(function(value: number)
			table.insert(received, value)
		end)

		fire(1)
		disconnect()
		fire(2)

		expect(received).toEqual({ 1 })
	end)
end)
