--!strict
--[=[
	@class safePlayerAdded

	Runs a callback for every player currently in the game **and** every
	player who joins afterwards. Avoids the race condition where players
	added before your script ran are missed by `Players.PlayerAdded`.
]=]

local Players = game:GetService("Players")

--[=[
	@within safePlayerAdded
	@function safePlayerAdded

	@param callback (Player) -> () -- Invoked for each existing and future player.
	@return RBXScriptConnection -- The `PlayerAdded` connection. Disconnect to stop receiving future callbacks.
]=]
local function safePlayerAdded(callback: (Player) -> ()): RBXScriptConnection
	for _, player in Players:GetPlayers() do
		task.spawn(callback, player)
	end

	return Players.PlayerAdded:Connect(callback)
end

return safePlayerAdded
