# Gaba

**A narrative-first dialogue authoring system for Godot 4.** Writers describe conversations like screenplays; Gaba compiles them into validated, multiplayer-safe runtime dialogue graphs your game plays.

The product principle: writers should think about *what is happening in the story*, not about graph nodes, IDs, or directives. The graph is real — Gaba compiles to it, runtime walks it, multiplayer replicates it — but you do not have to author in it.

**Status: 0.4.3.** Story Mode authoring, per-choice conditions, writer-friendly validation, a "Create NPC Dialogue" wizard dock, nine NPC templates, one-line install, and an optional bridge to the [gool](https://github.com/siliconight/gool) audio engine are working. Conversation flow preview pane is next — see [`ROADMAP.md`](ROADMAP.md).

## Features

- **Story Mode authoring** — write screenplay, not graphs. No node IDs required.
- **Per-choice conditions and effects** — different choices appear based on quest state, inventory, faction, anything your game exposes.
- **Create NPC Dialogue wizard** — Godot dock that copies a template, substitutes your NPC's name throughout, and writes the file. Browse templates at `addons/gaba/templates/`.
- **Designer-friendly validation** — `✓ 4 scenes, 7 choices, 2 endings` in the output panel; clickable validation dock on the roadmap.
- **Templates** — seven starting points under `addons/gaba/templates/` for the canonical NPC patterns (greeting, vendor, quest giver, etc.).
- **Runtime-safe resources** — authored files compile to `.res` resources Godot loads instantly.
- **Voice-over optional** — text-only is the happy path; VO fields exist for premium content and stay out of the way otherwise.
- **Audio-engine integrations** — ships an optional bridge to [gool](https://github.com/siliconight/gool) at `addons/gaba/integrations/gool_bridge.gd`. See [`docs/INTEGRATIONS.md`](docs/INTEGRATIONS.md).
- **Multiplayer-aware** — sessions can run in authoritative (server) or replica (client) mode. Server validates choices; client displays.

## Install

**One-liner** (from your Godot project's root directory):

```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/siliconight/gaba/main/scripts/install.sh | bash
```

```powershell
# Windows / PowerShell
irm https://raw.githubusercontent.com/siliconight/gaba/main/scripts/install.ps1 | iex
```

Pin a version with `GABA_TAG=v0.4.1` (bash) or `$env:GABA_TAG="v0.4.1"` (PowerShell) before the one-liner.

**Manual install:** download a [release archive](https://github.com/siliconight/gaba/releases), extract `addons/gaba/` from it into your project's `addons/` folder.

Either way, enable the plugin under **Project → Project Settings → Plugins**. The importer, `DialogueManager` autoload, and **Gaba** wizard dock register automatically. Look for the **Gaba** tab in the right-side editor docks.

## Authoring a dialogue

Easiest path: open the **Gaba** dock, type your NPC's name, pick a template, click **Create**. The wizard writes a `.dlg` file into `res://dialogues/` (configurable) with your NPC's name substituted throughout.

Manual path: create a `.dlg` file anywhere. Story Mode looks like this:

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

Browse [`addons/gaba/templates/`](addons/gaba/templates/) for working examples — or just use the wizard. See [`docs/AUTHORING.md`](docs/AUTHORING.md) for the full reference, including Structured Mode for engineers who want explicit node IDs.

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
    editor/                         # Gaba wizard dock; validation panel + preview next
    templates/                      # 7 starting points for new NPC dialogues

examples/dialogues/blacksmith.dlg   # original canonical example
docs/                               # AUTHORING.md, ARCHITECTURE.md, MULTIPLAYER.md,
                                    #   INTEGRATIONS.md, EXTENDING.md
```

## Roadmap

See [`ROADMAP.md`](ROADMAP.md). Next: validation panel dock (consumes the same `format_friendly()` data the output panel uses today) and a preview pane that lets writers click through conversations without running the game. After that, a visual graph editor as a complementary view of the same data.

## License

MIT. See [`LICENSE`](LICENSE).
