-- When using Deferred signal mode: scripts parented to objects are not able to listen to their own .Destroying event.
-- This script is cloned and used to listen to the .Destroying event in a separate thread.

local bindEvent: BindableEvent = script.Bind

bindEvent.Event:Connect(function(instance: Instance, callback: () -> ())
	local destroyingConnection
	local ancestryChangedConnection

	-- Listen to AncestryChanged as well as Destroying, since some events like falling into the void
	-- do not actually Destroy instances.
	ancestryChangedConnection = instance.AncestryChanged:Connect(function()
		if not instance:IsDescendantOf(game) then
			destroyingConnection:Disconnect()
			ancestryChangedConnection:Disconnect()
			callback()
			script:Destroy()
		end
	end)

	destroyingConnection = instance.Destroying:Once(function()
		-- No need to disconnect destroyingConnection since we're only connecting to it :Once
		ancestryChangedConnection:Disconnect()
		callback()
		script:Destroy()
	end)
end)
