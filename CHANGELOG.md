# Changelog

All notable changes to Gaba will be documented in this file.

## [0.6.1] - 2026-06-20

Branding. Gaba has a logo — a low-poly teal typewriter, fitting for a writer-first tool.

### Added
- **`assets/gaba.png`** (1254×1254 source) plus downscaled variants `gaba_512` / `256` / `128` / `64` / `32` / `16` for README, Asset Library, and editor use.
- README now opens with the logo.
- `project.godot` sets the dev project's window icon to the logo.

## [0.6.0] - 2026-06-20

The VO pipeline gets its missing link. You could route voice-over to gool and bake clips in grunt, but nothing connected the two — you matched clip names by hand. This release makes the names line up by construction.

### Added
- **`GabaVoNaming`** (`addons/gaba/integrations/vo_naming.gd`) — the single source of truth for the clip-name contract. An explicit `vo:` wins; otherwise the name is derived deterministically as `<dialogue_id>__<node_id>`, sanitised to a bank-safe token. Both the exporter and the bridge derive names here, so they can never drift.
- **`GabaGruntExport`** (`addons/gaba/integrations/grunt_export.gd`) — walks a `DialogueResource`, a list of `.dlg` files, or a folder, and writes a [grunt](https://github.com/siliconight/grunt) `batch` CSV (`name,text,character`) with one row per voiced line. Per-speaker casting maps speakers to grunt characters; text is flattened to one line and RFC-4180 quoted. Parses `.dlg` directly via the runtime parser, so it works in-editor or headless. The loop becomes: export → `grunt batch` → drop the folder in.

### Changed
- **Gool bridge derives names too.** When a node has no explicit `vo:`, the bridge now tries `<dialogue_id>__<node_id>` against gool's bank (new `auto_derive_vo_names` export, on by default), so VO baked from the exporter plays with no `vo:` lines authored at all. Missing *derived* clips are silent (line plays as text); a missing *explicit* `vo:` still warns, since that's likely a typo.

### Notes
- grunt's current `batch` CSV parser splits on commas without honoring quotes, so lines containing commas need a grunt build with quoted-field support to round-trip. Comma-free lines work on any grunt today. (grunt-side fix is small and tracked separately.)

## [0.5.0] - 2026-06-20

The missing body. Gaba shipped a dialogue *runtime* but no UI, so getting an authored conversation on screen meant hand-writing a node that loaded the resource, connected signals, built label-and-button UI, and called `select_choice()`. This release ships a drop-in box and a runnable example, so the whole integration is three lines.

### Added
- **Drop-in `DialogueBox`** (`addons/gaba/ui/DialogueBox.tscn` + `dialogue_box.gd`, `class_name GabaDialogueBox`). Instance it, call `play(dlg)`, done — it drives the session and calls `select_choice()` itself. Builds its own layout in code (works even as a bare `Control`), with a typewriter, keyboard/controller choice focus, and `finished` / `line_shown` signals. Handles the cases that bite hand-rolled UIs: bare `=>` continue prompts (advance, don't draw a blank button), terminal lines (kept on screen for dismissal instead of flashing past), and text-only `auto_advance` (stepped by a reading-time timer when no VO is driving it). Gool-bridge aware: honors `is_input_blocked` and `skip_current_vo` when the bridge is active, and is fully functional without it.
- **Runnable example** (`examples/runnable/demo.tscn` + `demo.gd` + `demo.dlg`). Open the scene, press F6, see working dialogue — an auto-advancing intro, a branch, a terminal close — with no game code. Doubles as a copy-paste starting point.
- **README "Drop-in dialogue UI" section** showing the three-line integration as the easy path, ahead of the manual signal-wiring example.

### Changed
- README repo-layout and status updated to mention `ui/` and the example.

## [0.4.6] - 2026-06-20

Discoverability pass for voice-over. The VO *data model* and gool *routing* were already documented, but nothing told a gaba-only user where the clips actually come from — so [grunt](https://github.com/siliconight/grunt), the sibling tool that bakes them, was invisible across the whole doc surface. This iteration closes that gap. Docs only; no code or API changes.

### Added
- **README "Voices (optional)" section** — placed after "Playing a dialogue". Frames the grunt → gaba → gool chain, makes explicit that the shared *clip name* is the only contract, and shows a minimal voiced-line example. Leads with "text-first, audio is optional" so writers who only want text can skip it.
- **`docs/INTEGRATIONS.md` "Producing the clips (grunt)" section** — added above the existing gool routing docs, which had assumed the named clips already existed in the bank. Documents the name contract (`grunt bake` → `vo:` → `Gool.has_sound()`) and that the three names are matched by hand today.

### Changed
- **README Status line** now points to grunt for spoken lines, alongside the existing gool reference.

### Fixed
- Repo-layout comment in the README said "7 starting points" for templates; corrected to "9" to match the status line and the template table.

## [0.4.5] - 2026-05-25

Stakeholder feedback round 3 landing. Five items shipped, two deferred to v0.5 with explicit roadmap entries (implicit scene linking; Writer/Engineer mode toggle), three already covered.

### Added
- **`NarrativeHooks`** — a designer-facing facade over `DialogueManager.effects.register` and `DialogueManager.conditions.register`. Lives at `addons/gaba/runtime/narrative_hooks.gd`. Both old and new APIs work; new docs use the new naming. Bulk-register via `NarrativeHooks.register_effects({...})` from a dictionary. Reframes the runtime wiring as "hooking narrative into gameplay" rather than "registering callbacks on the manager".

### Changed
- **Validator messages pushed further** toward narrative tone per stakeholder examples:
  - "Players never reach this part of the conversation — no other scene's choices lead here." *(was: "This scene is never reached...")*
  - "Choice \"X\" does not continue the conversation — there is no scene called 'Y'." *(was: "leads to 'Y', but no scene by that name exists")*
- **README restructured** around the workflow arc (Create → Write → Preview → Hook → Ship). Templates promoted from a single feature bullet to a primary getting-started path with a full table of nine patterns. README code example switched to `NarrativeHooks`.
- **Wizard tooltips** rewritten as narrative-first descriptions: "The character the player will be talking to" instead of unlabeled fields.
- **Preview empty state** uses warmer language: "Pick a .dlg file above and click Load to walk through the conversation as a player would."

### Deferred (with ROADMAP entries)
- **Implicit scene linking** — drop `=>` for linear progression. Breaking change for current `Player:` semantics; needs migration story. v0.5.
- **Writer Mode / Engineer Mode toggle** — Editor Setting that hides technical surfaces from writers, exposes them to engineers. v0.5.

### Already covered (mentioned in feedback)
- Preview pane (shipped v0.4.4)
- Optional gool bridge as separate addon (shipped v0.2.0)

## [0.4.4] - 2026-05-25

The conversation flow preview pane — the last remaining substantive stakeholder ask. Writers can now click through a `.dlg` like a player and feel the pacing, without launching the game.

### Added
- **`addons/gaba/editor/dialogue_preview_dock.gd`** — a new dock control registered alongside the wizard. Godot auto-tabs it next to the existing **Gaba** tab; look for **Gaba Play**.
- Reparses the `.dlg` file from disk on Load (does NOT use the cached `.res`), so writers see the post-edit state immediately without waiting for Godot's reimport pass.
- Renders speaker name, NPC text (multi-paragraph preserved), and one button per visible choice. Click a choice → advance to its target scene; terminal choices end the conversation; bare `=>` continue prompts render as "(continue)" buttons.
- **Choice gating toggle**: "Show choices with conditions" on (default) shows every choice; off hides choices with `if:` clauses, approximating what a fresh-state player would see. Choices that have conditions get a "(gated)" suffix when visible, so writers can tell them apart.
- **Triggered effects log** — every `do:` effect fires into a green list under the choices, tagged with its source ("choice 'Show me your wares.'" vs "scene quest_offer"). Effects are LOGGED, not executed; the preview has no game state.
- **Reset button** returns to the start scene and clears the effects log.
- **Validation results** from the loaded file are summarised in the status line using the same `format_friendly()` output the importer uses.

### Changed
- `plugin.gd` now registers two dock controls in the right-bottom-left slot. Disable cleanup teardown both. The existing wizard tab is unchanged.

### Caveats
Same as the wizard: editor UI cannot be verified outside a running Godot editor. The code is defensive (null-checks on every parse / file / has_node call, explicit handling of empty/broken/ended states, ScrollContainer for overflowing effect logs) but the first runtime test will tell us whether `add_control_to_dock` with two controls in the same slot tabs them as expected. If only one tab appears, the dock-slot constant probably needs adjusting — easy fix.

### Roadmap items addressed
Stakeholder item #5 (conversation flow preview before a full graph editor) — shipped.

### Still open on the v0.4.x roadmap
- Validation panel dock (consumes the same `format_friendly()` data; the friendly format already lands in the Output panel today)
- Configurable mock handlers (set specific flag values to test specific paths, beyond the binary all-on / all-off toggle)

## [0.4.3] - 2026-05-25

Stakeholder feedback round 2: confirmed Gaba's direction is narrative-first and asked for finishing-touch items on tone, templates, and positioning. This release lands the small ones; preview pane (the big remaining item) stays the next milestone.

### Added
- Two more templates from the stakeholder's canonical list:
  - `08_companion_conversation.dlg` — party-member NPC with hub-and-spoke topics
  - `09_cinematic_conversation.dlg` — scripted auto-advancing monologue across multiple scenes

### Changed
- **Validator messages rewritten in writer-tone.** Instead of `Choice 0 targets nonexistent scene 'shoppe'` you now see `Choice "Show me your wares." leads to 'shoppe', but no scene by that name exists.` Same codes, same severities — only the human-readable strings change. Reachability warnings, empty scenes, malformed conditions/effects, and missing-start errors all got the same treatment.
- README opens with the stakeholder's positioning statement: *A narrative-first dialogue authoring system for Godot 4. Writers describe conversations like screenplays; Gaba compiles them into validated, multiplayer-safe runtime dialogue graphs.*

### Not in this release (and why)
- **Conversation flow preview pane** — the biggest remaining stakeholder ask. Deferred deliberately: it deserves a focused build after the wizard's recent bug-fix train settles, and it's the kind of editor UI that benefits from being designed against confirmed-stable foundations.
- **Natural-language directive aliases** (`only if:` for `if:`, `when selected:` for `do:`). Story Mode's current `if:`/`do:` are already friendlier than `CONDITION:`/`EFFECT:`. Adding longer aliases without removing the short ones risks confusion ("which one should I use?"). Will revisit if writers report friction.
- **Hiding advanced syntax until needed** (item 3 in the feedback). Docs already do this; the text format itself can't hide what isn't typed.

## [0.4.2] - 2026-05-25

### Fixed
- Story-mode parser rejected speaker names containing digits or periods (e.g. `R2-D2:`, `Mr. Smith:`, `Player 1:`, `711 guy:`), causing the file to fail import with a red X in the FileSystem dock. The wizard happily substituted the user's NPC name into the speaker block but the parser then refused to recognize the result.
- Speaker name detection now accepts letters, digits, spaces, apostrophes, hyphens, and periods. The wizard's old-speaker detector (`_is_speaker_like`) was updated in the same way for symmetry, so custom templates with digit-containing speakers also parse correctly.

After pulling, right-click any failed `.dlg` in the FileSystem dock and choose Reimport — no need to recreate the file.

## [0.4.1] - 2026-05-25

Install scripts. No addon code changes.

### Added
- `scripts/install.sh` — one-line installer for Linux / macOS:
  ```
  curl -fsSL https://raw.githubusercontent.com/siliconight/gaba/main/scripts/install.sh | bash
  ```
- `scripts/install.ps1` — one-line installer for Windows / PowerShell:
  ```
  irm https://raw.githubusercontent.com/siliconight/gaba/main/scripts/install.ps1 | iex
  ```
- Both scripts download the GitHub archive, verify `project.godot` exists, refuse to overwrite an existing `addons/gaba/`, copy the addon folder into place, and print next-step instructions. Support `GABA_TAG` env var to pin a version (defaults to `main`).

### Why this is lighter than gool's
gool needs `git clone → cmake → build` because it's a C++ library producing a binary. Gaba is pure GDScript, so the install is just "copy the folder." The script wraps that in one curl invocation.

## [0.4.0] - 2026-05-25

The first piece of editor UX: a "Create NPC Dialogue" wizard dock.

### Added
- **Wizard dock** at `addons/gaba/editor/dialogue_wizard_dock.gd`, registered by `plugin.gd` into the right-bottom-left dock slot. Form fields: NPC name, template picker (descriptions read from each template's leading comment block), save directory (with browse), filename (auto-derived from NPC name, editable). Click Create → reads template, substitutes both the NPC id (slugified) and the speaker display name throughout, writes the file, rescans the filesystem so Godot imports the new `.dlg`, selects it in the FileSystem dock.
- Templates now ship under **`addons/gaba/templates/`** (moved from the top-level `templates/` directory) so they're available at runtime to projects that only install the addon folder. Drop your own `.dlg` templates in the same directory and they appear in the wizard's dropdown automatically — the leading `#` comment lines become the title and description.

### Changed
- `addons/gaba/plugin.gd` now registers/unregisters the wizard dock alongside the importer and autoload.
- Top-level `templates/` directory is removed (its files moved into the addon). If you have a working copy from v0.3.0, run `git rm -r templates` before pulling.

### Caveats
This is editor UI and cannot be validated outside of a running Godot editor. The code is conservative — UI built programmatically (no `.tscn`), every Godot API call null-checked, no clever idioms — but the first test should be installing the addon, opening the editor, and watching for the "Gaba" dock tab. If the dock fails to appear, look in the Output panel for plugin-load errors. See the README for the first-run recipe.

### Roadmap moved to "Done"
- ~~Create NPC Dialogue wizard (dock)~~ — shipped

Still on the v0.4.x roadmap: validation panel dock (consumes the existing `format_friendly()` data), preview/playtest pane.

## [0.3.0] - 2026-05-25

The narrative-designer release. Story Mode authoring format, per-choice conditions/effects, friendly validation output, and seven templates. The product principle now driving Gaba: "I am writing an NPC conversation," not "I am programming a dialogue graph."

### Added
- **Story Mode** authoring format in the parser. Speaker-driven, no node IDs required, no uppercase directives. Auto-detected: any file without `[bracket]` node headers is treated as story mode. The two formats coexist — both compile to the same `DialogueResource`.
- **Per-choice conditions and effects**. Story mode: `if:` and `do:` inside a `Player:` block attach to that choice. Structured mode: `CHOICE_IF:` / `CHOICE_DO:` directives accumulate and attach to the next `CHOICE:`. Unblocks the canonical pattern of "different choices appear based on quest state."
- **`ValidationReport.format_friendly()`** — designer-facing summary (`✓ 4 scenes, 7 choices, 2 endings` etc.) grouped by issue code, emitted to the Godot output panel alongside per-issue push_error/push_warning calls. Designed as the foundation for the eventual editor validation panel; same structured data, just text rendering for now.
- **Templates** under `templates/`: basic greeting, vendor, quest giver, quest turn-in, ambient barks, branching reputation, full VO story. Copy and rename to start a new NPC.
- **`ROADMAP.md`** committing the deferred editor-UX work (wizard dock, validation panel UI, preview pane, graph editor) so it doesn't get lost.
- `Scene:`, `=>`, `if:`, `do:`, `vo:`, `subtitle:`, `playback:` lowercase aliases for story mode.

### Changed
- **`docs/AUTHORING.md` restructured** to lead with Story Mode. Voice-over is now an "Advanced" section at the bottom. Structured Mode remains documented for engineers and tooling-generated files.
- Validator language is now scene-centric ("Scene is not reachable from the start") rather than node-centric.

### Deferred (in ROADMAP.md)
- Create NPC Dialogue wizard dock
- Validation panel UI dock (text version ships now as foundation)
- Preview / playtest pane
- Visual graph editor

These deferred items require an EditorPlugin dock UI that genuinely benefits from being tested interactively in Godot. Shipping them blind would mean shipping mediocre UI. The text-format work in this release lays the data layer they'll consume.

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
