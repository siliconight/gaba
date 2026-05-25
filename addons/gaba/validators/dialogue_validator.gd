@tool
class_name DialogueValidator
extends RefCounted

## Semantic validation of an assembled [DialogueResource].
##
## Run *after* parsing. The parser handles syntax (malformed lines, duplicate node
## headers); the validator handles meaning (broken links, unreachable nodes,
## missing required metadata).
##
## All checks are non-fatal — the validator collects every issue and returns them
## in a [ValidationReport]. Severity is split between errors (block import) and
## warnings (allow import, log to the editor).
##
## For human-readable output (the eventual editor panel), see
## [method ValidationReport.format_friendly].

enum Severity { ERROR, WARNING }

class Issue:
	var severity: int
	var code: String       # short identifier, e.g. "broken_link"
	var message: String
	var node_id: String    # empty if not node-specific

	func _to_string() -> String:
		var sev := "ERROR" if severity == Severity.ERROR else "WARN"
		var loc := " [%s]" % node_id if not node_id.is_empty() else ""
		return "%s %s%s: %s" % [sev, code, loc, message]


class ValidationReport:
	var issues: Array[Issue] = []
	var dialogue: DialogueResource  # back-reference for format_friendly counts

	func ok() -> bool:
		return error_count() == 0

	func error_count() -> int:
		var n := 0
		for issue in issues:
			if issue.severity == Severity.ERROR:
				n += 1
		return n

	func warning_count() -> int:
		var n := 0
		for issue in issues:
			if issue.severity == Severity.WARNING:
				n += 1
		return n

	## Legacy verbose format. One issue per line, prefixed with severity.
	func format() -> String:
		if issues.is_empty():
			return "No issues."
		var lines: Array[String] = []
		for issue in issues:
			lines.append(str(issue))
		return "\n".join(lines)

	## Designer-facing summary. Produces output like:
	## [codeblock]
	## ✓ 4 scenes, 7 choices, 2 endings
	## ⚠ 1 unreachable scene
	##   - mine_update: Node is not reachable from START
	## ✗ 1 broken choice target
	##   - greeting: Choice 0 targets nonexistent node 'shoppe'
	## [/codeblock]
	## Intended for both the Godot output panel today and the editor
	## validation dock once it exists. Keeps section ordering stable so the
	## eventual UI can color-code by leading glyph.
	func format_friendly() -> String:
		var out: Array[String] = []
		out.append(_format_summary_line())

		# Group remaining issues by code so the panel reads cleanly:
		# "2 unreachable scenes" beats two separate one-off lines.
		var by_code: Dictionary = {}  # code -> Array[Issue]
		for issue in issues:
			if not by_code.has(issue.code):
				by_code[issue.code] = []
			by_code[issue.code].append(issue)

		# Warnings first (less alarming), then errors. Within each, sorted by code.
		var warn_codes: Array = []
		var error_codes: Array = []
		for code in by_code.keys():
			var first = by_code[code][0]
			if first.severity == Severity.WARNING:
				warn_codes.append(code)
			else:
				error_codes.append(code)
		warn_codes.sort()
		error_codes.sort()

		for code in warn_codes:
			out.append_array(_format_issue_group("⚠", code, by_code[code]))
		for code in error_codes:
			out.append_array(_format_issue_group("✗", code, by_code[code]))

		return "\n".join(out)

	func _format_summary_line() -> String:
		var n_scenes := 0
		var n_choices := 0
		var n_endings := 0
		if dialogue != null:
			n_scenes = dialogue.nodes.size()
			for key in dialogue.nodes.keys():
				var node: DialogueNodeResource = dialogue.nodes[key]
				n_choices += node.choices.size()
				# An "ending" is any path that terminates the dialogue:
				# a node with no choices, or any individual terminal choice
				# (one with no target_node_id) on a node that does have choices.
				if node.is_terminal():
					n_endings += 1
				else:
					for choice in node.choices:
						if choice.is_terminal():
							n_endings += 1
		var glyph := "✓" if ok() else "•"
		return "%s %d scene%s, %d choice%s, %d ending%s" % [
				glyph,
				n_scenes, "" if n_scenes == 1 else "s",
				n_choices, "" if n_choices == 1 else "s",
				n_endings, "" if n_endings == 1 else "s"]

	func _format_issue_group(glyph: String, code: String, group: Array) -> Array[String]:
		var label := _humanize_code(code, group.size())
		var lines: Array[String] = []
		lines.append("%s %d %s" % [glyph, group.size(), label])
		for issue in group:
			var loc := "[%s] " % issue.node_id if not issue.node_id.is_empty() else ""
			lines.append("  - %s%s" % [loc, issue.message])
		return lines

	# Map terse codes to designer-friendly phrases.
	func _humanize_code(code: String, count: int) -> String:
		var plural := count > 1
		match code:
			"missing_npc_id": return "missing NPC id"
			"no_nodes": return "empty dialogue"
			"missing_start": return "missing start scene"
			"broken_start": return "broken start scene"
			"broken_link": return "broken choice target%s" % ("s" if plural else "")
			"malformed_condition": return "malformed condition%s" % ("s" if plural else "")
			"malformed_effect": return "malformed effect%s" % ("s" if plural else "")
			"empty_text": return "scene%s with no text" % ("s" if plural else "")
			"unreachable": return "unreachable scene%s" % ("s" if plural else "")
			"missing_localization": return "scene%s missing localization key" % ("s" if plural else "")
			"suspicious_vo_path": return "suspicious VO path%s" % ("s" if plural else "")
			_: return code


## Validates [param dialogue] and returns a [ValidationReport].
##
## [param require_localization] — if true, missing localization keys on nodes
## with non-empty text are flagged as warnings. Off by default since text-only
## projects don't need this.
static func validate(dialogue: DialogueResource, require_localization: bool = false) -> ValidationReport:
	assert(dialogue != null, "DialogueValidator.validate called with null dialogue")
	var report := ValidationReport.new()
	report.dialogue = dialogue

	_check_dialogue_metadata(dialogue, report)
	_check_start_node(dialogue, report)
	_check_node_links(dialogue, report)
	_check_node_content(dialogue, report, require_localization)
	_check_conditions_and_effects(dialogue, report)
	_check_reachability(dialogue, report)

	return report


# --- Top-level metadata ---
static func _check_dialogue_metadata(d: DialogueResource, r: ValidationReport) -> void:
	if d.npc_id.is_empty():
		_add(r, Severity.ERROR, "missing_npc_id", "Dialogue has no NPC id (use 'NPC: <id>' at the top of the file)")
	if d.nodes.is_empty():
		_add(r, Severity.ERROR, "no_nodes", "Dialogue contains no scenes")


# --- Start node ---
static func _check_start_node(d: DialogueResource, r: ValidationReport) -> void:
	if d.start_node_id.is_empty():
		_add(r, Severity.ERROR, "missing_start", "Dialogue has no start scene")
		return
	if not d.has_node(d.start_node_id):
		_add(r, Severity.ERROR, "broken_start", "Start scene '%s' does not exist" % d.start_node_id)


# --- Link integrity: every choice target must exist ---
static func _check_node_links(d: DialogueResource, r: ValidationReport) -> void:
	for node_id in d.nodes.keys():
		var node: DialogueNodeResource = d.nodes[node_id]
		for i in node.choices.size():
			var choice := node.choices[i]
			if choice.target_node_id.is_empty():
				continue  # terminal choice — legal
			if not d.has_node(choice.target_node_id):
				_add_node(r, Severity.ERROR, "broken_link", node_id,
					"Choice %d targets nonexistent scene '%s'" % [i, choice.target_node_id])


# --- Node-level content checks ---
static func _check_node_content(d: DialogueResource, r: ValidationReport, require_loc: bool) -> void:
	for node_id in d.nodes.keys():
		var node: DialogueNodeResource = d.nodes[node_id]
		if node.text.is_empty() and node.localization_key.is_empty():
			_add_node(r, Severity.WARNING, "empty_text", node_id, "Scene has no dialogue text")
		if require_loc and node.localization_key.is_empty() and not node.text.is_empty():
			_add_node(r, Severity.WARNING, "missing_localization", node_id,
				"Scene has text but no localization key")
		if not node.voiceover_audio_path.is_empty() and not node.voiceover_audio_path.contains("/"):
			_add_node(r, Severity.WARNING, "suspicious_vo_path", node_id,
				"voiceover_audio_path '%s' doesn't look like a path" % node.voiceover_audio_path)


# --- Conditions and effects: kind must be non-empty ---
static func _check_conditions_and_effects(d: DialogueResource, r: ValidationReport) -> void:
	for node_id in d.nodes.keys():
		var node: DialogueNodeResource = d.nodes[node_id]
		for i in node.conditions.size():
			var c := node.conditions[i]
			if c.kind.is_empty():
				_add_node(r, Severity.ERROR, "malformed_condition", node_id,
					"Condition %d has empty kind" % i)
		for i in node.effects.size():
			var e := node.effects[i]
			if e.kind.is_empty():
				_add_node(r, Severity.ERROR, "malformed_effect", node_id,
					"Effect %d has empty kind" % i)
		for ci in node.choices.size():
			var choice := node.choices[ci]
			for i in choice.conditions.size():
				if choice.conditions[i].kind.is_empty():
					_add_node(r, Severity.ERROR, "malformed_condition", node_id,
						"Choice %d condition %d has empty kind" % [ci, i])
			for i in choice.effects.size():
				if choice.effects[i].kind.is_empty():
					_add_node(r, Severity.ERROR, "malformed_effect", node_id,
						"Choice %d effect %d has empty kind" % [ci, i])


# --- Reachability: BFS from start, anything not visited is unreachable ---
static func _check_reachability(d: DialogueResource, r: ValidationReport) -> void:
	if d.start_node_id.is_empty() or not d.has_node(d.start_node_id):
		return

	var visited := {}
	var frontier: Array[String] = [d.start_node_id]
	while not frontier.is_empty():
		var current: String = frontier.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		var node: DialogueNodeResource = d.nodes.get(current)
		if node == null:
			continue
		for choice in node.choices:
			if not choice.target_node_id.is_empty() and not visited.has(choice.target_node_id):
				frontier.append(choice.target_node_id)

	for node_id in d.nodes.keys():
		if not visited.has(node_id):
			_add_node(r, Severity.WARNING, "unreachable", node_id,
				"Scene is not reachable from the start")


# --- Issue construction helpers ---
static func _add(r: ValidationReport, sev: int, code: String, msg: String) -> void:
	var issue := Issue.new()
	issue.severity = sev
	issue.code = code
	issue.message = msg
	r.issues.append(issue)


static func _add_node(r: ValidationReport, sev: int, code: String, node_id: String, msg: String) -> void:
	var issue := Issue.new()
	issue.severity = sev
	issue.code = code
	issue.node_id = node_id
	issue.message = msg
	r.issues.append(issue)
