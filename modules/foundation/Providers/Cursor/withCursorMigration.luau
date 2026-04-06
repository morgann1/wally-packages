local Foundation = script:FindFirstAncestor("foundation")
local Packages = Foundation.Parent

local React = require(Packages.React)

local CursorContext = require(script.Parent.CursorContext)

local function withCursorMigration(renderWithCursorMigration)
	return React.createElement(CursorContext.Consumer, {
		render = function(context)
			return renderWithCursorMigration(context.getCursor :: any)
		end,
	})
end

return withCursorMigration
