--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

-- The wrapper creates InputContext/InputAction instances and parents its
-- storage folder to the DataModel at require time; skip everything if the
-- environment doesn't allow that.
local requireOk, input = pcall(function()
	return require(ReplicatedStorage.Modules["ias-wrapper"]["ias-wrapper"]) :: any
end)
local testWhenAvailable: typeof(test) = if requireOk then test else test.skip :: any

describe("ias-wrapper", function()
	testWhenAvailable("context reconciles into an InputContext with counted enabling", function()
		local ctx = input.context("IasWrapperSpecContext", { priority = 1234 })

		local storage = game:FindFirstChild("Inputs")
		expect(storage).never.toBe(nil)
		local inputContext = (storage :: Instance):FindFirstChild("IasWrapperSpecContext") :: InputContext
		expect(inputContext).never.toBe(nil)
		expect(inputContext.Priority).toBe(1234)
		expect(inputContext.Enabled).toBe(false)

		input.enable(ctx)
		input.enable(ctx)
		expect(inputContext.Enabled).toBe(true)

		input.disable(ctx)
		expect(inputContext.Enabled).toBe(true)
		input.disable(ctx)
		expect(inputContext.Enabled).toBe(false)
	end)

	testWhenAvailable("enable warns instead of erroring for unknown contexts", function()
		expect(function()
			input.enable({ priority = 1 })
		end).never.toThrow()
	end)

	testWhenAvailable("action returns the descriptor augmented with the polling API", function()
		local action = input.action({
			name = "IasWrapperSpecAction",
			description = "spec action",
			type = "bool",
			binds = {
				input.binding({ input = Enum.KeyCode.F }),
			},
		})

		expect(typeof(action.is_pressed)).toBe("function")
		expect(typeof(action.get_state)).toBe("function")
		expect(typeof(action.pressed)).toBe("RBXScriptSignal")
		expect(action:is_pressed()).toBe(nil)

		input.clear_state()
	end)
end)
