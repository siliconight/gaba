@tool
class_name GabaConditionRegistry
extends RefCounted

## Registry of condition handlers. Games register Callables here and Gaba calls
## them when evaluating [DialogueCondition]s at runtime.
##
## A handler has the signature:
##   func handler(args: PackedStringArray, context: Dictionary) -> bool
##
## [b]Determinism:[/b] handlers should be pure functions of game state. The runtime
## evaluates conditions repeatedly (e.g. to decide which choices to show, then again
## on server validation) and assumes the result is stable for the same state.

var _handlers: Dictionary = {}  # kind: String -> Callable


## Registers a handler for [param kind]. Replaces any existing handler.
func register(kind: String, handler: Callable) -> void:
	assert(not kind.is_empty(), "ConditionRegistry: kind must be non-empty")
	assert(handler.is_valid(), "ConditionRegistry: handler must be a valid Callable")
	_handlers[kind] = handler


## Removes the handler for [param kind], if any.
func unregister(kind: String) -> void:
	_handlers.erase(kind)


## True if [param kind] has a registered handler.
func has(kind: String) -> bool:
	return _handlers.has(kind)


## All registered kinds. Useful for editor tooling.
func get_kinds() -> PackedStringArray:
	var keys := PackedStringArray()
	for k in _handlers.keys():
		keys.append(k)
	return keys


## Evaluates [param condition] against [param context]. If no handler is registered
## for the condition's kind, returns false and logs a warning — this is conservative:
## a missing handler should not silently approve a gameplay gate.
func evaluate(condition: DialogueCondition, context: Dictionary = {}) -> bool:
	if not _handlers.has(condition.kind):
		push_warning("[Gaba] No condition handler registered for '%s' (returning false)" % condition.kind)
		return false
	var handler: Callable = _handlers[condition.kind]
	var result: bool = handler.call(condition.args, context)
	return not result if condition.negated else result


## Evaluates a list of conditions with AND semantics. Empty list returns true.
func evaluate_all(conditions: Array[DialogueCondition], context: Dictionary = {}) -> bool:
	for c in conditions:
		if not evaluate(c, context):
			return false
	return true
