local Players = game:GetService("Players")

local function safePlayerAdded(callback: (Player) -> ())
	for _, player in Players:GetPlayers() do
		task.spawn(callback, player)
	end

	return Players.PlayerAdded:Connect(callback)
end

return safePlayerAdded
