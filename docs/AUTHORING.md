# Authoring Dialogue

This is the writer's reference for creating dialogue in Gaba. Two formats are supported in `.dlg` files: **Story Mode** (the default, designer-friendly) and **Structured Mode** (explicit IDs, useful for engineers and code-generated files). Both compile to the same runtime data — pick whichever fits the file.

## Story Mode (recommended)

Story Mode reads as a screenplay. You write what the NPC says, what the player can answer, and where each answer leads. Gaba generates the underlying graph for you.

```
NPC: Blacksmith

Blacksmith:
Need a blade sharpened?

Player:
Show me your wares.
=> Open Shop

Player:
Any work available?
=> Quest Offer

Scene: Open Shop
Blacksmith:
Take a look. Best steel in the valley.

Scene: Quest Offer
Blacksmith:
I need iron from the old mine.
```

That's the whole format. The rules in detail:

### The header

The first line names the NPC:

```
NPC: Blacksmith
```

That's it for the header. The first scene begins implicitly with the first speaker line that follows.

### Speakers

A speaker line starts a block:

```
Blacksmith:
Need a blade sharpened?
```

The speaker name can be anything except a reserved keyword. The text after the colon (and on subsequent lines) is what they say. Blank lines within a block become paragraph breaks in the displayed text. The block ends at the next speaker line, the next `Scene:`, or the next `=>`.

### Player choices

A `Player:` block is treated as a choice on the most recent NPC line, not as a new beat. Multiple `Player:` blocks in a row accumulate as multiple choices:

```
Blacksmith:
Need a blade sharpened?

Player:
Show me your wares.
=> Open Shop

Player:
Any work available?
=> Quest Offer
```

The order of `Player:` blocks is the order shown in the UI.

### Targets

`=>` points a Player choice (or an NPC line) at the scene to advance to:

```
Player:
Show me your wares.
=> Open Shop
```

`Open Shop` is the scene name, not an ID. Gaba slugifies it (`open_shop`) for the underlying graph. A Player block without `=>` is **terminal** — picking it ends the dialogue.

A bare `=>` after an NPC line (no `Player:` between them) creates a "Continue" prompt — useful for cutscene-style sequences:

```
Scene: Beat One
Oracle:
You have travelled far.
=> Beat Two

Scene: Beat Two
Oracle:
And further still you must go.
```

### Scenes

`Scene: <Name>` declares a new scene. Scene names are designer-friendly text:

```
Scene: Quest Offer
Blacksmith:
I need iron from the old mine.
```

The slugified name (`quest_offer` here) is what `=>` targets resolve against — both `=> Quest Offer` and `=> quest_offer` work.

### Per-choice conditions

`if:` inside a `Player:` block makes that choice appear only when the condition passes:

```
Player:
How is the mine job going?
if: quest_state iron_debt active
=> Mine Update
```

Multiple `if:` lines act as AND (all must pass). Prefix with `!` to negate:

```
Player:
Any work available?
if: !quest_state iron_debt active
if: !quest_state iron_debt complete
=> Quest Offer
```

Conditions are evaluated at runtime by handlers your game registers with `DialogueManager.conditions`. Gaba doesn't ship a quest system, inventory, or faction logic — you wire those in. See [EXTENDING.md](EXTENDING.md).

### Per-choice effects

`do:` inside a `Player:` block fires a gameplay effect when the choice is selected:

```
Player:
I will help.
do: start_quest iron_debt
=> Quest Accepted
```

Effects fire **before** the scene transition, so the target scene's conditions see the post-effect state. Multiple `do:` lines fire in order.

### Node-level conditions and effects

`if:` and `do:` outside a `Player:` block apply to the current scene rather than a choice. Less common but useful for "this scene triggers an event when entered":

```
Scene: Quest Accepted
Blacksmith:
Good. Come back when it is done.
do: log_journal "Iron from the mine"
```

### Comments

Lines starting with `#` are comments:

```
# Quartermaster — only available after the bandit camp questline opens
NPC: quartermaster
```

## Templates

Gaba ships starting points under `templates/`:

| File | What it shows |
|------|---------------|
| `01_basic_greeting.dlg` | Bare-minimum greeting NPC, no quests |
| `02_vendor.dlg` | Shop NPC with `do:` effects (open_shop, give_item) |
| `03_quest_giver.dlg` | Per-choice `if:` to show different options by quest state |
| `04_quest_turnin.dlg` | Inventory check + quest completion |
| `05_ambient_barks.dlg` | Tiny one-line NPCs |
| `06_branching_reputation.dlg` | Same NPC, three personalities by faction standing |
| `07_full_vo_story.dlg` | The advanced one — voice-over and subtitle keys |

Copy any of these to your `dialogues/` folder, rename, and rewrite the lines.

## Structured Mode

Structured Mode uses explicit `[node_id]` headers and uppercase directives. Useful when:

- You want full control over node IDs (e.g. tooling generates `.dlg` files)
- You're an engineer who finds the explicit form clearer
- You're integrating with an existing dialogue graph format

```
NPC: blacksmith
START: greeting

[greeting]
NPC: Need a blade sharpened?
CHOICE: Show me your wares -> shop
CHOICE: Any work available? -> quest_offer

[shop]
NPC: Take a look. Best steel in the valley.
EFFECT: open_shop blacksmith_inventory
CHOICE: Thanks -> greeting

[quest_offer]
NPC: I need iron from the old mine.
CHOICE_IF: !quest_state iron_debt active
CHOICE: I'll help -> accept_quest
CHOICE: Maybe later -> greeting

[accept_quest]
NPC: Good. Come back when it's done.
EFFECT: start_quest iron_debt
END
```

Auto-detection: a file is treated as Structured Mode if any line is a bare `[identifier]` header, otherwise Story Mode.

### Structured directives reference

| Directive | Effect |
|-----------|--------|
| `NPC: <id>` (file head) | Sets the dialogue's NPC id |
| `START: <node_id>` | Sets the starting node |
| `[<node_id>]` | Begins a node |
| `NPC: <text>` (in a node) | Sets the node's dialogue text |
| `SPEAKER: <name>` | Overrides the speaker name (default = NPC id) |
| `CHOICE: <text> -> <target>` | Adds a choice with a transition target |
| `CHOICE: <text>` | Adds a terminal choice (ends the dialogue) |
| `CHOICE_IF: <condition>` | Attaches a condition to the *next* CHOICE: |
| `CHOICE_DO: <effect>` | Attaches an effect to the *next* CHOICE: |
| `CONDITION: <kind> <args...>` | Node-level condition (prefix `!` to negate) |
| `EFFECT: <kind> <args...>` | Node-level effect |
| `LOC: <key>` | Localization key for the node's text |
| `END` | Marks the node as terminal explicitly |

Plus the voice-over directives — see the next section.

## Advanced: voice-over

Most NPCs don't need voice-over and you can skip this section entirely. For premium story content with recorded audio, attach VO data per scene.

### Story Mode

```
Oracle:
You have travelled far.
vo: vo_oracle_intro_01
subtitle: oracle.intro
playback: non_interruptible
```

### Structured Mode

```
[oracle_intro]
NPC: You have travelled far.
VO_EVENT: vo_oracle_intro_01
SUBTITLE: oracle.intro
PLAYBACK: non_interruptible
```

### Fields

| Field | Meaning |
|-------|---------|
| `vo:` / `VO_EVENT:` | Sound name in your audio engine's bank (e.g. a [gool](https://github.com/siliconight/gool) sound name, FMOD event, Wwise event) |
| `VO_AUDIO:` | Direct file path; alternative to `VO_EVENT:` for projects without a bank |
| `subtitle:` / `SUBTITLE:` | Localization key for subtitle text (may differ from display text) |
| `playback:` / `PLAYBACK:` | Behaviour hint: `interruptible`, `non_interruptible`, `skippable`, `auto_advance` |

Playback behaviour is interpreted by your runtime / UI / audio code. If you're using gool, the bridge addon at `addons/gaba/integrations/gool_bridge.gd` handles all four behaviours — see [INTEGRATIONS.md](INTEGRATIONS.md).

## Validation

The importer runs every file through the validator and surfaces a friendly summary in the Godot output panel:

```
[Gaba] res://dialogues/blacksmith.dlg
✓ 4 scenes, 7 choices, 2 endings
⚠ 1 unreachable scene
  - [mine_update] Scene is not reachable from the start
```

Errors block import; warnings let the file import but get logged. Issues:

| Code | Severity | Meaning |
|------|----------|---------|
| `missing_npc_id` | error | No `NPC:` at the file top |
| `no_nodes` | error | File contains zero scenes |
| `missing_start` | error | No start scene declared or inferred |
| `broken_start` | error | Start scene doesn't exist |
| `broken_link` | error | A choice target doesn't exist |
| `malformed_condition` / `malformed_effect` | error | Empty kind on a condition or effect |
| `empty_text` | warning | Scene has no dialogue text |
| `unreachable` | warning | Scene can't be reached from the start |
| `missing_localization` | warning | Scene has text but no LOC key (only with `require_localization` import option) |
| `suspicious_vo_path` | warning | `VO_AUDIO:` value doesn't contain a `/` |

A clickable validation panel inside the editor is on the roadmap — see [ROADMAP.md](../ROADMAP.md).
