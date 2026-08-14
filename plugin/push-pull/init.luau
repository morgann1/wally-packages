--!strict
-- Originally (c) Daniel P H Fox.

local Maybe = require(script.Parent.Maybe)

type Pack = { [number]: unknown, n: number }

--[=[
	@class PushPull

	Single-consumer producer/consumer queues, returned as a `push`/`pull`
	function pair. Two flavours: `yield` blocks the puller until a value
	arrives, `maybe` returns immediately with a [Maybe].
]=]
local PushPull = {}

--[=[
	@within PushPull

	Creates a queue whose `pull` yields the calling coroutine until a value
	is pushed. Values are delivered first-in first-out and each is consumed
	once. Useful as a wake-up channel inside long-running loops.

	@return (Values...) -> () -- push: enqueues a value and wakes a waiting puller.
	@return () -> Values... -- pull: dequeues the next value, yielding while the queue is empty.
]=]
function PushPull.yield<Values...>(): ((Values...) -> (), () -> Values...)
	local waiting: { [thread]: true } = {}
	local buffer: { Pack } = {}
	local function push(...)
		table.insert(buffer, table.pack(...))
		local thread = next(waiting)
		if thread ~= nil then
			waiting[thread] = nil
			task.spawn(thread)
		end
	end
	local function pull()
		while #buffer == 0 do
			waiting[coroutine.running()] = true
			coroutine.yield()
		end
		local values = table.remove(buffer, 1) :: Pack
		return table.unpack(values, 1, values.n)
	end
	return push, pull :: any
end

--[=[
	@within PushPull

	Creates a non-blocking queue: `pull` returns `Maybe.some(value)` when a
	value is buffered and `Maybe.none` when the queue is empty, never
	yielding.

	@return (Value) -> () -- push: enqueues a value.
	@return () -> Maybe<Value> -- pull: dequeues the next value, or a `None` when empty.
]=]
function PushPull.maybe<Value>(): ((Value) -> (), () -> Maybe.Maybe<Value>)
	local buffer: { Value } = {}
	local function push(v)
		table.insert(buffer, v)
	end
	local function pull(): Maybe.Maybe<Value>
		if #buffer == 0 then
			return Maybe.none("No value pushed")
		else
			return Maybe.some(table.remove(buffer, 1) :: Value)
		end
	end
	return push, pull :: any
end

return PushPull
