--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local container = ReplicatedStorage.Modules["character-promise-utils"]
local CharacterPromiseUtils = require(container["character-promise-utils"])

-- The functions only touch `Character` and `CharacterAdded`, so a table
-- stands in for the Player, with a BindableEvent backing the signal.
local function makeFakePlayer(character: Model?)
	local bindable = Instance.new("BindableEvent")
	local fakePlayer = {
		Character = character,
		CharacterAdded = bindable.Event,
	}
	return fakePlayer, bindable
end

describe("character-promise-utils", function()
	test("resolves immediately when the character already exists", function()
		local character = Instance.new("Model")
		local fakePlayer = makeFakePlayer(character)

		local promise = CharacterPromiseUtils.promiseCharacter(fakePlayer :: any)
		expect(promise:expect()).toBe(character)

		character:Destroy()
	end)

	test("resolves once CharacterAdded fires", function()
		local fakePlayer, bindable = makeFakePlayer(nil)
		local character = Instance.new("Model")

		local promise = CharacterPromiseUtils.promiseCharacter(fakePlayer :: any)
		bindable:Fire(character)

		expect(promise:expect()).toBe(character)

		bindable:Destroy()
		character:Destroy()
	end)
end)
