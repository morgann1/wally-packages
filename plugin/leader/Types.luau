--!strict
-- (c) Studio Elttob 2024. All rights reserved, seek permission before use.

local Packages = script.Parent.Parent

local Event = require(Packages.Event)
local Interposer = require(Packages.Interposer)

export type LeaderApi = {
	leader: () -> Interposer.Peer?,
	selfIsLeader: () -> boolean?,
	onLeaderChanged: Event.Connect<Interposer.Peer?>,
}

return nil
