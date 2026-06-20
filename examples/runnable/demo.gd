extends Control

## Runnable showcase for the drop-in DialogueBox.
## Open this scene in the editor and press F6 (Run Current Scene).
##
## This is the entire integration: instance the box, load a .dlg, call play().
## Swap in a DialogueTrigger node later to do this with no code at all.

const DIALOGUE_BOX := preload("res://addons/gaba/ui/DialogueBox.tscn")
const DEMO_DLG := "res://examples/runnable/demo.dlg"


func _ready() -> void:
	var dlg := load(DEMO_DLG)
	if dlg == null:
		push_error("Could not load the demo dialogue. Enable the Gaba plugin "
				+ "(Project > Project Settings > Plugins) so .dlg files import.")
		return

	var box := DIALOGUE_BOX.instantiate()
	add_child(box)
	box.finished.connect(_on_finished)
	box.play(dlg)


func _on_finished() -> void:
	print("[demo] dialogue finished")
