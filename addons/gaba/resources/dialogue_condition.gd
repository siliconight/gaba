@tool
class_name DialogueCondition
extends Resource

## A gameplay precondition evaluated by the runtime via ConditionRegistry.
##
## The addon does not know about quests, inventory, factions, etc. — games register
## handlers with ConditionRegistry and Gaba calls them. See docs/EXTENDING.md.

## The condition kind, e.g. "quest_state", "has_item", "faction_at_least", "flag".
## Game code registers handlers keyed by this string.
@export var kind: String = ""

## Positional arguments parsed from source. Game handlers consume these.
## Example: `CONDITION: has_item iron_ore 3` → kind="has_item", args=["iron_ore", "3"].
@export var args: PackedStringArray = PackedStringArray()

## If true, the condition's result is inverted before being returned.
## Set by a leading `!` in source: `CONDITION: !has_item iron_ore`.
@export var negated: bool = false


func _to_string() -> String:
	var prefix := "!" if negated else ""
	return "%s%s(%s)" % [prefix, kind, ", ".join(args)]
