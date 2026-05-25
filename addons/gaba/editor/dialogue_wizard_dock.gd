@tool
extends Control

## "Create NPC Dialogue" wizard dock.
##
## Lives in the Godot editor as a dockable panel. Lets a narrative designer
## create a new NPC dialogue file from a template without learning the .dlg
## format first.
##
## Flow:
##   1. Type the NPC's display name (e.g. "Captain Aldric").
##   2. Pick a template from the dropdown (descriptions read from the template's
##      leading comment block).
##   3. Confirm the save location and filename (auto-derived from the NPC name).
##   4. Click Create. The wizard copies the template, substitutes the NPC id
##      AND the speaker name throughout, writes the file, and rescans the
##      filesystem so Godot imports it.
##
## Registered by [code]plugin.gd[/code] as a dock control. Reads templates from
## [code]res://addons/gaba/templates/[/code] — drop your own templates there to
## have them appear in the dropdown.

const TEMPLATES_DIR := "res://addons/gaba/templates/"
const DEFAULT_OUTPUT_DIR := "res://dialogues/"

# Same reserved-word list the story parser uses, for slug validation.
const _RESERVED_SLUGS := ["scene", "if", "do", "vo", "subtitle", "loc",
		"playback", "speaker", "end", "start", "choice", "condition", "effect",
		"choice_if", "choice_do", "vo_event", "vo_audio"]

# --- UI nodes (assigned in _build_ui) ---
var _npc_name_edit: LineEdit
var _template_option: OptionButton
var _template_desc_label: Label
var _save_dir_edit: LineEdit
var _filename_edit: LineEdit
var _create_button: Button
var _status_label: Label
var _save_dir_dialog: EditorFileDialog

# --- State ---
# Each entry: {"path": String, "title": String, "description": String}
var _templates: Array = []

# True once the user has manually edited the filename — stops the
# auto-derive-from-NPC-name behaviour from clobbering their choice.
var _filename_user_edited: bool = false


func _ready() -> void:
	name = "Gaba"
	custom_minimum_size = Vector2(0, 380)
	_build_ui()
	_scan_templates()
	_update_create_enabled()


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Outer margin so content doesn't touch dock edges.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)

	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 4)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(form)

	# --- Header ---
	var header := Label.new()
	header.text = "Create NPC Dialogue"
	header.add_theme_font_size_override("font_size", 14)
	form.add_child(header)
	form.add_child(HSeparator.new())

	# --- NPC name ---
	form.add_child(_section_label("NPC name"))
	_npc_name_edit = LineEdit.new()
	_npc_name_edit.placeholder_text = "Captain Aldric"
	_npc_name_edit.text_changed.connect(_on_npc_name_changed)
	form.add_child(_npc_name_edit)

	# --- Template picker ---
	form.add_child(_section_label("Template"))
	var template_row := HBoxContainer.new()
	form.add_child(template_row)

	_template_option = OptionButton.new()
	_template_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_template_option.item_selected.connect(_on_template_selected)
	template_row.add_child(_template_option)

	var refresh := Button.new()
	refresh.text = "↻"
	refresh.tooltip_text = "Rescan templates folder"
	refresh.pressed.connect(_on_refresh_pressed)
	template_row.add_child(refresh)

	_template_desc_label = Label.new()
	_template_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_template_desc_label.modulate = Color(1, 1, 1, 0.6)
	_template_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_template_desc_label)

	# --- Save directory ---
	form.add_child(_section_label("Save to"))
	var save_row := HBoxContainer.new()
	form.add_child(save_row)

	_save_dir_edit = LineEdit.new()
	_save_dir_edit.text = DEFAULT_OUTPUT_DIR
	_save_dir_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(_save_dir_edit)

	var browse := Button.new()
	browse.text = "…"
	browse.tooltip_text = "Browse for folder"
	browse.pressed.connect(_on_browse_pressed)
	save_row.add_child(browse)

	# --- Filename ---
	form.add_child(_section_label("Filename"))
	_filename_edit = LineEdit.new()
	_filename_edit.placeholder_text = "my_npc.dlg"
	_filename_edit.text_changed.connect(_on_filename_changed_by_user)
	form.add_child(_filename_edit)

	# --- Create button (right-aligned) ---
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	form.add_child(button_row)

	_create_button = Button.new()
	_create_button.text = "Create"
	_create_button.pressed.connect(_on_create_pressed)
	button_row.add_child(_create_button)

	form.add_child(HSeparator.new())

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
# Template scanning
# ---------------------------------------------------------------------------

func _scan_templates() -> void:
	_templates.clear()
	_template_option.clear()

	var dir := DirAccess.open(TEMPLATES_DIR)
	if dir == null:
		_status("Templates folder not found at %s" % TEMPLATES_DIR, true)
		return

	dir.list_dir_begin()
	var filenames: Array[String] = []
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		if dir.current_is_dir():
			continue
		if entry.ends_with(".dlg"):
			filenames.append(entry)
	dir.list_dir_end()
	filenames.sort()

	for fn in filenames:
		var meta := _read_template_meta(TEMPLATES_DIR + fn)
		if meta.is_empty():
			continue
		_templates.append(meta)
		_template_option.add_item(meta["title"])

	if _templates.is_empty():
		_status("No .dlg templates found in %s" % TEMPLATES_DIR, true)
	else:
		_template_option.select(0)
		_on_template_selected(0)


func _read_template_meta(path: String) -> Dictionary:
	# Reads the leading `#` comment block as the template's title and description.
	# Title = first comment line. Description = subsequent comment lines until
	# the first non-comment line.
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}

	var title := ""
	var description_parts: Array[String] = []
	while not f.eof_reached():
		var line := f.get_line()
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			var comment := stripped.substr(1).strip_edges()
			if title.is_empty() and not comment.is_empty():
				title = comment
			elif not comment.is_empty():
				description_parts.append(comment)
		elif stripped.is_empty():
			# Blank line — keep scanning if we're still in the comment block.
			if title.is_empty():
				continue
			# Once we've started, blank line could end the comment block; but
			# the templates have blanks INSIDE the leading block, so keep going
			# until we hit non-comment content.
			continue
		else:
			break  # first content line — comment block ended

	f.close()
	return {
		"path": path,
		"title": title if not title.is_empty() else path.get_file(),
		"description": " ".join(description_parts),
	}


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _on_npc_name_changed(new_text: String) -> void:
	if not _filename_user_edited:
		_filename_edit.text = _slugify(new_text) + ".dlg" if not new_text.strip_edges().is_empty() else ""
	_update_create_enabled()


func _on_filename_changed_by_user(_new_text: String) -> void:
	_filename_user_edited = true
	_update_create_enabled()


func _on_template_selected(idx: int) -> void:
	if idx < 0 or idx >= _templates.size():
		_template_desc_label.text = ""
		return
	_template_desc_label.text = _templates[idx]["description"]


func _on_refresh_pressed() -> void:
	_scan_templates()
	_status("Rescanned templates folder.", false)


func _on_browse_pressed() -> void:
	if _save_dir_dialog == null:
		_save_dir_dialog = EditorFileDialog.new()
		_save_dir_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
		_save_dir_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_save_dir_dialog.title = "Choose save directory"
		_save_dir_dialog.dir_selected.connect(_on_save_dir_chosen)
		EditorInterface.get_base_control().add_child(_save_dir_dialog)
	_save_dir_dialog.current_dir = _save_dir_edit.text
	_save_dir_dialog.popup_centered_ratio(0.6)


func _on_save_dir_chosen(dir: String) -> void:
	if not dir.ends_with("/"):
		dir += "/"
	_save_dir_edit.text = dir


func _on_create_pressed() -> void:
	_create_button.disabled = true  # prevent double-click while we work
	var ok := _do_create()
	_create_button.disabled = false
	if ok:
		# Reset just the NPC name so the next NPC starts fresh, but keep the
		# user's template / save-dir choices.
		_npc_name_edit.text = ""
		_filename_edit.text = ""
		_filename_user_edited = false
		_update_create_enabled()


# ---------------------------------------------------------------------------
# Core: create the file
# ---------------------------------------------------------------------------

func _do_create() -> bool:
	# Read & validate inputs.
	var npc_display := _npc_name_edit.text.strip_edges()
	if npc_display.is_empty():
		_status("NPC name is required.", true)
		return false

	var npc_id := _slugify(npc_display)
	if npc_id.is_empty() or npc_id in _RESERVED_SLUGS:
		_status("NPC name '%s' produces a reserved or empty slug ('%s'). Pick a different name." % [npc_display, npc_id], true)
		return false

	var template_idx := _template_option.selected
	if template_idx < 0 or template_idx >= _templates.size():
		_status("Pick a template first.", true)
		return false
	var template: Dictionary = _templates[template_idx]

	var save_dir := _save_dir_edit.text.strip_edges()
	if save_dir.is_empty():
		_status("Save directory is required.", true)
		return false
	if not save_dir.begins_with("res://"):
		_status("Save directory must be a project path (start with res://).", true)
		return false
	if not save_dir.ends_with("/"):
		save_dir += "/"

	var filename := _filename_edit.text.strip_edges()
	if filename.is_empty():
		filename = npc_id + ".dlg"
	if not filename.ends_with(".dlg"):
		filename += ".dlg"

	var full_path := save_dir + filename

	# Refuse to overwrite — designer must change filename or delete the file.
	if FileAccess.file_exists(full_path):
		_status("File already exists: %s. Change the filename or delete the existing file." % full_path, true)
		return false

	# Read the template.
	var template_text := _read_text_file(template["path"])
	if template_text.is_empty():
		_status("Could not read template file: %s" % template["path"], true)
		return false

	# Substitute NPC name throughout.
	var new_text := _substitute_npc(template_text, npc_id, npc_display)

	# Ensure save directory exists.
	if not DirAccess.dir_exists_absolute(save_dir):
		var mk_err := DirAccess.make_dir_recursive_absolute(save_dir)
		if mk_err != OK:
			_status("Could not create directory %s (error %d)." % [save_dir, mk_err], true)
			return false

	# Write the file.
	var out := FileAccess.open(full_path, FileAccess.WRITE)
	if out == null:
		var open_err := FileAccess.get_open_error()
		_status("Could not write to %s (error %d)." % [full_path, open_err], true)
		return false
	out.store_string(new_text)
	out.close()

	# Rescan filesystem so Godot imports the new .dlg → .res.
	var fs := EditorInterface.get_resource_filesystem()
	if fs != null:
		fs.scan()

	# Reveal in the FileSystem dock.
	EditorInterface.select_file(full_path)

	_status("Created %s. Open it via the FileSystem dock to edit." % full_path, false)
	return true


# Replaces the file-level `NPC: <id>` header with the new slug, and any speaker
# blocks led by the template's current NPC display name with the new display
# name. Leaves "Player:" and "Scene:" blocks alone.
func _substitute_npc(template_text: String, new_id: String, new_display: String) -> String:
	var lines := template_text.split("\n", true)

	# Pass 1: detect the template's current display speaker. We use the first
	# non-comment, non-header speaker block that isn't Player/Scene.
	var current_display := ""
	for line in lines:
		var stripped := line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		if stripped.begins_with("NPC:"):
			continue
		var colon_idx := stripped.find(":")
		if colon_idx <= 0:
			continue
		var prefix := stripped.substr(0, colon_idx).strip_edges()
		if prefix.to_lower() == "player" or prefix.to_lower() in _RESERVED_SLUGS:
			continue
		if not _is_speaker_like(prefix):
			continue
		current_display = prefix
		break

	# Pass 2: substitute.
	var out_lines: Array[String] = []
	var npc_header_done := false
	for line in lines:
		var stripped := line.strip_edges()

		# File-level NPC: header — replace once.
		if not npc_header_done and stripped.begins_with("NPC:"):
			out_lines.append("NPC: " + new_id)
			npc_header_done = true
			continue

		# Speaker block header for the old display name.
		if not current_display.is_empty():
			if stripped == current_display + ":" or stripped.begins_with(current_display + ": "):
				# Replace just the prefix; preserve any inline text after the colon.
				var rest := stripped.substr(current_display.length())
				out_lines.append(new_display + rest)
				continue

		out_lines.append(line)

	return "\n".join(out_lines)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _update_create_enabled() -> void:
	var npc_ok := not _npc_name_edit.text.strip_edges().is_empty()
	var template_ok := _template_option.selected >= 0
	_create_button.disabled = not (npc_ok and template_ok and not _templates.is_empty())


func _read_text_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


func _status(message: String, is_error: bool) -> void:
	_status_label.text = message
	_status_label.modulate = Color(1.0, 0.55, 0.55) if is_error else Color(0.55, 1.0, 0.65)


# Slugify a display name to a snake_case id. Same algorithm the parser uses for
# Scene: names, so wizard-generated ids match what the parser would produce
# from the same Scene: name.
func _slugify(s: String) -> String:
	var lower := s.to_lower().strip_edges()
	var out := ""
	var prev_sep := true
	for i in lower.length():
		var ch := lower[i]
		var code := ch.unicode_at(0)
		var is_alnum := (code >= 0x61 and code <= 0x7A) or (code >= 0x30 and code <= 0x39)
		if is_alnum:
			out += ch
			prev_sep = false
		elif not prev_sep:
			out += "_"
			prev_sep = true
	while out.ends_with("_"):
		out = out.substr(0, out.length() - 1)
	return out


# True if [param prefix] looks like a proper-noun speaker label (letters,
# digits, spaces, apostrophes, hyphens, periods). Used to find the existing
# speaker name in a template so it can be substituted. Must match the
# parser's _match_speaker_header in dialogue_parser.gd.
func _is_speaker_like(prefix: String) -> bool:
	if prefix.is_empty() or prefix.length() > 64:
		return false
	for i in prefix.length():
		var ch := prefix[i]
		var code := ch.unicode_at(0)
		var is_alpha := (code >= 0x41 and code <= 0x5A) or (code >= 0x61 and code <= 0x7A)
		var is_digit := code >= 0x30 and code <= 0x39
		if not (is_alpha or is_digit or ch == " " or ch == "'" or ch == "-" or ch == "."):
			return false
	return true
