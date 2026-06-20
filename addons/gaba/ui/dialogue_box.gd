class_name GabaDialogueBox
extends Control

## A drop-in dialogue UI for Gaba.
##
## Instance DialogueBox.tscn, call play(dlg), and it runs the whole
## conversation for you — speaker name, typewriter text, choice buttons,
## continue prompts — calling DialogueSession.select_choice() so your game
## doesn't have to. No glue code.
##
## Minimal use:
## [codeblock]
## var box := preload("res://addons/gaba/ui/DialogueBox.tscn").instantiate()
## add_child(box)
## box.play(load("res://dialogues/blacksmith.dlg"))
## box.finished.connect(func(): print("done"))
## [/codeblock]
##
## Voice-over is optional and automatic. If the GabaGoolBridge autoload is
## present and active, VO plays and the non_interruptible / skippable /
## auto_advance behaviors are honored. If it isn't, text still works, and
## text-only auto_advance lines are stepped forward by a reading-time timer
## here so cutscenes play without any audio at all.

## Emitted once the conversation has fully closed and the box has hidden.
signal finished
## Emitted each time a new line is shown. Handy for portraits, camera, SFX.
signal line_shown(node)

@export_group("Typewriter")
## Characters revealed per second. 0 reveals the whole line instantly.
@export var chars_per_second: float = 45.0

@export_group("Auto-advance (text-only)")
## Extra seconds an auto_advance line lingers after it finishes revealing.
## Only used when the gool bridge ISN'T driving timing for this line.
@export var auto_advance_hold: float = 0.6
## Minimum seconds an auto_advance line stays up, regardless of length.
@export var auto_advance_min: float = 1.2

@export_group("Input")
## Input action that advances / confirms. If the action doesn't exist in the
## project, falls back to Space / Enter / left-click.
@export var advance_action: StringName = &"ui_accept"

# --- session state ---
var _session: DialogueSession
var _bridge: Node
var _current_node
var _full_text: String = ""
var _typing: bool = false
var _type_progress: float = 0.0
var _session_over: bool = false
var _auto_timer: float = -1.0

# --- built UI ---
var _panel: PanelContainer
var _speaker_label: Label
var _text_label: RichTextLabel
var _choices_box: VBoxContainer
var _continue_hint: Label
var _choice_buttons: Array[Button] = []


func _ready() -> void:
	_build_ui()
	hide()
	set_process(false)
	set_process_unhandled_input(false)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Start playing [param dialogue]. Returns the DialogueSession so callers can
## connect to its effect/choice signals if they want; you don't need to.
func play(dialogue: DialogueResource, context: Dictionary = {}) -> DialogueSession:
	if dialogue == null:
		push_error("[GabaDialogueBox] play() called with a null dialogue")
		return null
	stop()

	_bridge = _resolve_bridge()
	if _bridge and _bridge.has_signal("vo_finished") \
			and not _bridge.vo_finished.is_connected(_on_vo_finished):
		_bridge.vo_finished.connect(_on_vo_finished)

	_session = DialogueManager.start_dialogue(dialogue, context)
	_session.node_entered.connect(_on_node_entered)
	_session.session_ended.connect(_on_session_ended)
	_session_over = false

	show()
	set_process(true)
	set_process_unhandled_input(true)
	_session.start()
	return _session


## Stop and hide the box. Safe to call any time; does not emit [signal finished].
func stop() -> void:
	var s := _session
	_disconnect_session()
	_session = null
	if s and not s.is_ended():
		DialogueManager.end_dialogue(s)
	_current_node = null
	_typing = false
	_auto_timer = -1.0
	_session_over = false
	set_process(false)
	set_process_unhandled_input(false)
	hide()


# ---------------------------------------------------------------------------
# Session callbacks
# ---------------------------------------------------------------------------

func _on_node_entered(node) -> void:
	_current_node = node
	_clear_choices()
	var speaker := str(node.speaker)
	_speaker_label.text = speaker
	_speaker_label.visible = not speaker.is_empty()
	_full_text = str(node.text)
	_begin_typewriter()
	line_shown.emit(node)


func _on_session_ended() -> void:
	# A terminal node ends the session the instant it's entered, so this fires
	# right after _on_node_entered for the final line. Keep that line on screen
	# and let the player dismiss it — never auto-close here.
	_session_over = true
	if not _typing:
		_continue_hint.visible = true


func _on_vo_finished(session, _node) -> void:
	if session == _session:
		_set_choices_disabled(false)


# ---------------------------------------------------------------------------
# Typewriter
# ---------------------------------------------------------------------------

func _begin_typewriter() -> void:
	_text_label.text = _full_text
	_continue_hint.visible = false
	var total := _text_label.get_total_character_count()
	if chars_per_second <= 0.0 or total == 0:
		_text_label.visible_characters = -1
		_finish_typewriter()
		return
	_text_label.visible_characters = 0
	_type_progress = 0.0
	_typing = true


func _finish_typewriter() -> void:
	_typing = false
	_text_label.visible_characters = -1

	var available: Array = []
	if _session != null:
		available = _session.get_available_choices()

	# Build a button per *labeled* choice. Empty-text choices are bare `=>`
	# continue prompts, not player decisions — they advance, they don't show.
	_clear_choices()
	for i in available.size():
		var label := str(available[i].text).strip_edges()
		if label.is_empty():
			continue
		var btn := Button.new()
		btn.text = label
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_choice_pressed.bind(i))  # i = visible index
		_choices_box.add_child(btn)
		_choice_buttons.append(btn)

	if _choice_buttons.size() > 0:
		_continue_hint.visible = false
		_choice_buttons[0].grab_focus()
		# Hold choices until a non_interruptible VO has finished.
		if _input_blocked():
			_set_choices_disabled(true)
	else:
		_continue_hint.visible = true
		if _should_auto_advance():
			var read := float(_full_text.length()) / maxf(chars_per_second, 1.0)
			_auto_timer = maxf(auto_advance_min, read + auto_advance_hold)


func _process(delta: float) -> void:
	if _typing:
		_type_progress += delta * chars_per_second
		var total := _text_label.get_total_character_count()
		if int(_type_progress) >= total:
			_finish_typewriter()
		else:
			_text_label.visible_characters = int(_type_progress)
	elif _auto_timer >= 0.0:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			_auto_timer = -1.0
			_advance_auto()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _is_advance_pressed(event):
		return
	accept_event()

	# 1) Still typing → reveal the rest instantly (and hurry skippable VO).
	if _typing:
		_finish_typewriter()
		if _bridge and _current_node and str(_current_node.playback_behavior) == "skippable" \
				and _bridge.has_method("skip_current_vo"):
			_bridge.skip_current_vo(_session)
		return

	# 2) Blocked by a non_interruptible VO → ignore.
	if _input_blocked():
		return

	# 3) Conversation already ended → the last line was on screen; dismiss now.
	if _session_over or _session == null or _session.is_ended():
		_close()
		return

	# 4) No labeled choices → this is a continue prompt; step forward.
	#    (When labeled choices ARE present, a focused Button consumes the
	#     accept itself, so we only reach here for continue prompts.)
	var available: Array = _session.get_available_choices()
	if _count_labeled(available) == 0:
		if available.size() > 0:
			_session.select_choice(0)
		else:
			_close()


func _on_choice_pressed(visible_index: int) -> void:
	if _input_blocked():
		return
	if _session and not _session.is_ended():
		_session.select_choice(visible_index)


func _advance_auto() -> void:
	if _session == null or _session.is_ended():
		_close()
		return
	var available: Array = _session.get_available_choices()
	if available.size() > 0:
		_session.select_choice(0)
	else:
		_close()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _close() -> void:
	var was_open := visible
	stop()
	if was_open:
		finished.emit()


func _should_auto_advance() -> bool:
	if _current_node == null or _session_over:
		return false
	if str(_current_node.playback_behavior) != "auto_advance":
		return false
	# If the bridge is handling VO for this line, it auto-advances on VO end —
	# we must not also advance, or we'd skip a line.
	if _bridge != null and _current_node.has_voiceover():
		return false
	return true


func _input_blocked() -> bool:
	return _bridge != null and _session != null \
			and _bridge.has_method("is_input_blocked") \
			and _bridge.is_input_blocked(_session)


func _count_labeled(available: Array) -> int:
	var n := 0
	for c in available:
		if not str(c.text).strip_edges().is_empty():
			n += 1
	return n


func _set_choices_disabled(disabled: bool) -> void:
	for b in _choice_buttons:
		b.disabled = disabled


func _is_advance_pressed(event: InputEvent) -> bool:
	if advance_action != &"" and InputMap.has_action(advance_action):
		return event.is_action_pressed(advance_action)
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	if event is InputEventMouseButton and event.pressed:
		return event.button_index == MOUSE_BUTTON_LEFT
	return false


func _resolve_bridge() -> Node:
	var b := get_node_or_null(^"/root/GabaGoolBridge")
	if b == null:
		return null
	if b.has_method("is_active") and not b.is_active():
		return null
	return b


func _clear_choices() -> void:
	for c in _choices_box.get_children():
		c.queue_free()
	_choice_buttons.clear()


func _disconnect_session() -> void:
	if _session == null:
		return
	if _session.node_entered.is_connected(_on_node_entered):
		_session.node_entered.disconnect(_on_node_entered)
	if _session.session_ended.is_connected(_on_session_ended):
		_session.session_ended.disconnect(_on_session_ended)


# ---------------------------------------------------------------------------
# UI construction (built in code so the box works even as a bare Control)
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.anchor_top = 1.0
	_panel.offset_left = 24.0
	_panel.offset_right = -24.0
	_panel.offset_top = -240.0
	_panel.offset_bottom = -24.0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_speaker_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.custom_minimum_size = Vector2(0, 72)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_text_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_choices_box)

	_continue_hint = Label.new()
	_continue_hint.text = "▼"
	_continue_hint.modulate = Color(1, 1, 1, 0.55)
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_hint.visible = false
	vbox.add_child(_continue_hint)
