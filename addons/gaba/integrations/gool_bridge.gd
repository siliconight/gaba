extends Node

## Optional bridge between Gaba's DialogueManager and the gool audio engine.
##
## When enabled (see "Activating" below), this autoload:
##   - Plays voice-over for any DialogueNodeResource with a non-empty
##     voiceover_event_id, by routing through gool's create_emitter /
##     destroy_emitter API.
##   - Implements the four playback_behavior modes documented in
##     docs/AUTHORING.md: interruptible, non_interruptible, skippable, auto_advance.
##   - Asserts the gool contract at every call site (Gool.has_sound() before
##     create_emitter, etc.) so typos surface as warnings, not silent NPCs.
##
## Ships with Gaba but is NOT auto-registered — add it as an autoload yourself
## (see below). This keeps it opt-in and lets you skip it if you write your own
## audio routing.
##
## # Activating
##
## 1. Install both `gaba` and `gool` addons in your project.
## 2. In Project Settings → Autoload, add this file
##    (`res://addons/gaba/integrations/gool_bridge.gd`) as an autoload with
##    name `GabaGoolBridge`. Load order: AFTER both `DialogueManager` (added
##    by Gaba) and `Gool` (added by gool).
## 3. From gameplay code, just start dialogues normally and include the NPC's
##    world position in the context so VO can be spatialised:
##    [codeblock]
##    var session := DialogueManager.start_dialogue(
##        dlg, {"npc_position": npc.global_position})
##    session.start()
##    [/codeblock]
##
## # UI contract for non_interruptible
##
## For `non_interruptible` nodes the bridge cannot stop your UI from honouring
## a choice click on its own — your dialogue UI must check
## [method is_input_blocked] before passing input through to
## [method DialogueSession.select_choice]. Connect to the [signal vo_started]
## and [signal vo_finished] signals to update button enabled state.
##
## # UI contract for skippable
##
## For `skippable` nodes, your skip handler (e.g. spacebar pressed) calls
## [method skip_current_vo]. The bridge cuts the VO and fires
## [signal vo_finished], the same as if it had ended naturally.
##
## # Graceful degradation
##
## If gool's autoload (`/root/Gool`) isn't found at runtime, the bridge logs
## one warning and goes inert. Dialogue still plays text-only — every other
## Gaba feature works.

## Fires when a node's voice-over actually starts playing. Use to update UI
## (e.g. disable the choice buttons until [signal vo_finished] for
## non_interruptible nodes).
signal vo_started(session, node)

## Fires when a node's voice-over ends, either by natural completion, by
## [method skip_current_vo], or by being interrupted by a new node.
signal vo_finished(session, node)


# --- Tunables ---

## Fallback duration when neither subtitle_timing_data.duration_ms nor gool
## provide one. Used only when the bridge can't determine real length.
@export var default_vo_duration_ms: float = 3000.0

## Fade-out applied when a new node interrupts the previous node's VO.
@export var default_fade_out_ms: float = 50.0

## Fade-out applied when the session ends (terminal node, or end_dialogue()).
@export var session_end_fade_out_ms: float = 100.0

## When true, the bridge prints one activation line at _ready() and one
## warning per contract violation. Off for shipping if you've got log noise.
@export var enable_logging: bool = true


# --- playback_behavior string constants ---
# Match the values documented in docs/AUTHORING.md and the default on
# DialogueNodeResource.playback_behavior.

const PB_INTERRUPTIBLE := "interruptible"
const PB_NON_INTERRUPTIBLE := "non_interruptible"
const PB_SKIPPABLE := "skippable"
const PB_AUTO_ADVANCE := "auto_advance"


# --- Internal state ---

var _gool: Node = null
var _gool_has_finished_signal: bool = false
var _enabled: bool = false

# session -> {emitter:int, node:DialogueNodeResource, behavior:String, finished:bool}
var _states: Dictionary = {}

# gool emitter handle -> session  (for routing emitter_finished back to the right session)
var _handle_to_session: Dictionary = {}


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		return  # don't activate while editing scenes

	_gool = get_tree().root.get_node_or_null("Gool")
	if _gool == null:
		push_warning("[GabaGoolBridge] /root/Gool not found — bridge inert. Install gool and enable its plugin to activate VO routing.")
		return

	var manager: Node = get_tree().root.get_node_or_null("DialogueManager")
	if manager == null:
		push_warning("[GabaGoolBridge] /root/DialogueManager not found — bridge inert. Is the Gaba plugin enabled?")
		return

	# Prefer a signal-driven VO-end notification if gool exposes one.
	# Falls back to a Timer scheduled per node otherwise.
	if _gool.has_signal("emitter_finished"):
		_gool.connect("emitter_finished", _on_gool_emitter_finished)
		_gool_has_finished_signal = true

	manager.dialogue_started.connect(_on_dialogue_started)
	_enabled = true

	if enable_logging:
		var detection := "gool.emitter_finished signal" if _gool_has_finished_signal else "Timer fallback"
		print("[GabaGoolBridge] Active. VO completion detection: %s." % detection)


# ---------------------------------------------------------------------------
# Session lifecycle
# ---------------------------------------------------------------------------

func _on_dialogue_started(session) -> void:
	if _states.has(session):
		return  # defensive: already tracking
	_states[session] = {
		"emitter": -1,
		"node": null,
		"behavior": PB_INTERRUPTIBLE,
		"finished": true,
	}
	session.node_entered.connect(_on_node_entered.bind(session))
	session.session_ended.connect(_on_session_ended.bind(session))


func _on_node_entered(node, session) -> void:
	# Stop any VO left over from the previous node first.
	_stop_vo(session, default_fade_out_ms)

	if not node.has_voiceover():
		return

	var sound_name: String = node.voiceover_event_id
	if sound_name.is_empty():
		if not node.voiceover_audio_path.is_empty() and enable_logging:
			push_warning("[GabaGoolBridge] node '%s' has voiceover_audio_path but no voiceover_event_id; only event-id playback is supported by this bridge. Register the file with gool's sound bank and reference it by name." % node.node_id)
		return

	# Cross-script contract: assert gool knows the sound BEFORE asking for an
	# emitter. Per the v0.66.0 introspection API, has_sound() is the right
	# defensive call here.
	if _gool.has_method("has_sound") and not _gool.has_sound(sound_name):
		push_warning("[GabaGoolBridge] gool has no sound '%s' — skipping VO on node '%s'. Check your sound bank." % [sound_name, node.node_id])
		return

	if not _gool.has_method("create_emitter"):
		push_warning("[GabaGoolBridge] gool autoload is missing create_emitter() — cannot play VO. Bridge expected v0.66.0+ API surface.")
		return

	var npc_pos: Vector3 = session.context.get("npc_position", Vector3.ZERO)
	var handle = _gool.create_emitter(sound_name, npc_pos)
	if typeof(handle) != TYPE_INT or handle < 0:
		push_warning("[GabaGoolBridge] gool.create_emitter returned invalid handle for '%s' (got %s)" % [sound_name, str(handle)])
		return

	var state: Dictionary = _states[session]
	state.emitter = handle
	state.node = node
	state.behavior = node.playback_behavior
	state.finished = false
	_handle_to_session[handle] = session

	vo_started.emit(session, node)

	# If gool doesn't notify us when the emitter ends, schedule a fallback.
	if not _gool_has_finished_signal:
		_schedule_finish_timer(session, node, handle)


func _on_session_ended(session) -> void:
	_stop_vo(session, session_end_fade_out_ms)
	_states.erase(session)


# ---------------------------------------------------------------------------
# VO end detection
# ---------------------------------------------------------------------------

func _on_gool_emitter_finished(handle) -> void:
	if not _handle_to_session.has(handle):
		return  # not one of ours, or already cleaned up
	var session = _handle_to_session[handle]
	_handle_to_session.erase(handle)
	_mark_vo_finished(session, handle)


func _schedule_finish_timer(session, node, handle: int) -> void:
	var duration_ms := _resolve_vo_duration_ms(node)
	var timer := get_tree().create_timer(duration_ms / 1000.0)
	# Bind both handle and session so the callback can validate this is still
	# the active VO when it fires.
	timer.timeout.connect(_on_finish_timer.bind(session, handle))


func _on_finish_timer(session, handle: int) -> void:
	if not _states.has(session):
		return
	var state: Dictionary = _states[session]
	if state.emitter != handle or state.finished:
		return  # already advanced past this VO or it was stopped early
	_handle_to_session.erase(handle)
	_mark_vo_finished(session, handle)


func _resolve_vo_duration_ms(node) -> float:
	# Best source: explicit duration in subtitle_timing_data.
	if node.subtitle_timing_data.has("duration_ms"):
		return float(node.subtitle_timing_data["duration_ms"])
	# Next best: ask gool. Speculative API — only used if gool exposes it.
	if _gool.has_method("get_sound_duration_ms"):
		var d = _gool.get_sound_duration_ms(node.voiceover_event_id)
		if (typeof(d) == TYPE_INT or typeof(d) == TYPE_FLOAT) and float(d) > 0.0:
			return float(d)
	# Fallback.
	return default_vo_duration_ms


func _mark_vo_finished(session, handle: int) -> void:
	if not _states.has(session):
		return
	var state: Dictionary = _states[session]
	if state.emitter != handle or state.finished:
		return
	state.finished = true
	var node = state.node
	vo_finished.emit(session, node)

	# auto_advance: pick the first available choice when VO ends.
	# (If there are no choices, the node is terminal and the session has
	# already ended itself — nothing to do.)
	if state.behavior == PB_AUTO_ADVANCE and not session.is_ended():
		var choices = session.get_available_choices()
		if not choices.is_empty():
			session.select_choice(0)


# ---------------------------------------------------------------------------
# Stop helper
# ---------------------------------------------------------------------------

func _stop_vo(session, fade_out_ms: float) -> void:
	if not _states.has(session):
		return
	var state: Dictionary = _states[session]
	if state.emitter == -1:
		return

	# Sanity: flag contract violations. The game's UI should be checking
	# is_input_blocked() before letting the player advance through a
	# non_interruptible line.
	if state.behavior == PB_NON_INTERRUPTIBLE and not state.finished and enable_logging:
		push_warning("[GabaGoolBridge] Stopping non_interruptible VO on node '%s' before it finished. Your UI should check is_input_blocked() before advancing." % state.node.node_id)

	var handle: int = state.emitter
	_handle_to_session.erase(handle)
	if _gool != null and _gool.has_method("destroy_emitter"):
		_gool.destroy_emitter(handle, fade_out_ms)
	state.emitter = -1
	state.node = null
	state.finished = true


# ---------------------------------------------------------------------------
# Public API for game UI
# ---------------------------------------------------------------------------

## True if a non_interruptible VO is still playing for [param session]. UI code
## should consult this before honouring choice input.
func is_input_blocked(session) -> bool:
	if not _enabled or not _states.has(session):
		return false
	var state: Dictionary = _states[session]
	if state.emitter == -1 or state.finished:
		return false
	return state.behavior == PB_NON_INTERRUPTIBLE


## Skip the current VO on [param session]. Only effective if the current
## node's playback_behavior is "skippable". Returns true if a skip actually
## happened, false otherwise (no VO playing, or behavior is not skippable).
func skip_current_vo(session) -> bool:
	if not _enabled or not _states.has(session):
		return false
	var state: Dictionary = _states[session]
	if state.emitter == -1 or state.finished:
		return false
	if state.behavior != PB_SKIPPABLE:
		if enable_logging:
			push_warning("[GabaGoolBridge] skip_current_vo: node '%s' has playback_behavior='%s' (not 'skippable'); ignoring." % [state.node.node_id, state.behavior])
		return false
	var node = state.node
	_stop_vo(session, default_fade_out_ms)
	vo_finished.emit(session, node)
	return true


## True if the bridge is wired up to both gool and the DialogueManager. False
## if either was missing at _ready() time.
func is_active() -> bool:
	return _enabled
