--!strict
--[=[
	@class Cryo

	A collection of methods for working with immutable data in a functional
	way. Operations return new tables rather than mutating their inputs.

	The library is split into two namespaces:

	- `Cryo.Dictionary` — operations on string-keyed tables.
	- `Cryo.List` — operations on array-like tables.

	`Cryo.None` is a sentinel that, when passed as a value to dictionary
	merges, removes the corresponding key from the result.
]=]

local Dictionary = require(script.Dictionary)
local List = require(script.List)
local None = require(script.None)
local isEmpty = require(script.isEmpty)

export type None = typeof(None)

return table.freeze({
	Dictionary = Dictionary,
	List = List,
	isEmpty = isEmpty,
	None = None,
})
