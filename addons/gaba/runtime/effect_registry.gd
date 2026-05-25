@tool
class_name GabaEffectRegistry
extends RefCounted

## Registry of effect handlers. Games register Callables here and Gaba calls
## them when applying [DialogueEffect]s at runtime.
##
## A handler has the signature:
##   func handler(args: PackedStringArray, context: Dictionary) -> void
##
## [b]Multiplayer:[/b] effect handlers should run on the server only. The
## DialogueSession in client-replica mode skips effect application; the
## authoritative session applies them and replicates results through whatever
## channel the game uses (RPCs, MultiplayerSynchronizer, etc.).

var _handlers: Dictionary = {}  # kind: String -> Callable


## Registers a handler for [param kind]. Replaces any existing handler.
func register(kind: String, handler: Callable) -> void:
	assert(not kind.is_empty(), "EffectRegistry: kind must be non-empty")
	assert(handler.is_valid(), "EffectRegistry: handler must be a valid Callable")
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


## Applies [param effect] with [param context]. If no handler is registered,
## logs a warning and does nothing.
func apply(effect: DialogueEffect, context: Dictionary = {}) -> void:
	if not _handlers.has(effect.kind):
		push_warning("[Gaba] No effect handler registered for '%s' (skipping)" % effect.kind)
		return
	var handler: Callable = _handlers[effect.kind]
	handler.call(effect.args, context)


## Applies a list of effects in order.
func apply_all(effects: Array[DialogueEffect], context: Dictionary = {}) -> void:
	for e in effects:
		apply(e, context)
