# Multiplayer Authority

Gaba is designed for a server-authoritative model: the client displays dialogue and sends choice intents; the server validates everything and drives state forward. This document is the pattern, not a built-in implementation — wiring it up requires game-side networking code that Gaba doesn't ship.

## The model

```
CLIENT                                  SERVER
──────                                  ──────
Player interacts with NPC
    └─ RPC: "request dialogue X with NPC Y"
                                        ├─ Check proximity, NPC state
                                        ├─ start_dialogue(authoritative=true)
                                        └─ RPC back: "open dialogue X at node N"
session = start_dialogue(
    authoritative=false)
session.force_enter_node(N)
    └─ UI renders node N

Player clicks choice index i (visible)
    └─ RPC: "select choice i in session S"
                                        ├─ session.validate_choice(i)?
                                        ├─ If no: ignore (or reject)
                                        ├─ If yes: session.select_choice(i)
                                        │   ├─ applies effects (quest state, etc.)
                                        │   └─ transitions
                                        └─ RPC back: "now at node M"
session.force_enter_node(M)
    └─ UI renders node M
```

The replica session never applies effects. The authoritative session applies them once. There's no danger of an effect firing twice or out of order.

## What the server validates

Per TDD §14, on every choice request:

1. **Proximity** — is the player close enough to the NPC? Cheap to check from positions you already track.
2. **Active session** — is there actually a dialogue running for this player? Reject orphan requests.
3. **Current node** — does the client's view of "what node am I on" match the server's? Reject stale requests.
4. **Choice index validity** — `session.validate_choice(i)` returns true only if `i` is in range of the *visible* choices (conditions evaluated). This catches a client trying to pick a choice it shouldn't be able to see.
5. **Conditions** — re-evaluate the choice's conditions against authoritative game state. The visible-choice filter already does this; the validation is just a confirmation that nothing changed between the client's render and the request arriving.
6. **Effects** — apply them through the registry. Because the registry handlers run on authoritative game state (quest system, inventory, etc.), they're inherently correct.

## Why filter visible choices on the client too

For UX. Greyed-out / hidden choices feel correct; an error after clicking feels broken. Both sides evaluate conditions; the client's evaluation is advisory and the server's is binding.

If a condition involves data only the server knows (e.g. faction reputation hidden from the player), the client just won't see those conditions in its registry — they'll resolve to false, hiding the choice — which is the right behavior.

## Indexing choices: visible vs raw

`session.get_available_choices()` returns the *filtered* choice list (conditions evaluated). The index in this list is what crosses the wire, not the raw position in `current_node.choices`. This means client and server agree on what "choice 2" means, regardless of which choices were filtered out.

## Failure modes the model handles

- **Lag-induced stale request**: client sends "select 1" but the server already advanced past that node. Server's `validate_choice` returns false because the session's current node is different. Server ignores or replies with a correction.
- **Client tampering**: client crafts a request to enter a node it shouldn't be able to reach. Choice index is out of range or refers to a condition-failed choice. `validate_choice` returns false.
- **Disconnection mid-dialogue**: server's `end_dialogue` should be called when the player's connection drops. Server-side cleanup; no client involvement needed.

## What Gaba does not provide

- The RPC layer. Use `@rpc` annotations, `MultiplayerSpawner`, or whatever else fits your stack.
- Session ID generation / lookup. The server probably already has a per-player context — attach the session reference to it.
- Replay/rollback semantics. Effect application is one-way.
