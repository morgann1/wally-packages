--!strict
-- Originally (c) Daniel P H Fox.

export type Some<Value> = { some: true, value: Value }
export type None<Reason = string> = { some: false, reason: Reason }
export type Maybe<Value, Reason = string> = Some<Value> | None<Reason>

local Maybe = {}

function Maybe.some<Value>(value: Value): Some<Value>
	return { some = true, value = value }
end

function Maybe.none<Reason>(reason: Reason): None<Reason>
	return { some = false, reason = reason }
end

return Maybe
