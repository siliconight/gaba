@tool
class_name GabaVoNaming
extends RefCounted

## Single source of truth for Gaba's voice-over clip-naming contract.
##
## A line's clip name is what ties three tools together: grunt bakes a file
## under this name, the .dlg node references it, and gool resolves it via
## has_sound(). The name must be identical in all three places — so both the
## grunt exporter ([GabaGruntExport]) and the gool bridge derive it HERE,
## never independently.
##
## Rules:
## - If a node sets `vo:` (voiceover_event_id) explicitly, that name wins.
## - Otherwise the name is derived deterministically as
##   `<dialogue_id>__<node_id>`, sanitised to a filesystem- and bank-safe
##   token (lowercase, [a-z0-9_] only, runs collapsed).
##
## Deterministic means re-exporting the same dialogue produces the same names,
## and every multiplayer client reconstructs the same name for the same node.


## The derived clip name for a node that has no explicit `vo:`.
static func derived_name(dialogue_id: String, node_id: String) -> String:
	var d := _slug(dialogue_id)
	var n := _slug(node_id)
	if d.is_empty():
		return n
	return "%s__%s" % [d, n]


## Resolve the clip name for a node: explicit `vo:` if set, else the derived
## name. Returns "" only when there is genuinely nothing to name.
static func resolve(node, dialogue_id: String) -> String:
	if node == null:
		return ""
	var explicit := str(node.voiceover_event_id).strip_edges()
	if not explicit.is_empty():
		return explicit
	return derived_name(dialogue_id, str(node.node_id))


# Lowercase; keep [a-z0-9]; map every other run to a single underscore; trim.
static func _slug(s: String) -> String:
	var lower := s.to_lower()
	var out := ""
	var prev_us := true  # leading underscores suppressed
	for i in lower.length():
		var c := lower[i]
		var code := c.unicode_at(0)
		var keep := (code >= 0x61 and code <= 0x7A) or (code >= 0x30 and code <= 0x39)
		if keep:
			out += c
			prev_us = false
		elif not prev_us:
			out += "_"
			prev_us = true
	while out.ends_with("_"):
		out = out.substr(0, out.length() - 1)
	return out
