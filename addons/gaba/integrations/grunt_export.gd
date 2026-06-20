@tool
class_name GabaGruntExport
extends RefCounted

## Exports a dialogue's voiced lines as a [url=https://github.com/siliconight/grunt]grunt[/url]
## batch CSV, so grunt can bake the whole conversation's VO in one pass and the
## clip names line up with what the gool bridge plays — by construction, not by
## hand.
##
## grunt's batch CSV is `name,text[,character]`: column 0 is the clip name
## (the contract — see [GabaVoNaming]), column 1 the line to speak, column 2 an
## optional grunt character (voice + styling) that overrides grunt's
## `--character` default. A `name,text,character` header row is skipped by grunt.
##
## Usage (editor tool script, or runtime):
## [codeblock]
## GabaGruntExport.export_dlg_folder("res://dialogues", "res://vo_job.csv", {
##     "casting": {"Blacksmith": "jersey", "Oracle": "norman"},
##     "default_character": "narrator",
## })
## [/codeblock]
## Then bake:  grunt batch --csv vo_job.csv --out-dir vo/
##
## Options (all optional):
## - casting: Dictionary  speaker name -> grunt character (case-insensitive)
## - default_character: String  used when a speaker isn't in casting (""=grunt default)
## - only_explicit_vo: bool  if true, export only nodes with an explicit `vo:`
##                            (default false: every line with text gets a clip)
## - include_header: bool  write the `name,text,character` header (default true)
##
## Text handling: each line's text is flattened to a single physical line
## (newlines/tabs -> spaces) and RFC-4180 quoted when it contains a comma or
## quote. NOTE: grunt's current batch parser splits naively on commas; until it
## gains quoted-field support, lines containing commas are best baked from a
## grunt build with that fix. Lines without commas round-trip on any grunt.


## Build the row dictionaries for a resource without writing a file.
## Each row: {name, text, character, speaker, node_id}.
static func rows_for_resource(resource: DialogueResource, opts: Dictionary = {}) -> Array:
	var rows: Array = []
	if resource == null:
		return rows
	var casting: Dictionary = opts.get("casting", {})
	var default_character: String = opts.get("default_character", "")
	var only_explicit: bool = opts.get("only_explicit_vo", false)
	var dialogue_id := str(resource.dialogue_id)

	for node_id in resource.nodes.keys():  # insertion order = source order
		var node = resource.nodes[node_id]
		var text := _flatten(str(node.text))
		if text.is_empty():
			continue
		if only_explicit and str(node.voiceover_event_id).strip_edges().is_empty():
			continue
		var name := GabaVoNaming.resolve(node, dialogue_id)
		if name.is_empty():
			continue
		var speaker := str(node.speaker)
		rows.append({
			"name": name,
			"text": text,
			"character": _character_for(node, speaker, casting, default_character),
			"speaker": speaker,
			"node_id": str(node_id),
		})
	return rows


## Export a single resource. Returns the number of rows written, or -1 on error.
static func export_resource(resource: DialogueResource, out_path: String, opts: Dictionary = {}) -> int:
	return write_csv(rows_for_resource(resource, opts), out_path, opts)


## Export one or more `.dlg` files (parsed directly — no editor import needed).
## Rows from every file are concatenated into one CSV.
static func export_dlg_files(paths, out_path: String, opts: Dictionary = {}) -> int:
	var all_rows: Array = []
	for p in paths:
		var src := _read_text(str(p))
		if src.is_empty():
			continue
		var dialogue_id := str(p).get_file().get_basename()
		var result = DialogueParser.parse(src, dialogue_id)
		if not result.ok():
			push_warning("[GabaGruntExport] %s has parse errors; exporting the nodes that parsed" % p)
		all_rows.append_array(rows_for_resource(result.resource, opts))
	return write_csv(all_rows, out_path, opts)


## Export every `.dlg` directly under [param dir_path] (non-recursive).
static func export_dlg_folder(dir_path: String, out_path: String, opts: Dictionary = {}) -> int:
	var paths := PackedStringArray()
	var d := DirAccess.open(dir_path)
	if d == null:
		push_error("[GabaGruntExport] cannot open directory %s" % dir_path)
		return -1
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.get_extension().to_lower() == "dlg":
			paths.append(dir_path.path_join(fn))
		fn = d.get_next()
	d.list_dir_end()
	if paths.is_empty():
		push_warning("[GabaGruntExport] no .dlg files found in %s" % dir_path)
	return export_dlg_files(paths, out_path, opts)


## Write pre-built rows to a CSV. Returns rows written, or -1 on error.
static func write_csv(rows: Array, out_path: String, opts: Dictionary = {}) -> int:
	var include_header: bool = opts.get("include_header", true)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("[GabaGruntExport] cannot open %s for writing: %s"
				% [out_path, error_string(FileAccess.get_open_error())])
		return -1
	if include_header:
		f.store_line("name,text,character")
	for r in rows:
		f.store_line("%s,%s,%s" % [
			_csv(str(r.get("name", ""))),
			_csv(str(r.get("text", ""))),
			_csv(str(r.get("character", ""))),
		])
	f.close()
	return rows.size()


# --- helpers ---

static func _character_for(node, speaker: String, casting: Dictionary, default_character: String) -> String:
	# 1) per-node override stashed in speaker_metadata by game/tooling
	if node.speaker_metadata is Dictionary and node.speaker_metadata.has("grunt_character"):
		return str(node.speaker_metadata["grunt_character"])
	# 2) casting table, matched on speaker name (case-insensitive)
	var lower := speaker.to_lower()
	for key in casting.keys():
		if str(key).to_lower() == lower:
			return str(casting[key])
	# 3) fall back to the default (empty = let grunt's --character decide)
	return default_character


# Collapse newlines/tabs/whitespace runs to single spaces — a VO clip is one
# spoken utterance, and one physical CSV line keeps grunt's line reader happy.
static func _flatten(s: String) -> String:
	var out := s.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	while out.find("  ") != -1:
		out = out.replace("  ", " ")
	return out.strip_edges()


# RFC-4180 quoting: wrap in quotes (doubling internal quotes) when the field
# contains a comma or quote. Newlines are already flattened out above.
static func _csv(field: String) -> String:
	if field.find(",") != -1 or field.find("\"") != -1:
		return "\"" + field.replace("\"", "\"\"") + "\""
	return field


static func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[GabaGruntExport] cannot read %s" % path)
		return ""
	var t := f.get_as_text()
	f.close()
	return t
