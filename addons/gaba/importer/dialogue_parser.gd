@tool
class_name DialogueParser
extends RefCounted

## Parses .dlg source text into a [DialogueResource].
##
## The parser is intentionally tolerant: it collects errors as it goes rather than
## bailing on the first problem, so authors see the full picture in one pass.
## Semantic validation (broken links, unreachable nodes, etc.) is the validator's job —
## the parser only enforces syntax.
##
## # Grammar (informal)
## [codeblock]
## file       := header? node*
## header     := ("NPC:" id | "START:" id)+
## node       := "[" id "]" line+
## line       := "NPC:" text
##             | "CHOICE:" text "->" id
##             | "CHOICE:" text                   # terminal choice
##             | "EFFECT:" kind args*
##             | "CONDITION:" ["!"] kind args*
##             | "VO_EVENT:" id
##             | "VO_AUDIO:" path
##             | "SUBTITLE:" key
##             | "SPEAKER:" name
##             | "PLAYBACK:" mode
##             | "END"
## [/codeblock]
##
## Lines starting with `#` are comments. Blank lines are ignored.

## Parse result returned by [method parse].
class ParseResult:
	var resource: DialogueResource
	var errors: Array[Dictionary] = []  # [{line: int, message: String}]

	func ok() -> bool:
		return errors.is_empty()


## Parses [param source_text] and returns a [ParseResult].
## [param source_id] is used as the dialogue_id if no other identifier is supplied.
static func parse(source_text: String, source_id: String = "") -> ParseResult:
	var result := ParseResult.new()
	result.resource = DialogueResource.new()
	result.resource.dialogue_id = source_id

	var lines := source_text.split("\n", true)
	var current_node: DialogueNodeResource = null
	var seen_node_ids := {}

	for i in lines.size():
		var line_num := i + 1
		var raw := lines[i]
		var line := raw.strip_edges()

		# Skip comments and blank lines.
		if line.is_empty() or line.begins_with("#"):
			continue

		# --- Node header: [node_id] ---
		if line.begins_with("[") and line.ends_with("]"):
			var node_id := line.substr(1, line.length() - 2).strip_edges()
			if node_id.is_empty():
				_add_error(result, line_num, "Empty node id in '[]' header")
				continue
			if seen_node_ids.has(node_id):
				_add_error(result, line_num, "Duplicate node id '%s' (also defined earlier)" % node_id)
			seen_node_ids[node_id] = true

			current_node = DialogueNodeResource.new()
			current_node.node_id = node_id
			current_node.speaker = result.resource.npc_id  # default; can be overridden
			result.resource.nodes[node_id] = current_node
			continue

		# --- Directive lines (KEYWORD: value) ---
		var colon_idx := line.find(":")
		if colon_idx < 0:
			# Bare keyword (e.g. "END") or malformed line.
			if line == "END":
				if current_node == null:
					_add_error(result, line_num, "'END' outside of any node")
				else:
					current_node.is_end = true
				continue
			_add_error(result, line_num, "Unrecognized line: '%s'" % line)
			continue

		var keyword := line.substr(0, colon_idx).strip_edges().to_upper()
		var value := line.substr(colon_idx + 1).strip_edges()

		match keyword:
			"NPC":
				if current_node == null:
					# File-level header: NPC: <npc_id>
					if not result.resource.npc_id.is_empty():
						_add_error(result, line_num, "Duplicate file-level 'NPC:' declaration")
					result.resource.npc_id = value
				else:
					# Node-level: NPC: <line of dialogue>
					if not current_node.text.is_empty():
						_add_error(result, line_num, "Node '%s' already has dialogue text" % current_node.node_id)
					current_node.text = value
					if current_node.speaker.is_empty():
						current_node.speaker = result.resource.npc_id

			"START":
				if current_node != null:
					_add_error(result, line_num, "'START:' must appear before any node")
				if not result.resource.start_node_id.is_empty():
					_add_error(result, line_num, "Duplicate 'START:' declaration")
				result.resource.start_node_id = value

			"CHOICE":
				if current_node == null:
					_add_error(result, line_num, "'CHOICE:' outside of any node")
					continue
				var choice := _parse_choice(value, line_num, result)
				if choice != null:
					current_node.choices.append(choice)

			"EFFECT":
				if current_node == null:
					_add_error(result, line_num, "'EFFECT:' outside of any node")
					continue
				var effect := _parse_effect(value, line_num, result)
				if effect != null:
					current_node.effects.append(effect)

			"CONDITION":
				if current_node == null:
					_add_error(result, line_num, "'CONDITION:' outside of any node")
					continue
				var condition := _parse_condition(value, line_num, result)
				if condition != null:
					current_node.conditions.append(condition)

			"VO_EVENT":
				if current_node == null:
					_add_error(result, line_num, "'VO_EVENT:' outside of any node")
					continue
				current_node.voiceover_event_id = value

			"VO_AUDIO":
				if current_node == null:
					_add_error(result, line_num, "'VO_AUDIO:' outside of any node")
					continue
				current_node.voiceover_audio_path = value

			"SUBTITLE":
				if current_node == null:
					_add_error(result, line_num, "'SUBTITLE:' outside of any node")
					continue
				current_node.subtitle_text_key = value

			"SPEAKER":
				if current_node == null:
					_add_error(result, line_num, "'SPEAKER:' outside of any node")
					continue
				current_node.speaker = value

			"PLAYBACK":
				if current_node == null:
					_add_error(result, line_num, "'PLAYBACK:' outside of any node")
					continue
				current_node.playback_behavior = value

			"LOCALIZATION", "LOC":
				if current_node == null:
					_add_error(result, line_num, "'%s:' outside of any node" % keyword)
					continue
				current_node.localization_key = value

			_:
				_add_error(result, line_num, "Unknown keyword '%s'" % keyword)

	return result


# --- Choice parsing: "text -> target" or "text" (terminal) ---
static func _parse_choice(value: String, line_num: int, result: ParseResult) -> DialogueChoiceResource:
	var choice := DialogueChoiceResource.new()
	var arrow_idx := value.find("->")
	if arrow_idx < 0:
		# Terminal choice — no target.
		choice.text = value
		return choice
	choice.text = value.substr(0, arrow_idx).strip_edges()
	choice.target_node_id = value.substr(arrow_idx + 2).strip_edges()
	if choice.text.is_empty():
		_add_error(result, line_num, "Empty choice text")
		return null
	return choice


# --- Effect parsing: "kind arg1 arg2 ..." ---
static func _parse_effect(value: String, line_num: int, result: ParseResult) -> DialogueEffect:
	var tokens := value.split(" ", false)
	if tokens.is_empty():
		_add_error(result, line_num, "Empty effect")
		return null
	var effect := DialogueEffect.new()
	effect.kind = tokens[0]
	for j in range(1, tokens.size()):
		effect.args.append(tokens[j])
	return effect


# --- Condition parsing: "[!]kind arg1 arg2 ..." ---
static func _parse_condition(value: String, line_num: int, result: ParseResult) -> DialogueCondition:
	var negated := false
	if value.begins_with("!"):
		negated = true
		value = value.substr(1).strip_edges()
	var tokens := value.split(" ", false)
	if tokens.is_empty():
		_add_error(result, line_num, "Empty condition")
		return null
	var condition := DialogueCondition.new()
	condition.kind = tokens[0]
	condition.negated = negated
	for j in range(1, tokens.size()):
		condition.args.append(tokens[j])
	return condition


static func _add_error(result: ParseResult, line: int, message: String) -> void:
	result.errors.append({"line": line, "message": message})
