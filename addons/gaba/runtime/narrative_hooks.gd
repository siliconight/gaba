class_name NarrativeHooks
extends RefCounted

## Designer-facing facade over the dialogue registries.
##
## Gameplay code that needs to wire `if:` conditions and `do:` effects to
## actual game systems registers them through this class. It's a thin alias
## over [code]DialogueManager.conditions[/code] and [code]DialogueManager.effects[/code] —
## both work, both are supported — but [code]NarrativeHooks[/code] reads less like
## plumbing and more like what it actually is: the bridge between the writer's
## narrative and your game's mechanics.
##
## # Example
##
## In an autoload your game ships:
##
## [codeblock]
## extends Node
##
## func _ready() -> void:
##     NarrativeHooks.register_condition("quest_state", _quest_state)
##     NarrativeHooks.register_condition("has_item", _has_item)
##     NarrativeHooks.register_condition("faction_at_least", _faction_at_least)
##
##     NarrativeHooks.register_effect("start_quest", _start_quest)
##     NarrativeHooks.register_effect("complete_quest", _complete_quest)
##     NarrativeHooks.register_effect("give_item", _give_item)
##     NarrativeHooks.register_effect("open_shop", _open_shop)
##
## # ...handlers below...
## [/codeblock]
##
## Or bulk-register from a dictionary:
##
## [codeblock]
## NarrativeHooks.register_conditions({
##     "quest_state": _quest_state,
##     "has_item": _has_item,
## })
## NarrativeHooks.register_effects({
##     "start_quest": _start_quest,
##     "give_item": _give_item,
## })
## [/codeblock]
##
## Handler signatures match the registry contract:
##
## [codeblock]
## func _quest_state(args: Array, context: Dictionary) -> bool:
##     # args[0] = quest id, args[1] = expected state
##     return Quests.state_of(args[0]) == args[1]
##
## func _start_quest(args: Array, context: Dictionary) -> void:
##     Quests.start(args[0])
## [/codeblock]


## Register a single condition handler. Use inside a `do:` or `if:` clause:
## [code]if: quest_state iron_debt active[/code] → calls the handler registered
## under "quest_state" with [code]args = ["iron_debt", "active"][/code].
static func register_condition(kind: String, handler: Callable) -> void:
	if not _registries_ready():
		push_warning("[NarrativeHooks] DialogueManager not ready yet. Are you calling this before _ready()?")
		return
	DialogueManager.conditions.register(kind, handler)


## Register a single effect handler. Use inside a `do:` clause:
## [code]do: start_quest iron_debt[/code] → calls the handler registered under
## "start_quest" with [code]args = ["iron_debt"][/code].
static func register_effect(kind: String, handler: Callable) -> void:
	if not _registries_ready():
		push_warning("[NarrativeHooks] DialogueManager not ready yet. Are you calling this before _ready()?")
		return
	DialogueManager.effects.register(kind, handler)


## Bulk-register condition handlers from a dictionary of [code]name -> Callable[/code].
static func register_conditions(handlers: Dictionary) -> void:
	for kind in handlers.keys():
		register_condition(kind, handlers[kind])


## Bulk-register effect handlers from a dictionary of [code]name -> Callable[/code].
static func register_effects(handlers: Dictionary) -> void:
	for kind in handlers.keys():
		register_effect(kind, handlers[kind])


## Unregister a previously-registered condition. Safe to call on names that
## aren't registered — no-op.
static func unregister_condition(kind: String) -> void:
	if _registries_ready() and DialogueManager.conditions.has_method("unregister"):
		DialogueManager.conditions.unregister(kind)


## Unregister a previously-registered effect.
static func unregister_effect(kind: String) -> void:
	if _registries_ready() and DialogueManager.effects.has_method("unregister"):
		DialogueManager.effects.unregister(kind)


# Defensive — autoload order is usually deterministic but guard anyway so
# typos in user code surface as warnings, not crashes.
static func _registries_ready() -> bool:
	return DialogueManager != null \
		and DialogueManager.conditions != null \
		and DialogueManager.effects != null
