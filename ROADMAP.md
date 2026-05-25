# Roadmap

What Gaba is building and what it's deferring, in priority order. This file is the canonical commitment list — items here are real plans, not wishes.

## v0.4.x — editor UX

The product principle driving these items: **"I am writing an NPC conversation," not "I am programming a dialogue graph."** The text-format work shipped in v0.3.0 reduced the cognitive load of authoring; v0.4 brings the same reduction inside the Godot editor.

### Create NPC Dialogue wizard (dock)

A button in a Gaba dock that runs through:

1. NPC name (free text)
2. Dialogue type — Greeting / Vendor / Quest Giver / Quest Turn-In / Ambient Bark / Reputation-Branching / Full VO Story
3. Save location (defaults to `res://dialogues/`)
4. Click Create → copies the matching template from `templates/`, renames the NPC, opens the file in the script editor

Why: removes first-use friction. A writer should not need to learn the `.dlg` format before writing their first NPC.

### Validation panel (dock)

A panel that shows the friendly validation report (already produced by `ValidationReport.format_friendly()` as of v0.3.0) with:

- Tree view of scenes / choices / endings (counts)
- Errors and warnings grouped by code (also already structured)
- Each issue clickable → jumps to the line in the script editor
- Re-runs on file save / reimport

Why: errors should feel like editor squiggles, not Godot's output panel needles.

### Preview / playtest pane (dock)

A pane that lets a writer click through the conversation without running the game:

- Loads a `DialogueResource` (or live-reparses a `.dlg`)
- Renders NPC line + visible choices
- Click a choice → advance
- Mock condition/effect handlers so per-choice `if:` filtering works without game state
- Reset button to start over

Why: writers need to feel the conversation pacing. A graph view shows structure; a preview shows experience.

## v0.5.x — graph editor (visible only when wanted)

A visual node graph as a *complementary* view of the same data, not a replacement for text editing. Bidirectional: edit text, see the graph update; drag nodes, see the text update.

Open question to answer in design: does the graph view earn its complexity? Many narrative tools start with graphs and end up with writers wishing they had text. Gaba starts text-first deliberately — the graph view ships only if the data shape genuinely benefits from spatial layout (likely yes for complex quest webs; less obvious for linear cutscenes).

## Smaller items, no scheduled milestone

These don't fit neatly into a milestone but are good-faith TODOs:

- **Localization export pipeline** — emit a CSV of all `text` / `subtitle:` / `LOC:` keys for translators, re-import translated CSV back as overrides.
- **Validator hook for the gool sound bank** — at import time, use `Gool.has_sound()` to verify every `vo:` reference exists. Catches typo VOs in the editor before runtime.
- **Conversation health metrics** beyond the existing counts: average branching factor, longest path, dead-end count.
- **Search across all `.dlg` files** — find every dialogue that mentions a quest id, an item id, or a flag.
- **`CHOICE_IF: + CHOICE_IF:` AND/OR semantics** — currently all `if:` lines on a choice are AND. An explicit OR group (perhaps `if any:` block) would help complex branching without forcing designers to factor out shared text into helper scenes.
- **Story Mode multiline NPC paragraphs** — currently a `Scene:` break creates two nodes; sometimes you want one node with two paragraphs from the same speaker. The data model already supports it (just a `\n\n` inside `text`); only the format needs a convention.

## Done

### v0.3.0

- Story Mode authoring format (speaker-driven, no node IDs required)
- Per-choice conditions and effects (`if:` / `do:` in story mode; `CHOICE_IF:` / `CHOICE_DO:` in structured)
- Friendly validation report (`ValidationReport.format_friendly()`) emitted to the output panel
- Templates under `templates/` for the seven canonical NPC patterns
- Docs restructured: story mode first, voice-over demoted to "Advanced"

### v0.2.0

- Optional bridge addon to the [gool](https://github.com/siliconight/gool) audio engine
- `docs/INTEGRATIONS.md` with field mapping and UI contracts

### v0.1.0

- Initial MVP — structured `.dlg` format, parser, validator, importer, `DialogueManager` autoload, `DialogueSession` with multiplayer-aware authoritative/replica modes

## Explicitly not on the roadmap

To keep scope honest, these are deliberately out:

- **Cinematic sequencing / cameras / animation timing** — that's a separate tool's job. Gaba feeds events to your cinematic system via `do:`; it does not drive cameras.
- **Voice-over file pipeline** — Gaba carries VO references, it does not record / mix / convert audio. Use gool, FMOD, or Wwise.
- **Procedural / LLM dialogue generation** — out of scope by design.
- **Live multiplayer co-authoring** — out of scope. Multiplayer is for runtime authority, not editor collaboration.
- **C++ / GDExtension rewrite of any subsystem** — only revisited if profiling shows a real bottleneck. The bottleneck for Gaba is authoring friction, not runtime cost.
