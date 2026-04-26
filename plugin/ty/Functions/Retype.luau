--!strict
-- Originally (c) Daniel P H Fox.

local Package = script.Parent.Parent

local Types = require(Package.Types)

local Retype: Types.FnRetype = function(def)
	return def
end

return Retype