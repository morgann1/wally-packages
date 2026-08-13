--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local Signal = require(ReplicatedStorage.RobloxPackages.signal.signal)

describe("signal", function()
	test("subscribe receives fired values until unsubscribed", function()
		local signal, fire = Signal.createSignal()
		local received = {}
		local subscription = signal:subscribe(function(value)
			table.insert(received, value)
		end)

		fire(1)
		fire(2)
		subscription:unsubscribe()
		fire(3)

		expect(received).toEqual({ 1, 2 })
	end)
end)
