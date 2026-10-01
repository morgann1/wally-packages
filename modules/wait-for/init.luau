--!strict
local RunService = game:GetService("RunService")

local Promise = require(script.Parent.PromiseLuau)

local DEFAULT_TIMEOUT = 60

--[=[
	@class WaitFor
	Utility class for awaiting the existence of instances. Port of Sleitnick's
	[WaitFor](https://github.com/Sleitnick/RbxUtil/tree/main/modules/wait-for),
	typed on [promise-luau](https://github.com/morgann1/promise-luau).

	By default, all promises time out after 60 seconds, unless the `timeout`
	argument is specified. A timeout rejects with a `Promise.Error` of kind
	`TimedOut`.

	:::note
	Promises will be rejected if the parent (or any ancestor) is unparented
	from the game.
	:::

	:::caution Set name before parent
	When waiting for instances based on name (e.g. `WaitFor.Child`), the `WaitFor`
	system is listening to events to capture these instances being added. This
	means that the name must be set _before_ being parented into the object.
	:::
]=]
local WaitFor = {}

export type Error = "Unparented" | "ParentChanged"

--[=[
	@within WaitFor
	@prop Error {Unparented: string, ParentChanged: string}
	Rejection values for the instance lost cases. Timeouts reject with a
	`Promise.Error` instead.
]=]
WaitFor.Error = table.freeze({
	Unparented = "Unparented" :: "Unparented",
	ParentChanged = "ParentChanged" :: "ParentChanged",
})

-- Rejects with `WaitFor.Error.Unparented` if `instance` or any ancestor is unparented first.
local function watchAncestry<T...>(instance: Instance, promise: Promise.Promise<T...>): Promise.Promise<T...>
	local unparented = Promise.fromEvent(instance.AncestryChanged, function(_, newParent)
		return newParent == nil
	end):andThen(function()
		return Promise.reject(WaitFor.Error.Unparented)
	end)

	return Promise.race({ promise, unparented }) :: Promise.Promise<T...>
end

-- Resolves with the first child (or descendant, if `recursive`) of `parent` named `name`.
local function waitForNamed(
	parent: Instance,
	name: string,
	recursive: boolean,
	timeout: number?
): Promise.Promise<Instance>
	local found = parent:FindFirstChild(name, recursive)
	if found ~= nil then
		return Promise.resolve(found)
	end

	local added = if recursive then parent.DescendantAdded else parent.ChildAdded

	return watchAncestry(
		parent,
		Promise.fromEvent(added, function(instance)
			return instance.Name == name
		end):timeout(timeout or DEFAULT_TIMEOUT)
	)
end

-- Resolves with the first non-nil result of `get`, checked now and each time `signal` fires.
local function waitForValue<T>(signal: RBXScriptSignal, get: () -> T?, timeout: number?): Promise.Promise<T>
	local value = get()
	if value ~= nil then
		return Promise.resolve(value)
	end

	return Promise.fromEvent(signal, function()
		value = get()
		return value ~= nil
	end)
		:andThen(function()
			return value
		end)
		:timeout(timeout or DEFAULT_TIMEOUT) :: Promise.Promise<T>
end

--[=[
	@return Promise<Instance>
	Wait for a child to exist within a given parent based on the child name.

	```lua
	WaitFor.Child(parent, "SomeObject"):andThen(function(someObject)
		print(someObject, "now exists")
	end):catch(warn)
	```
]=]
function WaitFor.Child(parent: Instance, childName: string, timeout: number?): Promise.Promise<Instance>
	return waitForNamed(parent, childName, false, timeout)
end

--[=[
	@return Promise<{Instance}>
	Wait for all children to exist within the given parent.

	```lua
	WaitFor.Children(parent, {"SomeObject01", "SomeObject02"}):andThen(function(children)
		local someObject01, someObject02 = table.unpack(children)
	end)
	```

	:::note
	Once all children are found, a second check is made to ensure that all children
	are still directly parented to the given `parent` (since one child's parent
	might have changed before another child was found). A rejected promise with the
	`WaitFor.Error.ParentChanged` error will be thrown if any parents of the children
	no longer match the given `parent`.
	:::
]=]
function WaitFor.Children(parent: Instance, childrenNames: { string }, timeout: number?): Promise.Promise<{ Instance }>
	local all = table.create(#childrenNames)
	for i, childName in childrenNames do
		all[i] = WaitFor.Child(parent, childName, timeout)
	end

	return Promise.all(all):andThen(function(children: { Instance })
		for _, child in children do
			if child.Parent ~= parent then
				return Promise.reject(WaitFor.Error.ParentChanged)
			end
		end

		return children
	end) :: Promise.Promise<{ Instance }>
end

--[=[
	@return Promise<Instance>
	Wait for a descendant to exist within a given parent. This is similar to
	`WaitFor.Child`, except it looks for all descendants instead of immediate
	children.

	```lua
	WaitFor.Descendant(parent, "SomeDescendant"):andThen(function(someDescendant)
		print("SomeDescendant now exists")
	end)
	```
]=]
function WaitFor.Descendant(parent: Instance, descendantName: string, timeout: number?): Promise.Promise<Instance>
	return waitForNamed(parent, descendantName, true, timeout)
end

--[=[
	@return Promise<{Instance}>
	Wait for all descendants to exist within a given parent.

	```lua
	WaitFor.Descendants(parent, {"SomeDescendant01", "SomeDescendant02"}):andThen(function(descendants)
		local someDescendant01, someDescendant02 = table.unpack(descendants)
	end)
	```

	:::note
	Once all descendants are found, a second check is made to ensure that none of the
	instances have moved outside of the parent (since one instance might change before
	another instance is found). A rejected promise with the `WaitFor.Error.ParentChanged`
	error will be thrown if any of the instances are no longer descendants of the given
	`parent`.
	:::
]=]
function WaitFor.Descendants(
	parent: Instance,
	descendantNames: { string },
	timeout: number?
): Promise.Promise<{ Instance }>
	local all = table.create(#descendantNames)
	for i, descendantName in descendantNames do
		all[i] = WaitFor.Descendant(parent, descendantName, timeout)
	end

	return Promise.all(all):andThen(function(descendants: { Instance })
		for _, descendant in descendants do
			if not descendant:IsDescendantOf(parent) then
				return Promise.reject(WaitFor.Error.ParentChanged)
			end
		end

		return descendants
	end) :: Promise.Promise<{ Instance }>
end

--[=[
	@return Promise<BasePart>
	Wait for the PrimaryPart of a model to exist.

	```lua
	WaitFor.PrimaryPart(model):andThen(function(primaryPart)
		print(primaryPart == model.PrimaryPart)
	end)
	```
]=]
function WaitFor.PrimaryPart(model: Model, timeout: number?): Promise.Promise<BasePart>
	return watchAncestry(
		model,
		waitForValue(model:GetPropertyChangedSignal("PrimaryPart"), function()
			return model.PrimaryPart
		end, timeout)
	)
end

--[=[
	@return Promise<Instance>
	Wait for the Value of an ObjectValue to exist.

	```lua
	WaitFor.ObjectValue(someObjectValue):andThen(function(value)
		print("someObjectValue's value is", value)
	end)
	```
]=]
function WaitFor.ObjectValue(objectValue: ObjectValue, timeout: number?): Promise.Promise<Instance>
	return watchAncestry(
		objectValue,
		waitForValue(objectValue:GetPropertyChangedSignal("Value"), function()
			return objectValue.Value
		end, timeout)
	)
end

--[=[
	@return Promise<T>
	Wait for the given predicate function to return a non-nil value of
	type `T`. The predicate is fired every RunService Heartbeat step.

	```lua
	-- Example, waiting for some property to be set:
	WaitFor.Custom(function() return vectorForce.Attachment0 end):andThen(function(a0)
		print(a0)
	end)
	```
]=]
function WaitFor.Custom<T>(predicate: () -> T?, timeout: number?): Promise.Promise<T>
	return waitForValue(RunService.Heartbeat, predicate, timeout)
end

return WaitFor
