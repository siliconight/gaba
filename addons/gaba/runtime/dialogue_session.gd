@tool
class_name DialogueSession
extends RefCounted

## State for one active dialogue conversation.
##
## A session is created by [DialogueManager.start_dialogue] and lives until
## [method end] is called or a terminal node is reached. Holds the current node,
## resolves available choices against conditions, and dispatches effects.
##
## [b]Authority model:[/b] sessions are either authoritative (server-side, applies
## effects, validates choices) or replica (client-side, displays only). See
## [member is_authoritative] and docs/MULTIPLAYER.md.

signal node_entered(node: DialogueNodeResource)
signal choice_selected(choice: DialogueChoiceResource, choice_index: int)
signal effect_triggered(effect: DialogueEffect)
signal session_ended()

## The dialogue being played.
var dialogue: DialogueResource

## Current node. Null before [method start] or after [method end].
var current_node: DialogueNodeResource

## Opaque context Dictionary passed to all condition/effect handlers. Games put
## the player reference, world state handle, etc. here.
var context: Dictionary = {}

## When true, this session applies effects and resolves conditions locally.
## When false (client replica), it only updates UI state and waits for the
## authoritative server to drive node transitions.
var is_authoritative: bool = true

## True after [method end] has been called or a terminal node reached.
var _ended: bool = false

# Cached registry references — handed in by DialogueManager at construction.
var _conditions: GabaConditionRegistry
var _effects: GabaEffectRegistry


func _init(
	p_dialogue: DialogueResource,
	p_conditions: GabaConditionRegistry,
	p_effects: GabaEffectRegistry,
	p_context: Dictionary = {},
	p_authoritative: bool = true,
) -> void:
	assert(p_dialogue != null, "DialogueSession: dialogue must not be null")
	assert(p_conditions != null, "DialogueSession: conditions registry required")
	assert(p_effects != null, "DialogueSession: effects registry required")
	dialogue = p_dialogue
	_conditions = p_conditions
	_effects = p_effects
	context = p_context
	is_authoritative = p_authoritative


## Begins the session at the dialogue's start node. Idempotent — calling twice
## without ending in between is a no-op (with a warning).
func start() -> void:
	if current_node != null:
		push_warning("[Gaba] DialogueSession.start() called on already-started session")
		return
	var start_node := dialogue.get_start_node()
	if start_node == null:
		push_error("[Gaba] Dialogue '%s' has no valid start node" % dialogue.dialogue_id)
		_ended = true
		session_ended.emit()
		return
	_enter_node(start_node)


## The choices visible to the player right now. Filters out choices whose
## conditions don't pass.
func get_available_choices() -> Array[DialogueChoiceResource]:
	var out: Array[DialogueChoiceResource] = []
	if current_node == null:
		return out
	for choice in current_node.choices:
		if _conditions.evaluate_all(choice.conditions, context):
			out.append(choice)
	return out


## Selects a choice by its index in [method get_available_choices]. This is the
## index the UI sees — not the raw index in [code]current_node.choices[/code] —
## which is important because filtered-out choices shift the indexing.
##
## On authoritative sessions: applies the choice's effects, transitions to the
## target node, and applies the target's effects. On replica sessions: emits
## the signal but does not transition (the server drives transitions).
func select_choice(visible_index: int) -> void:
	if _ended:
		push_warning("[Gaba] select_choice called on ended session")
		return
	if current_node == null:
		push_error("[Gaba] select_choice called before start()")
		return
	var available := get_available_choices()
	if visible_index < 0 or visible_index >= available.size():
		push_error("[Gaba] choice index %d out of range (0..%d)" % [visible_index, available.size() - 1])
		return
	var choice := available[visible_index]
	choice_selected.emit(choice, visible_index)

	if not is_authoritative:
		return  # server will drive the transition

	# Apply choice effects first so the target node's conditions see them.
	for effect in choice.effects:
		_effects.apply(effect, context)
		effect_triggered.emit(effect)

	if choice.is_terminal():
		end()
		return

	var next := dialogue.get_node_by_id(choice.target_node_id)
	if next == null:
		# Should have been caught by validation, but guard anyway.
		push_error("[Gaba] Choice target '%s' not found at runtime — was the dialogue revalidated?" % choice.target_node_id)
		end()
		return
	_enter_node(next)


## Server-side: validate that [param visible_index] is a legal selection given
## the current session state. Returns true if the client's request should be honored.
func validate_choice(visible_index: int) -> bool:
	if _ended or current_node == null:
		return false
	var available := get_available_choices()
	return visible_index >= 0 and visible_index < available.size()


## Server-side: jump the session to [param node_id]. Used to replicate transitions
## to client replicas. Bypasses choice evaluation and effect application.
func force_enter_node(node_id: String) -> void:
	var node := dialogue.get_node_by_id(node_id)
	if node == null:
		push_error("[Gaba] force_enter_node: '%s' does not exist" % node_id)
		return
	_enter_node(node, false)


## Terminates the session. Safe to call multiple times.
func end() -> void:
	if _ended:
		return
	_ended = true
	current_node = null
	session_ended.emit()


func is_ended() -> bool:
	return _ended


# --- Internal ---
func _enter_node(node: DialogueNodeResource, apply_effects: bool = true) -> void:
	current_node = node
	if is_authoritative and apply_effects:
		for effect in node.effects:
			_effects.apply(effect, context)
			effect_triggered.emit(effect)
	node_entered.emit(node)
	if node.is_terminal():
		end()
