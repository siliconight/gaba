# Changelog

All notable changes to Gaba will be documented in this file.

## [0.2.0] - 2026-05-25

Optional bridge addon for the [gool](https://github.com/siliconight/gool) audio engine.

### Added
- `addons/gaba/integrations/gool_bridge.gd` — optional autoload that routes Gaba voice-over to gool. Implements all four `playback_behavior` modes (interruptible, non_interruptible, skippable, auto_advance). Defensive about gool's API surface: asserts `Gool.has_sound()` before `create_emitter`, prefers gool's `emitter_finished` signal for VO completion but falls back to a Timer driven by `subtitle_timing_data.duration_ms` (or a configurable default) when the signal is absent. Goes inert with one warning if gool isn't installed, so dialogue still plays text-only.
- `docs/INTEGRATIONS.md` — Gaba↔gool field mapping table, bridge activation steps, UI contract for non_interruptible and skippable, and the speculative gool method names the bridge expects.

### Fixed
- Placeholder gool link in `docs/AUTHORING.md` now points at the real repo.

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
