# Gaba

A Godot-native dialogue authoring and runtime system. Write branching NPC conversations in a simple text format, validate them at import time, and play them back in your game with multiplayer-safe execution.

**Status: 0.3.0.** Story Mode authoring, per-choice conditions, friendly validation, runtime, and an optional bridge to the [gool](https://github.com/siliconight/gool) audio engine are working. Editor UX (wizard dock, validation panel UI, preview pane) is next — see [`ROADMAP.md`](ROADMAP.md).

## Features

- **Story Mode authoring** — write screenplay, not graphs. No node IDs required.
- **Per-choice conditions and effects** — different choices appear based on quest state, inventory, faction, anything your game exposes.
- **Designer-friendly validation** — `✓ 4 scenes, 7 choices, 2 endings` in the output panel; clickable validation dock on the roadmap.
- **Templates** — seven starting points under `templates/` for the canonical NPC patterns (greeting, vendor, quest giver, etc.).
- **Runtime-safe resources** — authored files compile to `.res` resources Godot loads instantly.
- **Voice-over optional** — text-only is the happy path; VO fields exist for premium content and stay out of the way otherwise.
- **Audio-engine integrations** — ships an optional bridge to [gool](https://github.com/siliconight/gool) at `addons/gaba/integrations/gool_bridge.gd`. See [`docs/INTEGRATIONS.md`](docs/INTEGRATIONS.md).
- **Multiplayer-aware** — sessions can run in authoritative (server) or replica (client) mode. Server validates choices; client displays.

## Install

Drop `addons/gaba/` into your Godot 4 project's `addons/` folder, then enable it under **Project → Project Settings → Plugins**. The importer and `DialogueManager` autoload register automatically.

## Authoring a dialogue

Create a `.dlg` file. Story Mode looks like this:

```
NPC: Blacksmith

Blacksmith:
Need a blade sharpened?

Player:
Show me your wares.
=> Open Shop

Player:
Any work available?
if: !quest_state iron_debt active
=> Quest Offer

Scene: Open Shop
Blacksmith:
Take a look. Best steel in the valley.
do: open_shop blacksmith_inventory

Scene: Quest Offer
Blacksmith:
I need iron from the old mine.
do: start_quest iron_debt
```

Godot imports it on save. The result is a `DialogueResource` you `load()` like any other Godot resource.

Browse [`templates/`](templates/) for working examples. See [`docs/AUTHORING.md`](docs/AUTHORING.md) for the full reference, including Structured Mode for engineers who want explicit node IDs.

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
    integrations/                   # optional bridges (gool_bridge.gd)
    editor/                         # (future) graph editor, validation panel

examples/dialogues/blacksmith.dlg   # original canonical example
templates/                          # 7 designer-facing starting points
docs/                               # AUTHORING.md, ARCHITECTURE.md, MULTIPLAYER.md,
                                    #   INTEGRATIONS.md, EXTENDING.md
```

## Roadmap

See [`ROADMAP.md`](ROADMAP.md). Next milestone is editor UX: a Create NPC Dialogue wizard, validation panel dock, and preview pane. After that, a visual graph editor as a complementary view of the same data.

## License

MIT. See [`LICENSE`](LICENSE).
