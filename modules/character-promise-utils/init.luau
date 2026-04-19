--!strict
--[=[
	Utility for Roblox character objects that involve promises.
	@class CharacterPromiseUtils
]=]

local disconnectAndClear = require(script.Parent.disconnectAndClear)
local Promise = require(script.Parent.Promise)

local CharacterPromiseUtils = {}

--[=[
	Returns a promise that will resolve once a character exists.

	@param player Player
	@return Promise<Model>
]=]
function CharacterPromiseUtils.promiseCharacter(player: Player)
	local connections: { RBXScriptConnection } = {}

	local promise = Promise.new(function(resolve, _reject)
		if player.Character ~= nil then
			resolve(player.Character)
			return
		end

		table.insert(
			connections,
			player.CharacterAdded:Connect(function(character)
				resolve(character)
			end)
		)
	end)

	promise:finally(function()
		disconnectAndClear(connections)
	end)

	return promise
end

return CharacterPromiseUtils
