@tool
extends Node

## Autoload singleton that owns the global condition/effect registries and
## starts/tracks dialogue sessions. Registered as `DialogueManager` by plugin.gd.
##
## Typical use:
##   var session = DialogueManager.start_dialogue(load("res://dialogues/blacksmith.tres"))
##   session.node_entered.connect(_on_node_entered)
##   session.start()
##
## The manager is intentionally thin: it doesn't drive UI, doesn't know about
## NPCs, doesn't talk to the network. Those are game-side concerns that hook
## into the session's signals.

signal dialogue_started(session: DialogueSession)
signal dialogue_ended(session: DialogueSession)

## Game-defined condition handlers. Register handlers during game startup.
var conditions := GabaConditionRegistry.new()

## Game-defined effect handlers. Register handlers during game startup.
var effects := GabaEffectRegistry.new()

## All currently active sessions. Multiple are allowed so multiplayer servers
## can drive one per connected player simultaneously.
var _active_sessions: Array[DialogueSession] = []


## Creates a session for [param dialogue] but does not call start() on it —
## callers should connect signals first, then call session.start().
##
## [param context] is passed to all condition/effect handlers; put game-state
## handles here (player ref, world ref, etc.).
##
## [param authoritative] should be false on clients in multiplayer; true on
## single-player and on the server. See docs/MULTIPLAYER.md.
func start_dialogue(
	dialogue: DialogueResource,
	context: Dictionary = {},
	authoritative: bool = true,
) -> DialogueSession:
	assert(dialogue != null, "DialogueManager.start_dialogue: dialogue is null")
	var session := DialogueSession.new(dialogue, conditions, effects, context, authoritative)
	session.session_ended.connect(_on_session_ended.bind(session))
	_active_sessions.append(session)
	dialogue_started.emit(session)
	return session


## Ends [param session] and removes it from the active list. Safe to call on
## already-ended sessions.
func end_dialogue(session: DialogueSession) -> void:
	if session == null:
		return
	session.end()


## All currently active (not ended) sessions.
func get_active_sessions() -> Array[DialogueSession]:
	return _active_sessions.duplicate()


func _on_session_ended(session: DialogueSession) -> void:
	_active_sessions.erase(session)
	dialogue_ended.emit(session)
