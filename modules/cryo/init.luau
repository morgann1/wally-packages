--!strict
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
