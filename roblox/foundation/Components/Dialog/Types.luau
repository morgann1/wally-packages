local Foundation = script:FindFirstAncestor("foundation")

local Constants = require(Foundation.Constants)
local DialogSize = require(Foundation.Enums.DialogSize)
local OnCloseCallbackReason = require(Foundation.Enums.OnCloseCallbackReason)

type DialogSize = DialogSize.DialogSize
type OnCloseCallbackReason = OnCloseCallbackReason.OnCloseCallbackReason

return {
	nonSelectable = Constants.MODAL.DISABLE_SELECTION,
	isolatedSelectionGroup = Constants.MODAL.TRAP_FOCUS,
}
