local Players = game:GetService("Players")

local player = Players.LocalPlayer
local destructionHandlerTemplate = script.DestructionHandler

-- When using Deferred signal mode: scripts parented to an object cannot listen to that object's Destroying event, since it is
-- disconnected up before being executed.
-- To avoid this, we'll use a hacky solution and clone a listener script into PlayerScripts.
-- This script will continue running after the instance is destroyed and allow us to run e.g. cleanup code when it gets destroyed.
local function bindToInstanceDestroyed(instance: Instance, callback: () -> ())
	local destructionHandler = destructionHandlerTemplate:Clone()
	destructionHandler.Parent = player.PlayerScripts

	-- Defer firing the BindableEvent so the script is able to initialize first
	task.defer(function()
		destructionHandler.Bind:Fire(instance, callback)
	end)
end

return bindToInstanceDestroyed
