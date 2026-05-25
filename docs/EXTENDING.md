# Extending Gaba

Gaba ships zero gameplay logic. Quests, inventory, factions, flags — none of it is in the addon. You wire your game's systems in by registering handlers with `DialogueManager.conditions` and `DialogueManager.effects`.

## Where to register

Do it once at game startup. A typical place is your game's main `Node._ready()` or an autoload that runs before any dialogue can fire:

```gdscript
# autoloads/dialogue_bindings.gd
extends Node

func _ready() -> void:
    _register_conditions()
    _register_effects()

func _register_conditions() -> void:
    DialogueManager.conditions.register("has_item", _has_item)
    DialogueManager.conditions.register("quest_state", _quest_state)
    DialogueManager.conditions.register("faction_at_least", _faction_at_least)
    DialogueManager.conditions.register("flag", _flag)

func _register_effects() -> void:
    DialogueManager.effects.register("start_quest", _start_quest)
    DialogueManager.effects.register("complete_quest", _complete_quest)
    DialogueManager.effects.register("give_item", _give_item)
    DialogueManager.effects.register("remove_item", _remove_item)
    DialogueManager.effects.register("set_flag", _set_flag)
    DialogueManager.effects.register("trigger_event", _trigger_event)
    DialogueManager.effects.register("open_shop", _open_shop)
```

## Handler signatures

```gdscript
# Conditions return bool.
func _has_item(args: PackedStringArray, context: Dictionary) -> bool:
    var item_id := args[0]
    var count := int(args[1]) if args.size() > 1 else 1
    return Inventory.count(item_id) >= count

# Effects return nothing.
func _start_quest(args: PackedStringArray, context: Dictionary) -> void:
    QuestSystem.start(args[0])
```

`args` is the positional argument list from the `.dlg` source. `context` is the Dictionary you pass to `DialogueManager.start_dialogue` — put the player reference, world reference, or whatever else handlers will need to look things up. The runtime doesn't inspect `context`; it's purely your namespace.

## Negated conditions

The parser handles `!` negation in source:

```
CONDITION: !has_item rusty_key
```

Your handler should *not* check for the `!`. The registry inverts the return value itself. Write your handler as if everything were affirmative.

## Defensive defaults

If a `.dlg` file references a condition or effect kind you haven't registered, Gaba logs a warning. For **conditions**, unregistered kinds resolve to `false` (conservative: a missing gate should not open). For **effects**, unregistered kinds are silently skipped. Both behaviors are intentional — they let dialogue authors push content ahead of engineering, and the warnings surface in the editor output panel so nothing stays missing for long.

In production, you may want to fail loudly. Wrap the registry calls or write a CI check that scans `.dlg` files for unknown kinds.

## Asserting the contract at the call site

Before opening a dialogue from gameplay code, sanity-check the resource exists and is loadable. Don't trust that an asset was imported just because the file is on disk:

```gdscript
func talk_to(npc_id: String) -> void:
    var path := "res://dialogues/%s.tres" % npc_id
    if not ResourceLoader.exists(path):
        push_warning("[Dialogue] No dialogue for NPC '%s'" % npc_id)
        return
    var dlg: DialogueResource = load(path)
    assert(dlg != null, "Failed to load dialogue resource for '%s'" % npc_id)
    var session := DialogueManager.start_dialogue(dlg, {"player": self})
    # ... connect signals, then session.start()
```

## Adding new directives

If you find yourself wanting a new `.dlg` directive (e.g. `CAMERA:`, `MOOD:`), think first about whether it belongs in the registry instead. `EFFECT: set_camera close_up` works without parser changes and stays consistent with everything else.

If you really do need a new directive (it's structural, not gameplay), the surgery is small:

1. Add a field to `DialogueNodeResource` (or wherever it belongs).
2. Add a `match` arm in `DialogueParser.parse()`.
3. Add a validator check if the directive has constraints.
4. Use the new field in your runtime / UI code.

The downstream layers don't need changes if the new directive is data, not behavior.
