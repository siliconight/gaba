@tool
class_name DialogueResource
extends Resource

## Top-level dialogue asset. Represents a complete conversation tree for one NPC.
##
## Produced by the importer from .dlg source files. Consumed by DialogueManager at runtime.
## All node lookups go through [method get_node_by_id]; do not index [member nodes] directly
## from gameplay code.

## Unique identifier for this dialogue. Typically matches the source file basename.
@export var dialogue_id: String = ""

## NPC this dialogue is authored for. Used by gameplay code to look up dialogues by NPC.
@export var npc_id: String = ""

## ID of the node where playback begins. Must exist in [member nodes].
@export var start_node_id: String = ""

## All nodes in this dialogue, keyed by node_id.
## Stored as a Dictionary[String, DialogueNodeResource] for O(1) lookup.
@export var nodes: Dictionary = {}

## Optional metadata for tooling. Not used at runtime.
@export var metadata: Dictionary = {}


## Returns the node with the given id, or null if not found.
func get_node_by_id(id: String) -> DialogueNodeResource:
	return nodes.get(id, null)


## Returns the starting node, or null if start_node_id is unset/invalid.
func get_start_node() -> DialogueNodeResource:
	if start_node_id.is_empty():
		return null
	return get_node_by_id(start_node_id)


## Returns all node IDs in this dialogue.
func get_node_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key in nodes.keys():
		ids.append(key)
	return ids


## True if [param id] exists in this dialogue.
func has_node(id: String) -> bool:
	return nodes.has(id)
