--!strict
-- Originally (c) Daniel P H Fox.

--[=[
	@class Maybe

	An optional value that carries a reason when absent. Check `.some` to
	narrow: `if result.some then use(result.value) else warn(result.reason)`.
	Preferred over `nil` returns when the caller should know *why* there was
	no value.
]=]

--[=[
	@within Maybe
	@type Some { some: true, value: Value }
]=]
export type Some<Value> = { some: true, value: Value }

--[=[
	@within Maybe
	@type None { some: false, reason: Reason }
]=]
export type None<Reason = string> = { some: false, reason: Reason }

--[=[
	@within Maybe
	@type Maybe Some<Value> | None<Reason>
]=]
export type Maybe<Value, Reason = string> = Some<Value> | None<Reason>

local Maybe = {}

--[=[
	@within Maybe

	Wraps a present value.

	@param value Value
	@return Some<Value>
]=]
function Maybe.some<Value>(value: Value): Some<Value>
	return { some = true, value = value }
end

--[=[
	@within Maybe

	Marks a value as absent, with the reason why.

	@param reason Reason -- Usually a human-readable string.
	@return None<Reason>
]=]
function Maybe.none<Reason>(reason: Reason): None<Reason>
	return { some = false, reason = reason }
end

return Maybe
