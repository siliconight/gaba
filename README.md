# Gaba

**A narrative-first dialogue authoring system for Godot 4.** Writers describe conversations like screenplays; Gaba compiles them into validated, multiplayer-safe runtime dialogue graphs your game plays.

The product principle: writers should think about *what is happening in the story*, not about graph nodes, IDs, or directives. The graph is real — Gaba compiles to it, runtime walks it, multiplayer replicates it — but you do not have to author in it.

**Status: 0.4.5.** Story Mode authoring, per-choice conditions, writer-friendly validation, the **Gaba** wizard dock, the **Gaba Play** preview dock, nine NPC templates, one-line install, a `NarrativeHooks` runtime facade, and an optional bridge to the [gool](https://github.com/siliconight/gool) audio engine are working. Want lines *spoken*? [grunt](https://github.com/siliconight/grunt) bakes license-clean VO clips that drop straight in — see [Voices](#voices-optional). See [`ROADMAP.md`](ROADMAP.md) for what's still open.

## The workflow Gaba is built around

1. **Create a character** — click the **Gaba** dock, pick a story archetype (greeting, vendor, quest giver, companion, cinematic, …), name your NPC, click Create.
2. **Write the conversation** — open the file Godot just made and write dialogue in Story Mode: `Blacksmith: Need a blade sharpened?` / `Player: Show me your wares.` No node IDs. No directives.
3. **Preview the conversation** — switch to the **Gaba Play** dock, load the file, click through choices as if you were the player. Toggle gated choices to see the alternate path.
4. **Attach gameplay hooks** — in game code, register handlers for the `if:` and `do:` clauses you used: `NarrativeHooks.register_effect("start_quest", ...)`.
5. **Ship.**

You author intent. Gaba compiles the runtime.

## Start from a template, not a blank file

Templates live at `addons/gaba/templates/` and double as documentation by example. They each demonstrate one canonical NPC pattern:

| Template | Pattern | What it shows |
|---|---|---|
| `01_basic_greeting.dlg` | Greeting | Simplest possible NPC, no quests, text-only |
| `02_vendor.dlg` | Vendor | `do:` effects: `open_shop`, `give_item`, `remove_item` |
| `03_quest_giver.dlg` | Quest Giver | Per-choice `if:` — choices change based on quest state |
| `04_quest_turnin.dlg` | Quest Turn-In | Inventory check + completion |
| `05_ambient_barks.dlg` | Ambient | One-liner NPCs for crowds |
| `06_branching_reputation.dlg` | Reputation | Same NPC, different personalities by faction |
| `07_full_vo_story.dlg` | Full VO | The only template with voice-over fields |
| `08_companion_conversation.dlg` | Companion | Hub-and-spoke party member, returning menu |
| `09_cinematic_conversation.dlg` | Cinematic | Auto-advancing monologue across multiple scenes |

The **Gaba** wizard dock reads its dropdown from this folder — drop your own template `.dlg` files into `addons/gaba/templates/` and they appear automatically. The leading `#` comment lines become the title and description in the dropdown.

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
    # Register game-side handlers once at startup. NarrativeHooks is the
    # designer-facing facade — it routes to DialogueManager.effects /
    # .conditions internally.
    NarrativeHooks.register_effects({
        "start_quest": _start_quest,
        "open_shop": _open_shop,
    })
    NarrativeHooks.register_conditions({
        "quest_state": _quest_state,
    })

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

## Voices (optional)

Gaba is text-first — it runs with no audio at all. When you want lines *spoken*, two sibling tools drop in beside it, and skipping them changes nothing here:

- **[grunt](https://github.com/siliconight/grunt)** — type a line, get a license-clean, game-ready `.ogg`. No mic, no studio, no VO budget.
- **[gool](https://github.com/siliconight/gool)** — the audio engine that plays those clips in 3D at runtime.

**The contract is a name.** A line's `vo:` id is the clip name grunt bakes *and* the sound name gool plays. Match the three and the line speaks; leave any of them out and that line is simply silent — VO is per-line optional, always.

1. Install [gool](https://github.com/siliconight/gool) and enable it (adds the `Gool` autoload).
2. Add `res://addons/gaba/integrations/gool_bridge.gd` as an autoload named `GabaGoolBridge`, ordered **after** both `DialogueManager` and `Gool`. This routes VO automatically; without it, dialogue stays text-only.
3. Bake clips with [grunt](https://github.com/siliconight/grunt) and register them with gool so `Gool.has_sound("name")` is true.

Name the VO on any line you want voiced:

```
Oracle:
Go. Restore what your fathers broke.
vo: oracle_farewell
playback: auto_advance
```

Bake a grunt clip named `oracle_farewell`; the bridge plays it spatially when the line is reached. With `playback: auto_advance`, that clip *also* steps the conversation forward when it ends — so a voiced cutscene needs no advance code at all. A line with no `vo:`, or whose clip gool doesn't have yet, just shows its text.

> Today you match those three names by hand. An exporter that bakes a whole conversation's VO in one pass — names lined up by construction — isn't built yet. Deeper wiring (playback modes, skip, barks, FMOD/Wwise) lives in [`docs/INTEGRATIONS.md`](docs/INTEGRATIONS.md).

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
    templates/                      # 9 starting points for new NPC dialogues

examples/dialogues/blacksmith.dlg   # original canonical example
docs/                               # AUTHORING.md, ARCHITECTURE.md, MULTIPLAYER.md,
                                    #   INTEGRATIONS.md, EXTENDING.md
```

## Roadmap

See [`ROADMAP.md`](ROADMAP.md). Next: validation panel dock (consumes the same `format_friendly()` data the output panel uses today) and a preview pane that lets writers click through conversations without running the game. After that, a visual graph editor as a complementary view of the same data.

## License

MIT. See [`LICENSE`](LICENSE).
