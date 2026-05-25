# Changelog

All notable changes to Gaba will be documented in this file.

## [0.1.0] - 2026-05-25

Initial MVP.

### Added
- `.dlg` authoring format with header (`NPC:`, `START:`) and node directives (`NPC:`, `CHOICE:`, `CONDITION:`, `EFFECT:`, `VO_EVENT:`, `VO_AUDIO:`, `SUBTITLE:`, `SPEAKER:`, `PLAYBACK:`, `LOC:`, `END:`).
- `DialogueResource`, `DialogueNodeResource`, `DialogueChoiceResource`, `DialogueCondition`, `DialogueEffect` data model.
- `DialogueParser` with non-fatal error collection across the whole file.
- `DialogueValidator` with checks: missing NPC id, missing/broken start, broken links, duplicate node ids (parser-side), unreachable nodes, malformed conditions/effects, empty text, optional missing-localization warning.
- `DialogueImporter` `EditorImportPlugin` that turns `.dlg` files into `.res` resources on save.
- `DialogueManager` autoload with `GabaConditionRegistry` and `GabaEffectRegistry` extension points.
- `DialogueSession` with signal-driven runtime (`node_entered`, `choice_selected`, `effect_triggered`, `session_ended`), per-choice condition filtering, and authoritative/replica modes for multiplayer.
- Documentation: `README`, `docs/AUTHORING.md`, `docs/ARCHITECTURE.md`, `docs/MULTIPLAYER.md`, `docs/EXTENDING.md`.
- Example dialogue: `examples/dialogues/blacksmith.dlg`.

### Not yet implemented
- Visual graph editor with drag-and-drop.
- Validation panel docked in the editor.
- Dialogue preview / playtest window.
- Per-choice condition attachment via a `CHOICE_IF:` directive (currently only achievable programmatically).
- Built-in handlers for any specific game systems (intentional — see `docs/EXTENDING.md`).
