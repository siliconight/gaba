@tool
class_name DialogueNodeResource
extends Resource

## A single beat of dialogue: one NPC line, optional choices, optional VO data.
##
## When [member choices] is empty, this is a terminal node — selecting it ends the session.
## The node ends the session if [member is_end] is true OR if it has no choices.

## Unique within the owning [DialogueResource].
@export var node_id: String = ""

## Display name of the speaker. Defaults to the dialogue's npc_id at parse time
## but can be overridden per-node (e.g. for nested speakers in cutscenes).
@export var speaker: String = ""

## The line of dialogue text. May be a raw string or a localization key —
## the runtime treats it opaquely; consumers decide how to resolve it.
@export var text: String = ""

## Optional explicit localization key. If set, prefer this over [member text]
## when resolving translations.
@export var localization_key: String = ""

## Player choices available at this node. Empty array = terminal.
@export var choices: Array[DialogueChoiceResource] = []

## Conditions evaluated when reaching this node. If any fail, the runtime
## may skip the node (behavior depends on game integration).
@export var conditions: Array[DialogueCondition] = []

## Effects fired when this node becomes the current node.
@export var effects: Array[DialogueEffect] = []

## Explicit terminal marker. Set by the `END` keyword in source.
## A node is also implicitly terminal if it has zero choices.
@export var is_end: bool = false

# --- Voice-over (all optional; text-only dialogue is fully supported) ---

## ID of a voice-over event in the game's audio system (e.g. an FMOD/Wwise event,
## or a gool sound name). Empty = no VO.
@export var voiceover_event_id: String = ""

## Direct path to a VO audio file. Used when not routing through an event system.
## Mutually compatible with voiceover_event_id; the runtime decides which to use.
@export var voiceover_audio_path: String = ""

## Localization key for subtitles. May differ from [member localization_key]
## when subtitles are authored separately from the display text.
@export var subtitle_text_key: String = ""

## Optional timing data for subtitle reveal (e.g. word-level timestamps).
## Schema is game-specific; left as a generic Dictionary.
@export var subtitle_timing_data: Dictionary = {}

## Free-form speaker metadata (portrait, color, mood, etc.) for UI consumption.
@export var speaker_metadata: Dictionary = {}

## Playback behavior hint for the runtime/UI.
## Expected values: "interruptible", "non_interruptible", "skippable", "auto_advance".
## Left as a string so games can add their own modes without changing the addon.
@export var playback_behavior: String = "interruptible"


## True if this node should terminate the dialogue session when it becomes current.
func is_terminal() -> bool:
	return is_end or choices.is_empty()


## True if this node has any associated voice-over data.
func has_voiceover() -> bool:
	return not voiceover_event_id.is_empty() or not voiceover_audio_path.is_empty()
