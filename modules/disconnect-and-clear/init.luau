--!strict
--[=[
	@class disconnectAndClear

	Disconnects every `RBXScriptConnection` in the provided array, then
	empties the array. Useful for batch cleanup of stored connections.
]=]

--[=[
	@within disconnectAndClear
	@function disconnectAndClear

	@param connections { RBXScriptConnection } -- Array of connections to disconnect and clear.
]=]
local function disconnectAndClear(connections: { RBXScriptConnection }): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

return disconnectAndClear
