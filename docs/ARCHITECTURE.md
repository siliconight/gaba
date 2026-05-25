# Architecture

This is a quick map of how Gaba's pieces fit together. Read [AUTHORING.md](AUTHORING.md) first if you want to know how to *use* it; read this if you want to know how it works internally.

## Layers

```
.dlg source
    ↓ (editor reimport)
DialogueParser → DialogueValidator
    ↓
DialogueResource (saved as .res)
    ↓ (game runtime)
DialogueManager
    ↓
DialogueSession (uses ConditionRegistry + EffectRegistry)
    ↓ (signals)
Game UI + gameplay systems
```

The layers are deliberately separable. The parser doesn't import Godot resource APIs; the validator works on resources regardless of how they were produced; the runtime doesn't know about parsing. This means each layer is testable in isolation and replaceable independently (e.g. swap the parser for a visual-editor backend without touching anything downstream).

## What lives where

| Path | Role |
|------|------|
| `resources/` | Pure data classes. No logic beyond convenience accessors. |
| `importer/dialogue_parser.gd` | `.dlg` text → `DialogueResource` (in-memory). Syntactic only. |
| `importer/dialogue_importer.gd` | Glue between Godot's import pipeline and the parser+validator. |
| `validators/dialogue_validator.gd` | Semantic checks (links, reachability, metadata). Works on assembled resources. |
| `runtime/dialogue_manager.gd` | Autoload. Owns registries, creates sessions. |
| `runtime/dialogue_session.gd` | One conversation's worth of state. Drives transitions, fires effects. |
| `runtime/condition_registry.gd` | `kind → Callable` map for game-defined conditions. |
| `runtime/effect_registry.gd` | `kind → Callable` map for game-defined effects. |

## The registry pattern

Gaba intentionally knows nothing about quests, inventory, factions, or any game-specific system. The `EFFECT:` and `CONDITION:` directives in `.dlg` files are just `(kind, args)` tuples. Your game registers handlers at startup:

```gdscript
DialogueManager.effects.register("start_quest", func(args, ctx):
    QuestSystem.start(args[0])
)
DialogueManager.conditions.register("has_item", func(args, ctx) -> bool:
    return Inventory.count(args[0]) >= int(args[1])
)
```

This keeps the addon decoupled from any specific game architecture. It also means Gaba doesn't break when your quest system changes.

## Why .dlg over .tres for authoring

The data model is already Godot resources, so why have a separate text format? Three reasons:

1. **Diffability** — `.tres` is verbose YAML-adjacent format with UUIDs. `.dlg` diffs cleanly.
2. **Authoring speed** — designers type, they don't click through inspector panels.
3. **Merge sanity** — multiple writers can edit the same dialogue without merge hell.

The runtime never touches `.dlg` files. They get compiled to `.res` by the importer at edit time. At runtime, you `load()` the resource like any other.

## Signal flow during playback

```
session.start()
    └─ session._enter_node(start)
         ├─ applies node effects
         └─ emits node_entered

UI: connect to node_entered, call session.get_available_choices()
UI: render choices, wait for player input

session.select_choice(i)
    ├─ emits choice_selected
    ├─ applies choice effects
    └─ session._enter_node(target)
         ├─ applies node effects
         └─ emits node_entered

... until a terminal node is reached, then session.end() fires session_ended.
```

The UI never owns dialogue state. The session does. UI just renders whatever the latest signal carried.

## Multiplayer

See [MULTIPLAYER.md](MULTIPLAYER.md). Short version: server runs an authoritative session, client runs a replica session that doesn't apply effects, and choice selections cross the wire as RPC payloads validated by `session.validate_choice()` before the server forces the replica forward via `force_enter_node()`.

## Extension points (in priority order)

If you want to grow Gaba, these are the seams that were designed for it:

1. **`ConditionRegistry` / `EffectRegistry`** — first stop for game integration. Don't fork the addon to add a quest condition; register a handler.
2. **`DialogueParser`** — swap or extend if you want a different authoring format (YAML, JSON, visual editor output). Anything that produces a valid `DialogueResource` will flow through the rest of the pipeline.
3. **`DialogueValidator`** — add domain-specific checks by calling it after the built-in validation in your import pipeline or a CI step.
4. **`DialogueSession`** — subclass or compose if you need custom transition logic (e.g. timed nodes, parallel branches). The signals are the public contract.

## Non-goals (current)

These are explicitly out of scope for the MVP. Don't try to design around them yet:

- Cinematic sequencing / cameras / animation
- Voice-over file pipeline (the data model holds VO references; routing them to an audio engine is the game's job)
- Procedural / LLM dialogue generation
- C++ / GDExtension rewrite of any subsystem
