@tool
extends EditorPlugin

## Gaba editor plugin entry point.
##
## On enable: registers the .dlg importer and the DialogueManager autoload.
## On disable: cleans both up.

const AUTOLOAD_NAME := "DialogueManager"
const AUTOLOAD_PATH := "res://addons/gaba/runtime/dialogue_manager.gd"
const WIZARD_DOCK_SCRIPT := preload("res://addons/gaba/editor/dialogue_wizard_dock.gd")
const PREVIEW_DOCK_SCRIPT := preload("res://addons/gaba/editor/dialogue_preview_dock.gd")

var _importer: EditorImportPlugin
var _wizard_dock: Control
var _preview_dock: Control


func _enter_tree() -> void:
	# Register the .dlg → Resource importer.
	_importer = preload("res://addons/gaba/importer/dialogue_importer.gd").new()
	add_import_plugin(_importer)

	# Register the runtime autoload.
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

	# Add the "Create NPC Dialogue" wizard dock. Right-bottom-left slot is
	# usually uncrowded; users can drag it elsewhere via the editor's dock UI.
	_wizard_dock = WIZARD_DOCK_SCRIPT.new()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, _wizard_dock)

	# Add the conversation preview dock next to it. Godot auto-tabs controls
	# in the same dock slot, so the user sees "Gaba" and "Gaba Play" tabs.
	_preview_dock = PREVIEW_DOCK_SCRIPT.new()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, _preview_dock)

	print("[Gaba] Plugin enabled. Drop .dlg files into your project to import them.")


func _exit_tree() -> void:
	if _importer != null:
		remove_import_plugin(_importer)
		_importer = null
	if _wizard_dock != null:
		remove_control_from_docks(_wizard_dock)
		_wizard_dock.queue_free()
		_wizard_dock = null
	if _preview_dock != null:
		remove_control_from_docks(_preview_dock)
		_preview_dock.queue_free()
		_preview_dock = null
	remove_autoload_singleton(AUTOLOAD_NAME)
	print("[Gaba] Plugin disabled.")
