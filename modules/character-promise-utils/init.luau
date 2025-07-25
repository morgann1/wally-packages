--[=[
	Utility for Roblox character objects that involve promises.
	@class CharacterPromiseUtils
]=]

local Promise = require(script.Parent.Promise)
local disconnectAndClear = require(script.Parent.disconnectAndClear)

local CharacterPromiseUtils = {}

--[=[
	Returns a promise that will resolve once a character exists.

	@param player Player
	@return Promise<Model>
]=]
function CharacterPromiseUtils.promiseCharacter(player: Player)
	assert(typeof(player) == "Instance", "Bad player")

	local connections = {}

	local promise = Promise.new(function(resolve, reject)
		if player.Character then
			resolve(player.Character)
			return
		end

		table.insert(
			connections,
			player.CharacterAdded:Connect(function(character)
				resolve(character)
				return
			end)
		)
	end)

	promise:finally(function()
		disconnectAndClear(connections)
	end)

	return promise
end

return CharacterPromiseUtils
