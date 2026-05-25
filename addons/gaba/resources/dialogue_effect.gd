@tool
class_name DialogueEffect
extends Resource

## A gameplay side-effect fired by the runtime via EffectRegistry.
##
## The addon does not implement quest/inventory/etc. logic — games register
## handlers with EffectRegistry and Gaba calls them. See docs/EXTENDING.md.

## The effect kind, e.g. "start_quest", "give_item", "set_flag", "open_shop".
@export var kind: String = ""

## Positional arguments parsed from source. Game handlers consume these.
## Example: `EFFECT: give_item iron_ore 3` → kind="give_item", args=["iron_ore", "3"].
@export var args: PackedStringArray = PackedStringArray()


func _to_string() -> String:
	return "%s(%s)" % [kind, ", ".join(args)]
