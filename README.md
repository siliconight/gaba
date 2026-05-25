# Gaba

A Godot-native dialogue authoring and runtime system. Write branching NPC conversations in a simple text format, validate them at import time, and play them back in your game with multiplayer-safe execution.

**Status: 0.1.0 — MVP.** Text-based authoring, importer, validator, and runtime are working. The visual graph editor is not yet built.

## Features

- **Text-first authoring** — `.dlg` files are plain text, diff-friendly, and merge cleanly.
- **Compile-time validation** — broken links, unreachable nodes, malformed effects, and missing metadata are caught at import.
- **Runtime-safe resources** — authored files become `.res` resources Godot loads instantly at runtime.
- **Conditions and effects** — gameplay hooks via a registry pattern. Gaba doesn't know about quests or inventory; your game registers handlers and Gaba calls them.
- **Voice-over optional** — every node can have a VO event ID, audio path, and subtitle key, or none of those. Text-only dialogue is a first-class workflow.
- **Multiplayer-aware** — sessions can run in authoritative (server) or replica (client) mode. Server validates choices; client displays.

## Install

Drop `addons/gaba/` into your Godot 4 project's `addons/` folder, then enable it under **Project → Project Settings → Plugins**. The importer and `DialogueManager` autoload register automatically.

## Authoring a dialogue

Create a `.dlg` file anywhere in your project:

```
NPC: blacksmith
START: greeting

[greeting]
NPC: Need a blade sharpened?
CHOICE: Show me your wares -> shop
CHOICE: Goodbye.

[shop]
NPC: Take a look. Best steel in the valley.
EFFECT: open_shop blacksmith_inventory
CHOICE: Thanks. -> greeting
```

Godot will import it on save. You'll get a `DialogueResource` you can `load()` like any other Godot resource.

See [`docs/AUTHORING.md`](docs/AUTHORING.md) for the full grammar.

## Playing a dialogue

```gdscript
extends Node

func _ready() -> void:
    # Register game-side handlers once at startup.
    DialogueManager.effects.register("start_quest", _start_quest)
    DialogueManager.effects.register("open_shop", _open_shop)
    DialogueManager.conditions.register("quest_state", _quest_state)

func talk_to_blacksmith() -> void:
    var dlg: DialogueResource = load("res://dialogues/blacksmith.tres")
    var session := DialogueManager.start_dialogue(dlg, {"player": self})
    session.node_entered.connect(_on_node_entered)
    session.session_ended.connect(_on_dialogue_done)
    session.start()

func _on_node_entered(node: DialogueNodeResource) -> void:
    print("%s: %s" % [node.speaker, node.text])
    var choices := DialogueManager.get_active_sessions()[0].get_available_choices()
    for i in choices.size():
        print("  %d) %s" % [i, choices[i].text])

func _start_quest(args: PackedStringArray, ctx: Dictionary) -> void:
    print("Quest started: %s" % args[0])

func _open_shop(args: PackedStringArray, ctx: Dictionary) -> void:
    pass

func _quest_state(args: PackedStringArray, ctx: Dictionary) -> bool:
    return false
```

## Repository layout

```
addons/gaba/
    plugin.cfg                      # addon manifest
    plugin.gd                       # EditorPlugin entry point
    resources/                      # data model (DialogueResource, etc.)
    importer/                       # .dlg → Resource pipeline
    validators/                     # semantic validation
    runtime/                        # DialogueManager + DialogueSession + registries
    editor/                         # (future) graph editor, validation panel

examples/dialogues/blacksmith.dlg   # canonical example
docs/                               # AUTHORING.md, ARCHITECTURE.md, MULTIPLAYER.md
```

## Roadmap

The MVP is text-based authoring. Future work, in roughly priority order:

- Visual graph editor with drag-and-drop linking
- Validation panel docked in the editor
- Dialogue preview / playtest window
- NPC assignment tooling (browse all dialogues by NPC)
- Localization export pipeline
- Built-in condition/effect handlers for common game systems

## License

MIT. See [`LICENSE`](LICENSE).
