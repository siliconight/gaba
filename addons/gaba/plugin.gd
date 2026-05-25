@tool
extends EditorPlugin

## Gaba editor plugin entry point.
##
## On enable: registers the .dlg importer and the DialogueManager autoload.
## On disable: cleans both up.

const AUTOLOAD_NAME := "DialogueManager"
const AUTOLOAD_PATH := "res://addons/gaba/runtime/dialogue_manager.gd"

var _importer: EditorImportPlugin


func _enter_tree() -> void:
	# Register the .dlg → Resource importer.
	_importer = preload("res://addons/gaba/importer/dialogue_importer.gd").new()
	add_import_plugin(_importer)

	# Register the runtime autoload.
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

	print("[Gaba] Plugin enabled. Drop .dlg files into your project to import them.")


func _exit_tree() -> void:
	if _importer != null:
		remove_import_plugin(_importer)
		_importer = null
	remove_autoload_singleton(AUTOLOAD_NAME)
	print("[Gaba] Plugin disabled.")
