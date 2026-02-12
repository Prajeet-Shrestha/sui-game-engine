# Phase 4: World Contract

> The World package (`engine/world/`) is a **facade** — a single entry point for game contracts to access all 18 engine systems.

## Package Structure

```
engine/world/
├── Move.toml          # depends on entity, components, systems
├── sources/
│   └── world.move     # World struct + all system wrappers
└── tests/
    └── world_tests.move
```

## World Struct

```move
public struct World has key {
    id: UID,
    name: String,
    version: u64,
    creator: address,    // Game master
    paused: bool,
    entity_count: u64,
    max_entities: u64,
}
```

## Design Rules

| Rule | Detail |
|------|--------|
| **Pause scope** | ALL operations blocked when paused |
| **Pause gating** | Only `creator` can pause/resume |
| **Wrappers** | Thin pass-throughs — no re-implementation |
| **Entity counting** | Spawn wrappers increment `entity_count` |
| **Bypass** | Direct system import is allowed (security is Phase 2) |
| **Creator** | Game master address, stored at creation. Full role definition in Phase 2 |

## API Categories

### Admin
- `create_world()`, `share()`, `pause()`, `resume()`, `destroy()`

### Spawn (increments entity_count)
- `spawn_player()`, `spawn_npc()`, `spawn_tile()`

### Grid
- `create_grid()`, `place()`, `remove_from_grid()`, `share_grid()`

### Movement
- `move_entity()`, `swap()`, `capture()`

### Turns
- `create_turn_state()`, `end_turn()`, `advance_phase()`

### Combat
- `attack()`, `apply_effect()`, `tick_effects()`, `remove_expired()`

### Energy
- `spend_energy()`, `regenerate_energy()`, `has_enough_energy()`

### Cards
- `draw_cards()`, `play_card()`, `discard_card()`, `discard_hand()`, `shuffle_deck()`

### Encounters
- `generate_encounter()` (also increments entity_count per enemy)

### Rewards
- `grant_gold()`, `grant_card()`, `grant_relic()`

### Shop
- `buy_card()`, `buy_relic()`, `remove_card()`

### Map
- `choose_path()`, `advance_floor()`, `current_floor()`, `current_node()`

### Relics
- `add_relic()`, `apply_relic_bonus()`, `remove_relic()`

### Win Condition
- `check_elimination()`, `declare_winner()`

### Objectives & Territory
- `pick_up()`, `drop_flag()`, `score()`
- `claim()`, `contest()`, `capture_zone()`

### Re-exported Constants
- Turn modes: `mode_simple()`, `mode_phase()`
- Turn phases: `phase_draw()`, `phase_play()`, `phase_combat()`, `phase_end()`
- Win conditions: `condition_elimination()`, `condition_board_full()`, etc.
