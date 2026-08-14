--!strict
-- Originally (c) Daniel P H Fox.

--[=[
	@class ty

	Runtime type definitions that mirror Luau types, built by chaining
	combinators off base defs:

	```lua
	local IconVariant = ty.Just("light"):Or(ty.Just("dark")):Or(ty.Just("mono"))
	local Icon = ty.Struct({ exhaustive = true }, {
		size = ty.Number,
		variants = IconVariant:MapOf(ty.String),
	})
	if Icon:Matches(value) then ... end
	local icon = Icon:CastOrError(value)
	```

	Every def answers `Matches` (boolean) and `Cast` (a [Maybe] carrying the
	converted value or a nested reason string). Combinators are available
	both as functions on `ty` and as methods on any def, where the def
	becomes the first argument.
]=]

--[=[
	@within ty
	@interface Def
	.ExpectsType string -- Human-readable name of the type, used in errors.
	.NotOfTypeError string -- Base error message for failed casts.
	.Matches (self: Def, x: unknown) -> boolean -- Whether `x` fits, without converting.
	.Cast (self: Def, x: unknown) -> Maybe<unknown> -- Converts `x`, or a `None` explaining the mismatch.
]=]

local Def = require(script.Def)
local Maybe = require(script.Parent.Maybe)
local Types = require(script.Types)

export type Def = Types.Def
export type Constants = Types.Constants
export type Methods = Types.Methods
export type Optional = Types.Optional
export type Or = Types.Or
export type And = Types.And
export type MapOf = Types.MapOf
export type Array = Types.Array
export type Struct = Types.Struct
export type IntoTagged = Types.IntoTagged

local methods: Types.Methods = {
	And = require(script.Functions.And),
	Array = require(script.Functions.Array),
	CastOrError = require(script.Functions.CastOrError),
	IgnoreInvalid = require(script.Functions.IgnoreInvalid),
	IntoDefault = require(script.Functions.IntoDefault),
	IntoNumber = require(script.Functions.IntoNumber),
	IntoString = require(script.Functions.IntoString),
	IntoTagged = require(script.Functions.IntoTagged),
	Just = require(script.Functions.Just),
	MapOf = require(script.Functions.MapOf),
	Nicknamed = require(script.Functions.Nicknamed),
	Optional = require(script.Functions.Optional),
	Or = require(script.Functions.Or),
	Predicate = require(script.Functions.Predicate),
	Retype = require(script.Functions.Retype),
	Struct = require(script.Functions.Struct),
	Tuple = require(script.Functions.Tuple),
	Typeof = require(script.Functions.Typeof),
	Untyped = require(script.Functions.Untyped),
}
Def.methodMeta.__index = methods

--[=[
	@within ty
	@prop Unknown Def

	Matches anything; casts pass values through unchanged. Its opposite is
	`ty.Never`, which matches nothing.
]=]
--[=[
	@within ty
	@prop Number Def

	`typeof`-based defs for the primitive types: `ty.Number`, `ty.Boolean`,
	`ty.String`, `ty.Thread`, `ty.Table` and `ty.Function`.
]=]
--[=[
	@within ty
	@prop True Def

	Literal defs for the three singleton values: `ty.True`, `ty.False` and
	`ty.Nil`.
]=]
local constants: Types.Constants = {
	Unknown = Def.new("unknown", function(self, x)
		return true
	end, function(self, x)
		return Maybe.some(x)
	end),
	Never = Def.new("never", function(self, x)
		return false
	end, function(self, x)
		return Maybe.none(self.NotOfTypeError)
	end),

	Number = methods.Typeof("number"),
	Boolean = methods.Typeof("boolean"),
	String = methods.Typeof("string"),
	Thread = methods.Typeof("thread"),
	Table = methods.Typeof("table"),
	Function = methods.Typeof("function"),

	True = methods.Just(true) :: any,
	False = methods.Just(false) :: any,
	Nil = methods.Just(nil),
}

local ty: Types.Methods & Types.Constants = setmetatable(constants, Def.methodMeta) :: any
return ty
