# Integrations

Gaba intentionally does no audio routing of its own — it carries the *data* about voice-over (event ID, audio path, subtitle key, playback behavior) and lets your game route it. This file documents the supported integration patterns.

## Producing the clips (grunt)

The routing patterns below assume the named clips already exist in your audio engine's bank. [grunt](https://github.com/siliconight/grunt) is the sibling tool that makes them: type a line, get a license-clean Vorbis `.ogg`, drop it into `res://`. No mic, no studio, no VO budget, no third-party-sample licensing exposure.

**The clip name is the whole contract.** The name grunt bakes a clip under is the same string you put in a node's `vo:` (`voiceover_event_id`), which is the same name gool resolves through `has_sound()`:

```
grunt bakes          gaba (.dlg)             gool plays
goblin_taunt_01  →   vo: goblin_taunt_01  →  Gool.has_sound("goblin_taunt_01")
```

Match all three and the line speaks; miss any one and the bridge logs a warning and the line plays text-only (see [gool](#gool-audio-engine) below). Today you keep the names in sync by hand — write the line in gaba, bake a clip of the same name in grunt. An exporter that walks a `DialogueResource` and emits a grunt batch job, generating the names on both sides at once, is the obvious next step but isn't built yet.

grunt also covers the non-lexical layer dialogue lines rarely spell out — barks, grunts, screams, efforts — so you can reserve recorded VO for key story moments and let grunt fill the everything-else.

### Exporting a VO job

`GabaGruntExport` turns a dialogue into a grunt `batch` CSV so you don't type each line into grunt by hand and the names match automatically:

```gdscript
GabaGruntExport.export_dlg_folder("res://dialogues", "res://vo_job.csv", {
    "casting": {"Blacksmith": "jersey", "Oracle": "norman"},
    "default_character": "narrator",
})
```

```
grunt batch --csv vo_job.csv --out-dir vo/
```

The CSV is `name,text,character`: column 0 is the clip name from [`GabaVoNaming`](../addons/gaba/integrations/vo_naming.gd) (`<dialogue_id>__<node_id>` unless the node sets `vo:`), column 2 the grunt character from your casting map. Because the bridge derives the *same* name (`auto_derive_vo_names`, on by default), the baked clips play with no `vo:` lines authored — drop the `vo/` folder in, register it with gool, done.

One caveat for now: grunt's `batch` parser splits on commas without honoring quotes, so lines with commas need a grunt build with quoted-field support. Comma-free lines round-trip on any grunt today.

## gool (audio engine)

[gool](https://github.com/siliconight/gool) is a Godot 4 audio engine with prefab nodes, a JSON sound bank, and multiplayer-aware playback. It maps cleanly onto Gaba's voice-over fields.

### Field mapping

| Gaba field on `DialogueNodeResource` | gool counterpart |
|---|---|
| `voiceover_event_id` | A name in your gool sound bank, e.g. `"vo.blacksmith.greeting_01"` — gool hashes it to an `AudioSoundId` at registration |
| `voiceover_audio_path` | A file you register with `RegisterStreamingSoundFromFile` (streaming, since dialogue is too long to pin as PCM) |
| `subtitle_text_key` / `subtitle_timing_data` | Pure UI; gool doesn't touch this. Subtitle timing's `duration_ms` field, if present, is also consulted by the bridge for VO end detection. |
| `playback_behavior` = `"interruptible"` | One-shot event; gool's voice cap evicts on the next VO |
| `playback_behavior` = `"non_interruptible"` | Persistent emitter via `CreateEmitter`; UI must respect [`is_input_blocked`](#bridge-api) |
| `playback_behavior` = `"skippable"` | Persistent emitter; UI calls [`skip_current_vo`](#bridge-api) on player input |
| `playback_behavior` = `"auto_advance"` | Persistent emitter; bridge auto-selects choice 0 when VO ends |
| NPC world position (from `context["npc_position"]`) | Passed to `Gool.create_emitter(name, position)` for spatialization |

A side note: gool ships an `AudioCategory::Dialogue` with a 2-second multiplayer staleness default. That category is the right home for Gaba VO events — if your server commands a node transition under heavy lag, gool drops a 3-second-old VO rather than playing it late.

### The bridge addon

Gaba ships an optional bridge at `addons/gaba/integrations/gool_bridge.gd`. It implements all four `playback_behavior` modes and is defensive about the gool API (asserts `has_sound` before `create_emitter`, falls back to a Timer for VO-end detection if gool doesn't expose an `emitter_finished` signal).

**Activating:**

1. Install both `gaba` and `gool` in your project.
2. Open **Project Settings → Autoload** and add `res://addons/gaba/integrations/gool_bridge.gd` with the node name `GabaGoolBridge`. Load order: AFTER both `DialogueManager` (added by Gaba) and `Gool` (added by gool).
3. From gameplay code, include the NPC's position in the dialogue context:
   ```gdscript
   var session := DialogueManager.start_dialogue(
       dlg, {"npc_position": npc.global_position})
   session.start()
   ```

That's it. Any node with a `voiceover_event_id` will route through gool automatically.

### Bridge API

The bridge exposes two signals and three methods your UI code uses:

```gdscript
# Signals — connect these to drive UI state.
signal vo_started(session, node)
signal vo_finished(session, node)

# Methods.
func is_input_blocked(session) -> bool      # True while a non_interruptible VO is playing
func skip_current_vo(session) -> bool        # Cuts a skippable VO; no-op otherwise
func is_active() -> bool                     # True if bridge found both gool and DialogueManager
```

The non_interruptible and skippable behaviors require UI cooperation. The bridge can't intercept a button click; your dialogue UI must call `is_input_blocked()` before honoring input, and your skip button must call `skip_current_vo()`. A minimal pattern:

```gdscript
func _on_choice_button_pressed(visible_index: int) -> void:
    if GabaGoolBridge.is_input_blocked(_session):
        return  # VO is non_interruptible; wait for vo_finished
    _session.select_choice(visible_index)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_skip"):
        GabaGoolBridge.skip_current_vo(_session)
```

### Speculative method names

The bridge calls these gool methods. If the GDExtension binding uses different spellings, adapt the bridge — every call site uses `has_method` first so missing methods produce warnings rather than crashes:

- `Gool.has_sound(name: String) -> bool` — sound-bank introspection (per v0.66.0)
- `Gool.create_emitter(sound_name: String, position: Vector3) -> int` — persistent emitter handle
- `Gool.destroy_emitter(handle: int, fade_out_ms: float)` — fade out and free
- `Gool.get_sound_duration_ms(name: String) -> float` *(optional)* — used by the Timer fallback
- `Gool.emitter_finished(handle: int)` *(signal, optional)* — preferred over Timer fallback

If gool's actual names diverge, the bridge file is one search-and-replace.

### Bonus: validator integration (not yet implemented)

Gool's `has_sound()` introspection makes a natural validator extension: at import time, check every `voiceover_event_id` in a `.dlg` against gool's sound bank and surface misses as Gaba validation errors. This would catch typos in the editor before the player ever hears a missing line. It's not in the box yet — file an issue or a PR.

## FMOD / Wwise / built-in Godot audio

The bridge pattern is generic. Any audio engine reachable from GDScript can substitute by reimplementing `gool_bridge.gd` against its API. The data Gaba provides — event id, audio path, subtitle key, playback behavior, position from context — is engine-agnostic on purpose.

## Localization

Gaba doesn't ship a localization layer. The fields are there (`localization_key` on nodes and choices, `subtitle_text_key` on nodes for VO subtitles) and you resolve them against Godot's built-in `tr()` or your own translation system in the UI. Treat the raw `text` field as the source-of-truth English (or development) string and look up the key when rendering.
