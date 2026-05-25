# Authoring Dialogue (.dlg) Files

This is the format reference for writing dialogue in Gaba. The format is plain text, line-oriented, and designed to be readable, diffable, and forgiving.

## File structure

A file has two sections: a **header** at the top, then **nodes**. Blank lines and `#` comments are allowed anywhere.

```
# header
NPC: blacksmith
START: greeting

# nodes follow
[greeting]
NPC: Welcome.
CHOICE: Bye.
```

## Header

The header sets file-wide metadata. Both directives are required.

| Directive | Meaning |
|-----------|---------|
| `NPC: <id>` | The NPC this dialogue belongs to. Used by gameplay code to look up dialogues by NPC. |
| `START: <node_id>` | The node where playback begins. Must match a `[node_id]` defined later. |

## Nodes

A node starts with `[node_id]` on its own line and continues until the next `[...]` header or end-of-file. Node IDs must be unique within a file.

Inside a node, each line is a directive. The supported directives:

### Dialogue text

```
NPC: Need a blade sharpened?
```

`NPC:` inside a node sets the speaker's line. Each node can have at most one `NPC:` line (use multiple nodes for multi-beat speeches).

### Speaker override

```
SPEAKER: King Aldric
```

Optional. Defaults to the file's NPC id. Useful for cutscenes where multiple characters speak through the same dialogue.

### Choices

```
CHOICE: Show me your wares -> shop
CHOICE: Goodbye.
```

A choice with `-> target` transitions to that node when selected. A choice without `->` is **terminal** — selecting it ends the dialogue. The order of `CHOICE:` lines is the order shown in the UI.

A node with **no choices** is also terminal.

### Conditions

```
CONDITION: has_item iron_ore 3
CONDITION: !quest_state iron_debt complete
```

A condition gates whether the node (or choice it's attached to) is available. Format: `kind` followed by space-separated args. Prefix with `!` to negate.

Conditions on a **node** are evaluated when the runtime considers entering the node. Conditions on a **choice** filter it from the visible choice list. Game code defines what `has_item`, `quest_state`, etc. mean by registering handlers — see [EXTENDING.md](EXTENDING.md).

To attach a condition to a choice rather than the node, put it on a line **before** that choice. (The current MVP applies all `CONDITION:` lines to the node; per-choice conditions are tracked under `choices[i].conditions` and can be set programmatically. A `CHOICE_IF:` directive is on the roadmap.)

### Effects

```
EFFECT: start_quest iron_debt
EFFECT: give_item gold 50
```

Effects fire as gameplay side-effects. Effects on a node fire when the node is entered. Effects on a choice fire when the choice is selected, *before* transitioning to the target.

### Voice-over

```
VO_EVENT: vo_blacksmith_greeting_01
VO_AUDIO: res://audio/vo/blacksmith/greeting.ogg
SUBTITLE: blacksmith.greeting
PLAYBACK: non_interruptible
```

All optional. `VO_EVENT` points at an event in your audio system (e.g. an FMOD/Wwise event or a [gool](https://github.com/) sound name). `VO_AUDIO` is a direct file path. `SUBTITLE` is the localization key for subtitle text (may differ from the node's display text). `PLAYBACK` hints at runtime behavior — values are arbitrary strings interpreted by your UI/audio code.

### Localization

```
LOC: blacksmith.greeting
```

Sets the localization key for the node's display text. If unset, the runtime falls back to the raw `NPC:` text.

### Explicit end

```
END
```

Marks the node as terminal. Equivalent to having no choices, but explicit. Useful when you want a node that has effects but no further branching.

## Complete example

```
NPC: blacksmith
START: greeting

[greeting]
NPC: Need a blade sharpened?
VO_EVENT: vo_blacksmith_greeting_01
SUBTITLE: blacksmith.greeting
CHOICE: Show me your wares -> shop
CHOICE: Any work available? -> quest_offer
CHOICE: Goodbye.

[shop]
NPC: Take a look. Best steel in the valley.
EFFECT: open_shop blacksmith_inventory
CHOICE: Thanks. -> greeting

[quest_offer]
NPC: I need iron from the old mine.
CONDITION: !quest_state iron_debt active
CHOICE: I'll help. -> accept_quest
CHOICE: Maybe later. -> greeting

[accept_quest]
NPC: Good. Come back when it's done.
EFFECT: start_quest iron_debt
END
```

## Validation

The importer runs every file through the validator and surfaces issues in the Godot output panel. Errors block import; warnings let the file import but get logged.

| Code | Severity | Meaning |
|------|----------|---------|
| `missing_npc_id` | error | No `NPC:` at the file top |
| `no_nodes` | error | File contains zero nodes |
| `missing_start` | error | No `START:` directive |
| `broken_start` | error | `START:` points at a nonexistent node |
| `broken_link` | error | A `CHOICE:` target doesn't exist |
| `malformed_condition` / `malformed_effect` | error | Empty kind on a condition or effect |
| `empty_text` | warning | Node has no dialogue text |
| `unreachable` | warning | Node can't be reached from START |
| `missing_localization` | warning | Node has text but no LOC key (only with `require_localization` import option) |
| `suspicious_vo_path` | warning | `VO_AUDIO:` value doesn't contain a `/` |
