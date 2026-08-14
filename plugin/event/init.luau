--!strict
-- Originally (c) Daniel P H Fox.

--[=[
	@class Event

	A minimal signal, split into its two capabilities so producers and
	consumers can be handed different halves:

	```lua
	local onThing, fireThing = Event()
	local disconnect = onThing(function(value)
		print("got", value)
	end)
	fireThing(123)
	disconnect()
	```
]=]

--[=[
	@within Event
	@type Connect<Args...> (callback: (Args...) -> ()) -> () -> ()

	Registers a listener and returns a function that disconnects it.
]=]
export type Connect<Args...> = (callback: (Args...) -> ()) -> () -> ()

--[=[
	@within Event
	@function Event

	Creates an event and returns its `connect` and `fire` halves. Listeners
	run on their own threads via `task.spawn`, so a yielding or erroring
	listener never blocks the firer or the other listeners.

	@return Connect<Args...> -- Registers a listener; returns its disconnect.
	@return (Args...) -> () -- Fires the event to every current listener.
]=]
local function Event<Args...>(): (Connect<Args...>, (Args...) -> ())
	local listeners: { [{}]: (Args...) -> () } = {}
	local function connect(callback: (Args...) -> ()): () -> ()
		local id = {}
		listeners[id] = callback
		return function(): ()
			listeners[id] = nil
		end
	end
	local function fire(...: Args...): ()
		for _, listener in listeners do
			task.spawn(listener, ...)
		end
	end
	return connect, fire
end

return Event
