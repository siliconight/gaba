extends Control

## Conversation flow preview pane.
##
## Loads a .dlg file, reparses it (so writers see their latest edits, not the
## cached .res), and lets them click through the conversation like a player.
##
## # Mock semantics
##
## Real game runtime has handlers registered for conditions (`if: quest_state
## ...`) and effects (`do: start_quest ...`). The preview has none — it
## doesn't know your game state. So:
##
## - Conditions: a toggle (`Show choices with conditions`) decides whether to
##   show all choices (toggle on, equivalent to "all conditions pass") or only
##   unconditional choices (toggle off, equivalent to "all conditions fail").
##   Configurable per-flag mocking is future work.
##
## - Effects: logged to a green-tinted list under the choices, with their
##   source (choice text or scene id). Not executed. This lets writers verify
##   "yes, picking this option starts the quest" without running the game.
##
## # Live re-parse
##
## The preview always reparses the .dlg file from disk on Load. Cached .res
## imports are ignored. So if you edit a .dlg, save it, and click Load, you
## see the post-edit state immediately — no need to wait for Godot's reimport.
##
## Registered as a dock control by plugin.gd alongside the wizard.

const PARSER := preload("res://addons/gaba/importer/dialogue_parser.gd")
const VALIDATOR := preload("res://addons/gaba/validators/dialogue_validator.gd")

# UI references — assigned in _build_ui()
var _path_edit: LineEdit
var _show_gated_check: CheckBox
var _speaker_label: Label
var _text_label: RichTextLabel
var _choices_container: VBoxContainer
var _effects_log: VBoxContainer
var _status_label: Label
var _scene_indicator: Label
var _file_dialog: EditorFileDialog

# State
var _dialogue: DialogueResource = null
var _current_node_id: String = ""
var _triggered_effects: Array[String] = []


func _ready() -> void:
	name = "Gaba Play"
	custom_minimum_size = Vector2(0, 480)
	_build_ui()
	_render_empty_state()


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Outer scroll, because the form grows (effects log, long NPC text).
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 4)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(form)

	# --- Header ---
	var header := Label.new()
	header.text = "Preview Conversation"
	header.add_theme_font_size_override("font_size", 14)
	form.add_child(header)
	form.add_child(HSeparator.new())

	# --- File row ---
	form.add_child(_section_label("File"))
	var file_row := HBoxContainer.new()
	form.add_child(file_row)

	_path_edit = LineEdit.new()
	_path_edit.placeholder_text = "res://dialogues/my_npc.dlg"
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_edit.text_submitted.connect(_on_path_submitted)
	file_row.add_child(_path_edit)

	var browse := Button.new()
	browse.text = "…"
	browse.tooltip_text = "Browse for a .dlg file"
	browse.pressed.connect(_on_browse_pressed)
	file_row.add_child(browse)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.tooltip_text = "Reparse the file and restart at the start scene"
	load_btn.pressed.connect(_on_load_pressed)
	file_row.add_child(load_btn)

	# --- Choice gating toggle ---
	_show_gated_check = CheckBox.new()
	_show_gated_check.text = "Show choices with conditions"
	_show_gated_check.button_pressed = true
	_show_gated_check.tooltip_text = "On: see every choice. Off: see only choices with no `if:` clause — the path a fresh-state player would see."
	_show_gated_check.toggled.connect(_on_gating_toggled)
	form.add_child(_show_gated_check)

	form.add_child(HSeparator.new())

	# --- Speaker name + text ---
	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 13)
	_speaker_label.modulate = Color(0.95, 0.85, 0.55)  # warm tone for speaker
	form.add_child(_speaker_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.custom_minimum_size = Vector2(0, 60)
	form.add_child(_text_label)

	form.add_child(HSeparator.new())

	# --- Choices area (dynamic buttons) ---
	_choices_container = VBoxContainer.new()
	_choices_container.add_theme_constant_override("separation", 2)
	_choices_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_choices_container)

	form.add_child(HSeparator.new())

	# --- Effects log ---
	form.add_child(_section_label("Triggered effects"))
	_effects_log = VBoxContainer.new()
	_effects_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_effects_log)

	form.add_child(HSeparator.new())

	# --- Footer: scene indicator + reset ---
	var footer := HBoxContainer.new()
	form.add_child(footer)

	_scene_indicator = Label.new()
	_scene_indicator.modulate = Color(1, 1, 1, 0.5)
	_scene_indicator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_scene_indicator)

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.tooltip_text = "Return to the start scene and clear effects log"
	reset_btn.pressed.connect(_on_reset_pressed)
	footer.add_child(reset_btn)

	# --- Status line ---
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_status_label)


func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(1, 1, 1, 0.75)
	return l


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _on_path_submitted(_text: String) -> void:
	_load_current_path()


func _on_load_pressed() -> void:
	_load_current_path()


func _on_browse_pressed() -> void:
	if _file_dialog == null:
		_file_dialog = EditorFileDialog.new()
		_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_file_dialog.add_filter("*.dlg", "Gaba dialogue files")
		_file_dialog.title = "Choose a .dlg file to preview"
		_file_dialog.file_selected.connect(_on_file_chosen)
		EditorInterface.get_base_control().add_child(_file_dialog)
	if not _path_edit.text.is_empty():
		_file_dialog.current_path = _path_edit.text
	_file_dialog.popup_centered_ratio(0.6)


func _on_file_chosen(path: String) -> void:
	_path_edit.text = path
	_load_current_path()


func _on_gating_toggled(_pressed: bool) -> void:
	if _dialogue != null:
		_render_choices()


func _on_reset_pressed() -> void:
	if _dialogue == null:
		return
	_current_node_id = _dialogue.start_node_id
	_triggered_effects.clear()
	_render_current_scene()
	_status("Reset to start scene.", false)


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

func _load_current_path() -> void:
	var path := _path_edit.text.strip_edges()
	if path.is_empty():
		_status("Enter a .dlg path or use Browse.", true)
		return
	if not path.begins_with("res://"):
		_status("Path must start with res://", true)
		return
	if not FileAccess.file_exists(path):
		_status("File not found: %s" % path, true)
		return

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_status("Could not open %s (error %d)" % [path, FileAccess.get_open_error()], true)
		return
	var text := f.get_as_text()
	f.close()

	var dialogue_id := path.get_file().get_basename()
	var parse_result = PARSER.parse(text, dialogue_id)

	if not parse_result.ok():
		_dialogue = null
		var error_lines: Array[String] = []
		for err in parse_result.errors:
			error_lines.append("  line %d: %s" % [err["line"], err["message"]])
		_status("Parse errors:\n" + "\n".join(error_lines), true)
		_render_empty_state()
		return

	_dialogue = parse_result.resource
	_triggered_effects.clear()
	_current_node_id = _dialogue.start_node_id

	# Validation result is informational; we render either way.
	var validation = VALIDATOR.validate(_dialogue)
	if validation.error_count() > 0:
		_status("Loaded with validation errors. Some scenes may misbehave.\n" + validation.format_friendly(), true)
	else:
		_status(validation.format_friendly(), false)

	_render_current_scene()


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _render_empty_state() -> void:
	_speaker_label.text = ""
	_text_label.text = "Load a .dlg file to begin previewing."
	_clear_children(_choices_container)
	_scene_indicator.text = ""
	_render_effects_log()


func _render_current_scene() -> void:
	if _dialogue == null:
		_render_empty_state()
		return
	if _current_node_id.is_empty():
		# Two reasons _current_node_id can be empty:
		#   (a) the dialogue legitimately ended (user picked a terminal choice
		#       or reached a no-choice node)
		#   (b) the dialogue has no valid start scene
		# Distinguish by checking whether the dialogue HAS a valid start.
		_speaker_label.text = ""
		if _dialogue.start_node_id.is_empty() or not _dialogue.has_node(_dialogue.start_node_id):
			_text_label.text = "This dialogue has no valid start scene. See validation errors below."
			_scene_indicator.text = ""
		else:
			_text_label.text = "— Conversation ended —"
			_scene_indicator.text = "(ended)"
		_clear_children(_choices_container)
		_render_effects_log()
		return
	if not _dialogue.has_node(_current_node_id):
		_speaker_label.text = ""
		_text_label.text = "Error: scene '%s' not found in this dialogue." % _current_node_id
		_clear_children(_choices_container)
		_scene_indicator.text = ""
		return

	var node: DialogueNodeResource = _dialogue.nodes[_current_node_id]
	_speaker_label.text = node.speaker if not node.speaker.is_empty() else _dialogue.npc_id
	_text_label.text = node.text if not node.text.is_empty() else "(scene has no dialogue text)"
	_scene_indicator.text = "Scene: " + _current_node_id

	_render_choices()
	_render_effects_log()


func _render_choices() -> void:
	_clear_children(_choices_container)

	if _dialogue == null or _current_node_id.is_empty():
		return
	if not _dialogue.has_node(_current_node_id):
		return

	var node: DialogueNodeResource = _dialogue.nodes[_current_node_id]

	# Terminal: no choices OR explicit END.
	if node.choices.is_empty() or node.is_end:
		var end_label := Label.new()
		end_label.text = "— End of conversation —"
		end_label.modulate = Color(1, 1, 1, 0.6)
		end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_choices_container.add_child(end_label)
		return

	var show_gated: bool = _show_gated_check.button_pressed
	var visible_count := 0

	for i in node.choices.size():
		var choice: DialogueChoiceResource = node.choices[i]
		var has_conditions := not choice.conditions.is_empty()
		if has_conditions and not show_gated:
			continue

		var btn := Button.new()
		var btn_text := choice.text if not choice.text.is_empty() else "(continue)"
		if btn_text.length() > 80:
			btn_text = btn_text.substr(0, 77) + "..."
		if has_conditions:
			btn_text += "   (gated)"
		btn.text = btn_text
		btn.tooltip_text = choice.text if not choice.text.is_empty() else "(empty choice — auto-advance)"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_choice_pressed.bind(i))
		_choices_container.add_child(btn)
		visible_count += 1

	if visible_count == 0:
		var hint := Label.new()
		hint.text = "(All choices on this scene have conditions. Toggle \"Show choices with conditions\" to see them.)"
		hint.modulate = Color(1, 1, 1, 0.6)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_choices_container.add_child(hint)


func _render_effects_log() -> void:
	_clear_children(_effects_log)
	if _triggered_effects.is_empty():
		var empty := Label.new()
		empty.text = "(none yet)"
		empty.modulate = Color(1, 1, 1, 0.4)
		_effects_log.add_child(empty)
		return
	for line in _triggered_effects:
		var label := Label.new()
		label.text = "• " + line
		label.modulate = Color(0.65, 0.95, 0.65)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_effects_log.add_child(label)


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


# ---------------------------------------------------------------------------
# Choice navigation
# ---------------------------------------------------------------------------

func _on_choice_pressed(choice_idx: int) -> void:
	if _dialogue == null or _current_node_id.is_empty():
		return
	if not _dialogue.has_node(_current_node_id):
		return

	var node: DialogueNodeResource = _dialogue.nodes[_current_node_id]
	if choice_idx < 0 or choice_idx >= node.choices.size():
		return

	var choice: DialogueChoiceResource = node.choices[choice_idx]

	# Log the choice's effects (no execution — mock).
	for effect in choice.effects:
		_log_effect(effect, "choice", _choice_source_label(choice, choice_idx))

	# Terminal choice → conversation ends.
	if choice.target_node_id.is_empty():
		_current_node_id = ""
		_render_current_scene()
		return

	# Advance to the target scene.
	_current_node_id = choice.target_node_id

	# Log the new scene's effects (entered the scene).
	if _dialogue.has_node(_current_node_id):
		var new_node: DialogueNodeResource = _dialogue.nodes[_current_node_id]
		for effect in new_node.effects:
			_log_effect(effect, "scene", _current_node_id)

	_render_current_scene()


# ---------------------------------------------------------------------------
# Effects logging
# ---------------------------------------------------------------------------

func _log_effect(effect: DialogueEffect, source_kind: String, source_label: String) -> void:
	var args_str := " ".join(effect.args)
	var description := effect.kind
	if not args_str.is_empty():
		description += " " + args_str
	var entry := "[%s: %s] %s" % [source_kind, source_label, description]
	_triggered_effects.append(entry)
	_render_effects_log()


func _choice_source_label(choice: DialogueChoiceResource, idx: int) -> String:
	if not choice.text.is_empty():
		var t := choice.text
		if t.length() > 40:
			t = t.substr(0, 37) + "..."
		return "\"%s\"" % t
	return "#%d" % (idx + 1)


# ---------------------------------------------------------------------------
# Status line
# ---------------------------------------------------------------------------

func _status(message: String, is_error: bool) -> void:
	_status_label.text = message
	_status_label.modulate = Color(1.0, 0.55, 0.55) if is_error else Color(0.55, 1.0, 0.65)


# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _file_dialog != null and is_instance_valid(_file_dialog):
			_file_dialog.queue_free()
			_file_dialog = null
