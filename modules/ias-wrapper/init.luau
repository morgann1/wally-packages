--!strict
--[=[
	@class input

	Lightweight wrapper over Roblox's `InputAction` / `InputContext` /
	`InputBinding` instances. Lets you declare input contexts as nested
	tables of actions, register them once, then enable or disable whole
	contexts on demand.

	The model is: **bindings** (key combinations) live on **actions**
	(named, typed inputs like "jump" or "move"), which live on
	**contexts** (collections of actions enabled together, e.g. "gameplay"
	vs "menu"). A context is enabled when its enable count is positive;
	[input.enable] / [input.disable] increment and decrement that count.

	See:
	[alicesaidhi/383b04a42cad53acb27e017f50fd8086](https://gist.github.com/alicesaidhi/383b04a42cad53acb27e017f50fd8086).
]=]

local UserInputService = game:GetService("UserInputService")
--[[

keybinds -> input action -> input contexts

]]

export type Binding = {
	up: Enum.KeyCode?,
	left: Enum.KeyCode?,
	down: Enum.KeyCode?,
	right: Enum.KeyCode?,
	forward: Enum.KeyCode?,
	backward: Enum.KeyCode?,

	input: Enum.KeyCode?,

	primary_modifier: Enum.KeyCode?,
	secondary_modifier: Enum.KeyCode?,

	clamp_magnitude: boolean?,

	released_threshold: number?,
	pressed_threshold: number?,

	response_curve: number?,
	scale: number?,
	vector2scale: vector?,
	vector3scale: vector?,
}

export type ActionFunctions<T> = {
	is_pressed: (ActionFunctions<T>) -> boolean,
	is_released: (ActionFunctions<T>) -> boolean,
	is_changed: (ActionFunctions<T>) -> boolean,
	get_state: (ActionFunctions<T>) -> T,

	pressed: RBXScriptSignal,
	released: RBXScriptSignal,
	state_changed: RBXScriptSignal<T>,
}

export type Action<T> = {
	name: string,
	description: string,

	type: T,
	binds: { Binding },
}

export type ActionBool = Action<"bool"> & ActionFunctions<boolean>
export type Action1D = Action<"1d"> & ActionFunctions<number>
export type Action2D = Action<"2d"> & ActionFunctions<Vector2>
export type Action3D = Action<"3d"> & ActionFunctions<Vector3>
export type ActionViewport = Action<"viewport"> & ActionFunctions<Vector2>

export type ActionTypes = ActionBool | Action1D | Action2D | Action3D | ActionViewport

export type Context = {
	priority: number?,
	sink: boolean?,

	[string]: ActionTypes | Context,
}

type Vec2 = Vector2
type Vec3 = Vector3

local input = {}

local map_ctx_enabled: { [Context]: number? } = {}
local map_ctx: { [Context]: InputContext? } = {}
local map_actions: { [ActionTypes]: InputAction? } = {}
local storage = Instance.new("Folder")

local pressed = {}
local released = {}
local state_changed = {}

storage.Name = "Inputs"
storage.Parent = game
-- note: we do not cache bindings, it's easier to just recreate them every single time.

local input_action_metatable = {}

input_action_metatable.__index = input_action_metatable

function input_action_metatable.get_state(self: ActionTypes): boolean | number | Vector2 | Vector3
	local action = map_actions[self]
	assert(action, `no input action registered for "{self.name}"`)

	return action:GetState()
end

function input_action_metatable.is_pressed(self: ActionTypes)
	return pressed[self]
end

function input_action_metatable.is_released(self: ActionTypes)
	return released[self]
end

function input_action_metatable.is_changed(self: ActionTypes)
	return state_changed[self]
end

local function reconcile_binding(bind: Binding, action: ActionTypes)
	local input_action = map_actions[action]
	local input_binding = Instance.new("InputBinding")

	input_binding.Down = bind.down or Enum.KeyCode.Unknown
	input_binding.Up = bind.up or Enum.KeyCode.Unknown
	input_binding.Left = bind.left or Enum.KeyCode.Unknown
	input_binding.Right = bind.right or Enum.KeyCode.Unknown
	input_binding.Backward = bind.backward or Enum.KeyCode.Unknown
	input_binding.Forward = bind.forward or Enum.KeyCode.Unknown
	input_binding.KeyCode = bind.input or Enum.KeyCode.Unknown
	input_binding.ClampMagnitudeToOne = if bind.clamp_magnitude ~= nil then bind.clamp_magnitude else true
	input_binding.PressedThreshold = bind.pressed_threshold or 0.5
	input_binding.ReleasedThreshold = bind.released_threshold or 0.2
	input_binding.ResponseCurve = bind.response_curve or 1
	input_binding.Scale = bind.scale or 1
	input_binding.Vector2Scale = if bind.vector2scale
		then Vector2.new(bind.vector2scale.x, bind.vector2scale.y)
		else Vector2.one
	input_binding.Vector3Scale = if bind.vector3scale
		then Vector3.new(bind.vector3scale.x, bind.vector3scale.y, bind.vector3scale.z)
		else Vector3.one

	input_binding.Parent = input_action
end

local function reconcile_action(action: ActionTypes, ctx: Context?)
	local inputctx = ctx and map_ctx[ctx]

	local input_action = map_actions[action]

	if not input_action then
		input_action = Instance.new("InputAction")
		assert(input_action, "Luau")

		input_action.Name = action.name
		input_action.Type = if action.type == "1d"
			then Enum.InputActionType.Direction1D
			elseif action.type == "2d" then Enum.InputActionType.Direction2D
			elseif action.type == "3d" then Enum.InputActionType.Direction3D
			elseif action.type == "viewport" then Enum.InputActionType.ViewportPosition
			elseif action.type == "bool" then Enum.InputActionType.Bool
			else Enum.InputActionType.Bool

		map_actions[action] = input_action

		input_action.Pressed:Connect(function()
			pressed[action] = true
		end)
		input_action.Released:Connect(function()
			released[action] = true
		end)
		input_action.StateChanged:Connect(function()
			state_changed[action] = true
		end)

		local mutable = action :: any
		mutable.pressed = input_action.Pressed
		mutable.released = input_action.Released
		mutable.state_changed = input_action.StateChanged
	end

	assert(input_action, "Luau")
	input_action.Parent = inputctx
	input_action:ClearAllChildren()

	for _, binding in action.binds do
		reconcile_binding(binding, action)
	end
end

local function update_enabled(ctx: Context)
	local count = map_ctx_enabled[ctx]
	local context = map_ctx[ctx]

	if context == nil then
		return
	end

	context.Enabled = count > 0
end

local function reconcile_context(name: string, ctx: Context, parent: Context?)
	local inputctx = map_ctx[ctx]
	map_ctx_enabled[ctx] = map_ctx_enabled[ctx] or 0

	if not inputctx then
		inputctx = Instance.new("InputContext")
		assert(inputctx, "Luau")

		inputctx.Name = name
		inputctx.Parent = storage
		map_ctx[ctx] = inputctx
	end

	assert(inputctx, "Luau")

	if parent and map_ctx[parent] then
		inputctx.Parent = map_ctx[parent]
	end

	inputctx.Priority = ctx.priority or 1000
	inputctx.Sink = ctx.sink or false

	for key, value in ctx do
		if key == "priority" or key == "sink" then
			continue
		end
		if (getmetatable :: any)(value) ~= input_action_metatable then
			reconcile_context(key, value :: Context, ctx)
		else
			reconcile_action(value :: ActionTypes, ctx)
		end
	end

	update_enabled(ctx)
end

--[=[
	@within input
	Increments the enable count of a context by `n` (default 1). The
	context's underlying `InputContext.Enabled` becomes true once the
	count is positive.

	@param v Context
	@param n number? -- Increment amount; defaults to 1.
]=]
function input.enable(v: Context, n: number?)
	local count = map_ctx_enabled[v]
	if count == nil then
		warn(`using unknown value for input context`)
		return
	end
	map_ctx_enabled[v] = count + (n or 1)
	update_enabled(v)
end

--[=[
	@within input
	Decrements the enable count of a context by `n` (default 1). The
	underlying `InputContext.Enabled` becomes false once the count drops
	to zero or below.

	@param v Context
	@param n number? -- Decrement amount; defaults to 1.
]=]
function input.disable(v: Context, n: number?)
	local count = map_ctx_enabled[v]
	if count == nil then
		warn(`using unknown value for input context`)
		return
	end
	map_ctx_enabled[v] = count - (n or 1)
	update_enabled(v)
end

--[=[
	@within input
	Reconciles a context (and any nested contexts/actions it contains)
	into actual `InputContext` instances. Returns the same table you
	passed in for chaining/storing.

	@param name string -- Name applied to the underlying `InputContext`.
	@param v Context
	@return Context
]=]
function input.context(name: string, v: Context): Context
	reconcile_context(name, v)
	return v
end

--[=[
	@within input
	@function action

	Reconciles an action descriptor into an `InputAction` instance and
	returns it augmented with the `ActionFunctions` API (`is_pressed`,
	`is_released`, `is_changed`, `get_state`, plus `pressed`, `released`,
	and `state_changed` signals).

	The return type is narrowed by the `type` field on the descriptor:
	`"bool"` → `ActionBool`, `"1d"` → `Action1D`, etc.

	@param v Action -- An action descriptor with a `type` discriminator.
	@return ActionTypes
]=]
input.action = function(v: any)
	reconcile_action(v, nil)

	setmetatable(v, input_action_metatable)
	return v :: any
end :: (
	& ((v: Action<"bool">) -> ActionBool)
	& ((v: Action<"1d">) -> Action1D)
	& ((v: Action<"2d">) -> Action2D)
	& ((v: Action<"3d">) -> Action3D)
	& ((v: Action<"viewport">) -> ActionViewport)
)

--[=[
	@within input
	Identity helper that returns its argument typed as a [Binding]. Useful
	for declaring bindings inline with type inference.

	@param v Binding
	@return Binding
]=]
function input.binding(v: Binding): Binding
	return v
end

--[=[
	@within input
	Clears the per-frame transient state (`is_pressed`, `is_released`,
	`is_changed` flags) for every action. Call this once per frame before
	polling so each press/release/state-change is observed exactly once.
]=]
function input.clear_state()
	table.clear(pressed)
	table.clear(released)
	table.clear(state_changed)
end

local modifier_keys = {
	Enum.KeyCode.LeftControl,
	Enum.KeyCode.RightControl,
	Enum.KeyCode.LeftAlt,
	Enum.KeyCode.RightAlt,
	Enum.KeyCode.LeftMeta,
	Enum.KeyCode.RightMeta,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift,
}

local map_input_type = {
	[Enum.UserInputType.MouseButton1] = Enum.KeyCode.MouseLeftButton,
	[Enum.UserInputType.MouseButton2] = Enum.KeyCode.MouseRightButton,
	[Enum.UserInputType.MouseButton3] = Enum.KeyCode.MouseMiddleButton,
	[Enum.UserInputType.Touch] = Enum.KeyCode.Touch,
}

--[=[
	@within input
	@yields

	Yields until the user produces input, then returns a table containing
	the primary `KeyCode` along with up to two modifier keys held during
	the press. Mouse buttons and touch are translated to their `KeyCode`
	equivalents.

	@return { bind: Enum.KeyCode, modifier1: Enum.KeyCode, modifier2: Enum.KeyCode }
]=]
function input.capture_input(): { bind: Enum.KeyCode, modifier1: Enum.KeyCode, modifier2: Enum.KeyCode }
	local captured: { InputObject } = {}

	local connection1 = UserInputService.InputBegan:Connect(function(inputObject)
		table.insert(captured, inputObject)
	end)

	local captured_end = UserInputService.InputEnded:Wait()
	connection1:Disconnect()

	local last_keycode = captured_end.KeyCode
	local modifiers = {}

	if last_keycode == Enum.KeyCode.Unknown then
		last_keycode = map_input_type[captured_end.UserInputType]
	end

	for _, key: InputObject in captured do
		if table.find(modifier_keys, key.KeyCode) then
			table.insert(modifiers, key.KeyCode)
		end
	end

	local modifier2: Enum.KeyCode = (table.remove(modifiers) :: Enum.KeyCode?) or Enum.KeyCode.Unknown
	local modifier1: Enum.KeyCode = table.remove(modifiers) or modifier2 or Enum.KeyCode.Unknown

	if modifier2 == modifier1 then
		modifier2 = Enum.KeyCode.Unknown
	end

	return { bind = last_keycode, modifier1 = modifier1, modifier2 = modifier2 }
end

return input
