# On-Chain Game Skills — Implementation Plan

## Overview

A fully self-contained skill at `.agent/skills/on_chain_game_skills/`. **No external references** — all engine docs are copied inside the skill folder.

---

## Folder Structure

```
.agent/skills/on_chain_game_skills/
│
├── SKILL.md                              ← Entry point (Rule Zero + router)
│
├── references/                           ← HOW TO USE (patterns + guides)
│   ├── world_api.md                      ← World facade API reference
│   ├── game_template.md                  ← Boilerplate game contract
│   ├── component_picker.md               ← "What do I need?" decision matrix
│   ├── spatial_patterns.md               ← Grid + movement + territory
│   ├── combat_patterns.md                ← Damage + effects + energy
│   ├── progression_patterns.md           ← Cards + shops + maps + relics
│   ├── turn_and_win_patterns.md          ← Turn modes + win conditions
│   ├── dos_and_donts.md                  ← Pitfalls + anti-patterns
│   ├── workflow.md                       ← Step-by-step AI agent workflow
│   ├── custom_components.md              ← Adding game-specific data to entities
│   └── game_lifecycle.md                 ← Multi-transaction flow + shared vs owned
│
├── engine-reference/                     ← HOW IT WORKS (engine API docs)
│   ├── entity.md                         ← Entity struct, bitmask, lifecycle
│   ├── components.md                     ← All 18 components with full API
│   ├── systems.md                        ← All 18 systems with full API
│   └── world.md                          ← World facade implementation details
│
└── examples/                             ← Added later from real games built with this skill
```

**Total: 16 files** (1 SKILL.md + 11 references + 4 engine-reference)

---

## Two Reference Layers

| Layer | Folder | Purpose | When to read |
|-------|--------|---------|-------------|
| **Patterns** | `references/` | How to USE systems — recipes, combinations, templates | Always (game building) |
| **Engine API** | `engine-reference/` | How systems WORK — every function signature, edge case | When you need exact details |

Pattern references link to engine-reference files using relative paths within the skill folder:

```markdown
## Grid Setup Pattern
world::create_grid(&mut world, 3, 3, ctx);

> **Full API:** See [grid_sys](./engine-reference/systems.md#grid_sys)
```

---

## SKILL.md Design

### Rule Zero (always first)

> **You are NOT writing game logic from scratch.**
> You compose the engine's **systems** and **components**.
> The engine handles state, storage, and on-chain data.
> Your job: **wire systems together** in the right sequence.
>
> - **Components** = data (Health, Position, Deck, Gold…)
> - **Systems** = logic (combat_sys, card_sys, movement_sys…)
> - **World** = facade (pause control, entity counting)
> - **Your game** = entry points calling World functions

### Prerequisite Skills (read these first)

Before using this skill, the AI must also load these foundational skills:

| Skill | Path | Covers |
|-------|------|--------|
| **Sui Move Patterns** | `.agent/skills/sui-move-skills/sui_move_patterns/` | Object model, abilities, generics, collections, API design |
| **Sui Framework** | `.agent/skills/sui-move-skills/sui_framework/` | Clock, randomness, events, dynamic fields, transfer, storage |
| **Sui Engineering** | `.agent/skills/sui-move-skills/sui_engineering/` | Upgradeability, gas limits, error handling, testing |

> [!IMPORTANT]
> These 3 skills provide the **Move language and Sui platform knowledge**. This skill provides the **engine-specific game building knowledge**. Both layers are needed.

### Router + Decision Matrix

Routes to the right reference file based on game needs.

---

## Reference Files Summary (9)

| # | File | Content |
|---|------|---------|
| 1 | `world_api.md` | Every World function with signatures, grouped by purpose |
| 2 | `game_template.md` | Move.toml + module skeleton + GameSession pattern |
| 3 | `component_picker.md` | "My game needs X" → use these components/systems |
| 4 | `spatial_patterns.md` | Grid setup, movement, swap, capture, territory, objectives |
| 5 | `combat_patterns.md` | Damage pipeline, status effects, energy gating |
| 6 | `progression_patterns.md` | Deck lifecycle, encounters, rewards, shops, maps, relics |
| 7 | `turn_and_win_patterns.md` | Simple/phase turn modes, 6 win condition types |
| 8 | `dos_and_donts.md` | 11 do/don't rules for common pitfalls |
| 9 | `workflow.md` | 9-step AI workflow (Understand → Deploy) |
| 10 | `custom_components.md` | Adding game-specific data beyond the 18 built-in components |
| 11 | `game_lifecycle.md` | Multi-transaction flow, shared vs owned, PTB batching |

## Engine Reference (4)

Copied from `engine-docs/` and self-contained within the skill:

| # | File | Content |
|---|------|---------|
| 1 | `entity.md` | Entity struct, bitmask, 18 component bits, lifecycle API |
| 2 | `components.md` | All 18 components: struct, key, constructor, add/borrow/mutate |
| 3 | `systems.md` | All 18 systems: function signatures, behavior, events |
| 4 | `world.md` | World facade: admin, wrappers, events, errors |

---

### 10. `custom_components.md` — Game-Specific Data

**What an AI gets:** How to add custom data that the engine doesn't provide.

**3-Tier Decision (in priority order):**

| Priority | Approach | When to Use | Example |
|----------|----------|-------------|--------|
| 🥇 **Default** | **Dynamic field shortcut** | Simple key-value data (score, flag, timer, counter) | `dynamic_field::add(uid, b"score", 0u64)` |
| 🥈 Second | **Full component module** | Structured multi-field data reused across entities | Custom `Mana { current, max, regen }` module |
| 🥉 Third | **GameSession fields** | Game-wide state not tied to any entity | Match timer, round number, team scores |

**Dynamic Field Shortcut (always try this first):**
```move
// Store
dynamic_field::add(entity::uid_mut(entity), b"score", 0u64);
// Read
let score = dynamic_field::borrow<vector<u8>, u64>(entity::uid(entity), b"score");
// Mutate
*dynamic_field::borrow_mut<vector<u8>, u64>(entity::uid_mut(entity), b"score") = 10;
```

**Full Component Module (only when shortcut isn't enough):**
- Copy the engine component pattern: `struct → key → add → borrow → borrow_mut`
- Use bitmask bits 18+ (0–17 are taken by built-in components)
- Template included in the reference

**GameSession Fields (for game-wide state):**
- Add fields directly to the `GameSession` struct
- Not per-entity — shared across all players

---

### 11. `game_lifecycle.md` — Multi-Transaction Game Flow

**What an AI gets:** How transactions connect across a game's full lifecycle.

**Game Lifecycle Diagram:**
```
[Admin]  create_game()  → World + Grid + GameSession shared
[P1]     join_game()    → spawn player entity
[P2]     join_game()    → spawn player entity
[Admin]  start_game()   → state = Active, first turn set
         ┌───── GAME LOOP ─────────────┐
         │ take_action() → PTB can   │
         │   batch: move + attack +  │
         │   end_turn in one tx      │
         └─────────────────────────┘
[System] game_over()    → declare winner, pause world
```

**Key sections:**

| Topic | Content |
|-------|---------|
| Shared vs Owned | World, Grid, GameSession, TurnState = `share()`. Player entities = owned or shared? |
| PTB Batching | Which actions to combine in one Programmable Transaction Block |
| Caller Validation | `tx_context::sender()` == expected player |
| State Machine | Lobby → Active → Finished; enforce valid transitions |
| Transaction Sequence | Template per game type (2-player, multiplayer, single-player) |

---

## Examples (deferred)

Examples will be added later by building real games with this skill. The `examples/` folder is reserved for these.

## Implementation Order

1. `SKILL.md` — Rule Zero + router
2. `engine-reference/` — copy + adapt from `engine-docs/` (4 files)
3. `world_api.md` — distill from `engine-reference/world.md`
4. `component_picker.md` — distill from `engine-reference/components.md`
5. `game_template.md` — boilerplate pattern
6. `dos_and_donts.md` — pitfalls
7. `workflow.md` — AI workflow
8. `turn_and_win_patterns.md` — game flow patterns
9. `spatial_patterns.md` — grid patterns
10. `combat_patterns.md` — damage patterns
11. `progression_patterns.md` — progression patterns
12. `custom_components.md` — custom data patterns
13. `game_lifecycle.md` — multi-transaction flow

---

## Verification

- **Self-contained**: zero references outside `on_chain_game_skills/`
- **Completeness**: every World function in `world_api.md`
- **Coverage**: every system in at least one pattern reference
- **AI test**: give agent only this skill → build a game → valid output
