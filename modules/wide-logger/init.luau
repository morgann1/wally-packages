--!strict
--[=[
	@class WideLogger

	A logger built around "wide events" (https://loggingsucks.com/): one
	structured event per operation, enriched with context as the operation
	runs, emitted exactly once when the span finishes.

	Instead of scattering `print` calls across a code path, you open a span
	at the start of an operation, attach high-cardinality context fields
	(user ids, request ids, business state) along the way, and let the
	logger emit a single readable record at the end.

	```lua
	local Log = require(path.to.WideLogger)

	Log.withSpan("checkout.process", { request_id = id }, function(span)
	    span:set("user_id", user.Id)
	    span:set("cart_total_cents", cart.totalCents)
	    -- ... do work; if this errors the span auto-fails ...
	    span:set("payment_provider", "stripe")
	end)
	```

	Output goes to `print` (ok) or `warn` (failed) and is formatted for
	Studio readability:

	```
	[checkout.process] OK 142.30ms
	  cart_total_cents = 4200
	  payment_provider = "stripe"
	  request_id = "abc"
	  user_id = 5
	```
]=]

export type Fields = { [string]: any }

type SpanFields = {
	_name: string,
	_started_at: number,
	_fields: Fields,
	_failed: boolean,
	_err: any,
	_finished: boolean,
}

export type Span = SpanFields & {
	set: (self: Span, key: string, value: any) -> Span,
	merge: (self: Span, fields: Fields) -> Span,
	fail: (self: Span, err: any) -> Span,
	finish: (self: Span) -> (),
}

local SpanMethods = {}
SpanMethods.__index = SpanMethods

--[=[
	@within WideLogger
	@method set
	Attach a single field to the span. Returns the span for chaining.
]=]
function SpanMethods.set(self: Span, key: string, value: any): Span
	if self._finished then
		return self
	end
	self._fields[key] = value
	return self
end

--[=[
	@within WideLogger
	@method merge
	Attach a table of fields to the span at once. Existing keys are
	overwritten. Returns the span for chaining.
]=]
function SpanMethods.merge(self: Span, fields: Fields): Span
	if self._finished then
		return self
	end
	for k, v in fields do
		self._fields[k] = v
	end
	return self
end

--[=[
	@within WideLogger
	@method fail
	Mark the span as failed and attach the given error. The span will be
	emitted via `warn` when finished. Returns the span for chaining.
]=]
function SpanMethods.fail(self: Span, err: any): Span
	if self._finished then
		return self
	end
	self._failed = true
	self._err = err
	return self
end

local function formatValue(value: any, depth: number): string
	if depth > 3 then
		return "<...>"
	end

	local t = type(value)
	if t == "string" then
		return string.format("%q", value)
	elseif t == "number" or t == "boolean" or t == "nil" then
		return tostring(value)
	elseif t == "table" then
		local parts: { string } = {}
		local count = 0
		for k, v in value :: { [any]: any } do
			count += 1
			if count > 10 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, `{tostring(k)}={formatValue(v, depth + 1)}`)
		end
		return `\{{table.concat(parts, ", ")}}`
	else
		return `<{t}>`
	end
end

local function formatEvent(name: string, ok: boolean, durationMs: number, fields: Fields, err: any): string
	local status = if ok then "OK" else "ERR"
	local header = string.format("[%s] %s %.2fms", name, status, durationMs)

	-- Sort keys for stable output.
	local keys: { string } = {}
	for k in fields do
		table.insert(keys, k)
	end
	table.sort(keys)

	local lines: { string } = { header }
	if not ok then
		table.insert(lines, `  error = {formatValue(err, 0)}`)
	end
	for _, k in keys do
		table.insert(lines, `  {k} = {formatValue(fields[k], 0)}`)
	end
	return table.concat(lines, "\n")
end

--[=[
	@within WideLogger
	@method finish
	Emit the wide event. Subsequent calls are no-ops. After this, calls to
	`set`/`merge`/`fail` are also no-ops.
]=]
function SpanMethods.finish(self: Span)
	if self._finished then
		return
	end
	self._finished = true

	local durationMs = (os.clock() - self._started_at) * 1000
	local message = formatEvent(self._name, not self._failed, durationMs, self._fields, self._err)

	if self._failed then
		warn(message)
	else
		print(message)
	end
end

local WideLogger = {}

--[=[
	@within WideLogger
	@function span
	Open a new span. Set fields on it as the operation progresses, then
	call `:finish()` to emit the wide event.
]=]
function WideLogger.span(name: string, fields: Fields?): Span
	local self = (
		setmetatable({
			_name = name,
			_started_at = os.clock(),
			_fields = {} :: Fields,
			_failed = false,
			_err = nil,
			_finished = false,
		}, SpanMethods) :: any
	) :: Span

	if fields then
		self:merge(fields)
	end
	return self
end

--[=[
	@within WideLogger
	@function withSpan
	Open a span, run `fn(span)`, and finish the span automatically. If
	`fn` errors, the span is marked failed and the error is rethrown
	after the event is emitted. Returns whatever `fn` returned on success.
]=]
function WideLogger.withSpan<T>(name: string, fields: Fields?, fn: (Span) -> T): T
	local span = WideLogger.span(name, fields)

	local ok, result = xpcall(function()
		return fn(span)
	end, function(err)
		return debug.traceback(tostring(err), 2)
	end)

	if ok then
		span:finish()
		return result
	else
		span:fail(result)
		span:finish()
		error(result, 0)
	end
end

return WideLogger
