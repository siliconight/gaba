@tool
class_name DialogueChoiceResource
extends Resource

## A player-selectable choice on a dialogue node.

## The text shown to the player. May be a raw string or a localization key.
@export var text: String = ""

## Optional explicit localization key. If set, prefer this over [member text].
@export var localization_key: String = ""

## node_id of the node this choice transitions to. May be empty for terminal
## choices (e.g. "[Leave]" that just closes the dialogue).
@export var target_node_id: String = ""

## Conditions that must pass for this choice to be available to the player.
## If any fail, the runtime hides or disables the choice (UI-dependent).
@export var conditions: Array[DialogueCondition] = []

## Effects fired when the player selects this choice. Run before the
## node transition so that target-node conditions see the post-effect state.
@export var effects: Array[DialogueEffect] = []


## True if this choice has no target — selecting it ends the dialogue.
func is_terminal() -> bool:
	return target_node_id.is_empty()
