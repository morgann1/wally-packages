--!strict
--[=[
	@class bindToInstanceDestroyed

	A reliable way to execute cleanup code when an instance is destroyed.

	Under Deferred signal mode, a script parented to an object cannot listen
	to that object's `Destroying` event — the connection is severed before
	the script runs. As a workaround, this module clones a listener script
	into `PlayerScripts`, which outlives the destroyed instance and runs the
	provided callback when it fires.
]=]

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local destructionHandlerTemplate = script.DestructionHandler

--[=[
	@within bindToInstanceDestroyed
	@function bindToInstanceDestroyed

	Registers a callback that runs once `instance` is destroyed.

	@param instance Instance -- The instance to watch.
	@param callback () -> () -- Invoked exactly once after `instance` is destroyed.
]=]
local function bindToInstanceDestroyed(instance: Instance, callback: () -> ()): ()
	local destructionHandler = destructionHandlerTemplate:Clone()
	destructionHandler.Parent = player.PlayerScripts

	-- Defer firing the BindableEvent so the script is able to initialize first
	task.defer(function()
		destructionHandler.Bind:Fire(instance, callback)
	end)
end

return bindToInstanceDestroyed
