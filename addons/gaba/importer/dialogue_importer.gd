@tool
class_name DialogueImporter
extends EditorImportPlugin

## EditorImportPlugin that converts .dlg source files into [DialogueResource] assets.
##
## Registered by plugin.gd when the editor plugin is enabled. Once registered,
## Godot automatically reimports .dlg files when they change, validates them,
## and writes the result to .godot/imported/ as a binary resource.

const PARSER := preload("res://addons/gaba/importer/dialogue_parser.gd")
const VALIDATOR := preload("res://addons/gaba/validators/dialogue_validator.gd")


func _get_importer_name() -> String:
	return "gaba.dialogue"


func _get_visible_name() -> String:
	return "Gaba Dialogue"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["dlg"])


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_priority() -> float:
	return 1.0


func _get_import_order() -> int:
	return 0


func _get_preset_count() -> int:
	return 1


func _get_preset_name(preset_index: int) -> String:
	return "Default"


func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "require_localization",
			"default_value": false,
			"property_hint": PROPERTY_HINT_NONE,
			"hint_string": "Require a localization key on every node with text",
		},
		{
			"name": "fail_on_warnings",
			"default_value": false,
			"property_hint": PROPERTY_HINT_NONE,
			"hint_string": "Treat warnings as import failures",
		},
	]


func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true


func _import(
	source_file: String,
	save_path: String,
	options: Dictionary,
	platform_variants: Array[String],
	gen_files: Array[String]
) -> Error:
	var file := FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		push_error("[Gaba] Could not open %s: %s" % [source_file, FileAccess.get_open_error()])
		return FileAccess.get_open_error()
	var text := file.get_as_text()
	file.close()

	# dialogue_id defaults to the source basename, stripped of extension.
	var dialogue_id := source_file.get_file().get_basename()

	# --- Parse ---
	var parse_result = PARSER.parse(text, dialogue_id)
	if not parse_result.ok():
		for err in parse_result.errors:
			push_error("[Gaba] %s:%d  %s" % [source_file, err["line"], err["message"]])
		return ERR_PARSE_ERROR

	# --- Validate ---
	var require_loc: bool = options.get("require_localization", false)
	var fail_on_warn: bool = options.get("fail_on_warnings", false)
	var report = VALIDATOR.validate(parse_result.resource, require_loc)

	for issue in report.issues:
		var location := "%s [%s]" % [source_file, issue.node_id] if not issue.node_id.is_empty() else source_file
		if issue.severity == VALIDATOR.Severity.ERROR:
			push_error("[Gaba] %s  %s: %s" % [location, issue.code, issue.message])
		else:
			push_warning("[Gaba] %s  %s: %s" % [location, issue.code, issue.message])

	if report.error_count() > 0:
		return ERR_INVALID_DATA
	if fail_on_warn and report.warning_count() > 0:
		return ERR_INVALID_DATA

	# --- Save the resource ---
	var out_path := "%s.%s" % [save_path, _get_save_extension()]
	var save_err := ResourceSaver.save(parse_result.resource, out_path)
	if save_err != OK:
		push_error("[Gaba] Failed to save imported resource to %s: %d" % [out_path, save_err])
		return save_err

	print("[Gaba] Imported %s (%d nodes)" % [source_file, parse_result.resource.nodes.size()])
	return OK
