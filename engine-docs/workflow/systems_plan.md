# Phase 3: Systems — Implementation Plan

## Single Package

All 18 systems in `engine/systems/`. Split only if max package size error.

```
engine/systems/
├── Move.toml            # depends on entity, components
├── sources/
│   ├── spawn_sys.move
│   ├── grid_sys.move
│   ├── turn_sys.move
│   ├── win_condition_sys.move
│   ├── movement_sys.move
│   ├── swap_sys.move
│   ├── capture_sys.move
│   ├── objective_sys.move
│   ├── territory_sys.move
│   ├── combat_sys.move
│   ├── status_effect_sys.move
│   ├── energy_sys.move
│   ├── card_sys.move
│   ├── encounter_sys.move
│   ├── reward_sys.move
│   ├── shop_sys.move
│   ├── map_sys.move
│   └── relic_sys.move
└── tests/
    ├── core_tests.move
    └── advanced_tests.move
```

---

## Design Rules

1. **No shared helpers module.** Utility functions (e.g. distance calculations) inlined per module.
2. **No cross-system imports.** Each system only imports from `entity` and `components`.
3. **Systems that need to create entities** (e.g. `encounter_sys`) call `entity::new()` directly and attach components themselves — they do NOT import `spawn_sys`.
4. **Grid tracks `occupied_count`** for O(1) fullness checks.
5. **`win_condition_sys` is generic** — it is a thin event emitter, NOT a collection of game-specific checks. Game-specific win logic (board full, king captured, flag scored, etc.) belongs in the game module, which then calls `declare_winner()`.

---

## Pass 1: Core + Board (9 systems)

### spawn_sys.move — Entity factories
- `spawn_player(name, x, y, max_hp, team_id, clock, ctx)` → position, identity, health, team
- `spawn_npc(name, x, y, max_hp, atk, range, clock, ctx)` → position, identity, health, attack
- `spawn_tile(x, y, clock, ctx)` → position, marker
- Event: `SpawnEvent`

### grid_sys.move — Grid shared object (`Table<u64, ID>`)
- Grid struct fields: `id`, `width`, `height`, `cells: Table<u64, ID>`, `occupied_count: u64`
- `create_grid()`, `place()`, `remove()`, `move_on_grid()`, `is_occupied()`, `get_entity_at()`
- `occupied_count` updated on place/remove for O(1) fullness check
- Errors: `EOutOfBounds`, `ECellOccupied`, `ECellEmpty`

### turn_sys.move — Dual-mode turns
- TurnState struct (shared). Simple mode (counter) + Phase mode (Draw→Play→Combat→End)
- `create_turn_state()`, `end_turn()`, `advance_phase()`, getters

### win_condition_sys.move — Generic game-over emitter
- `check_elimination(entity): bool` — returns `health.current() == 0`
- `declare_winner(winner_id, condition_type, clock)` → emits `GameOverEvent`
- **NOT game-specific.** Does NOT contain board-full, king-captured, etc. Those checks are the game module's job. Games call `declare_winner()` when their custom condition is met.

### movement_sys.move — Move with validation
- `move_entity(entity, grid, to_x, to_y)` — bounds, speed, pattern, collision
- Inlines distance/pattern helpers

### swap_sys.move — Swap positions + grid cells
### capture_sys.move — Remove captured piece from grid
### objective_sys.move — `pick_up()`, `drop_flag()`, `score()`
### territory_sys.move — `claim()`, `contest()`, `capture_zone()`

---

## Pass 2: Combat + Roguelike (9 systems)

### combat_sys.move — `attack()` with range, damage, defense
### status_effect_sys.move — `apply_effect()`, `tick_effects()`, `remove_expired()`
### energy_sys.move — `spend_energy()`, `regenerate_energy()`
### card_sys.move — `draw_cards()`, `play_card()`, `shuffle_deck(r: &Random)`
### encounter_sys.move — `generate_encounter()` with floor scaling (creates entities directly, no spawn_sys import)
### reward_sys.move — `grant_gold()`, `grant_card()`, `grant_relic()`
### shop_sys.move — `buy_card()`, `buy_relic()`, `remove_card()`
### map_sys.move — `choose_path()`, `advance_floor()`
### relic_sys.move — `apply_relic_bonus()`, `add_relic()`, `remove_relic()`

---

## Verification
```bash
cd engine/systems && sui move build && sui move test
```
