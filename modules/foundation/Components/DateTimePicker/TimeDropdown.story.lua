local Foundation = script:FindFirstAncestor("foundation")
local Packages = Foundation.Parent
local React = require(Packages.React)

local TimeDropdown = require(script.Parent.TimeDropdown)

return {
	summary = "TimeDropdown",
	stories = {
		{
			name = "TimeDropdown",
			story = function()
				return React.createElement(TimeDropdown, {
					onItemChanged = function() end,
				})
			end,
		},
	},
}
