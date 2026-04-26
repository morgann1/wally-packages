--!strict
-- Originally (c) Studio Elttob 2024.

--[=[
	@class SensationSounds

	A set of named UI sound effects for Studio plugins, modeled after
	Studio Elttob's Sensation library. The module exports a factory:
	pass it a table of sound asset ids keyed by purpose and it returns
	the same table after preloading every entry off the main thread.

	```lua
	local SensationSounds = require(path.to.SensationSounds)
	local sounds = SensationSounds({
		generic = "rbxassetid://1234",
		success = "rbxassetid://5678",
	})
	-- sounds.generic is "rbxassetid://1234"
	-- sounds.attention is nil — slot wasn't provided
	```
]=]

local ContentProvider = game:GetService("ContentProvider")

--[=[
	@within SensationSounds
	@type SoundKey "generic" | "attention" | "subtle" | "success" | "fail" | "ask"

	The closed set of sound slots Sensation recognizes.
]=]
export type SoundKey = "generic" | "attention" | "subtle" | "success" | "fail" | "ask"

--[=[
	@within SensationSounds
	@type Sounds { [SoundKey]: string? }

	A partial map of [SoundKey] to `rbxassetid://...`. Missing keys
	mean the slot has no sound configured.
]=]
export type Sounds = { [SoundKey]: string? }

--[=[
	@within SensationSounds
	@function SensationSounds

	Preloads each provided sound asset id off the main thread and
	returns the same table for chaining.

	@param sounds Sounds
	@return Sounds
]=]
local function SensationSounds(sounds: Sounds): Sounds
	for _, soundId in sounds do
		task.spawn(function()
			ContentProvider:PreloadAsync({ soundId })
		end)
	end
	return sounds
end

return SensationSounds
