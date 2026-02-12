# Systems Package

> **Package:** `systems` · **18 modules**
> **Path:** `engine/systems/`
> **Dependencies:** `entity`, `components`, Sui Framework (`sui::clock`, `sui::random`)

---

## Concept

Systems contain **all game logic**. They read/mutate components on entities but own no data themselves (stateless). Each system is a pure function module — no structs stored on-chain (except `Grid` and `TurnState` which are shared Sui objects).

Systems enforce rules: movement validates grid bounds, combat checks range, energy asserts sufficient cost, etc.

---

## System Catalog

### 1. spawn_sys — Entity Factory

Creates fully-assembled entities with the right components pre-attached.

| Function | Signature | Components Added |
|----------|-----------|-----------------|
| `spawn_player` | `(name, x, y, max_hp, team_id, &Clock, &mut TxContext): Entity` | Position, Identity, Health, Team |
| `spawn_npc` | `(name, x, y, max_hp, atk_damage, team_id, &Clock, &mut TxContext): Entity` | Position, Identity, Health, Attack |
| `spawn_tile` | `(x, y, symbol, &Clock, &mut TxContext): Entity` | Position, Marker |

Emits `SpawnEvent { entity_id, entity_type, name }`.

---

### 2. grid_sys — 2D Spatial Grid

A shared `Grid` object that maps `(x, y)` → `entity ID`. Enforces bounds and occupancy.

**Struct:** `Grid has key { id, width, height, cells: Table<u64, ID>, occupied_count }`

| Function | Signature | Description |
|----------|-----------|-------------|
| `create_grid` | `(width, height, &mut TxContext): Grid` | New grid |
| `share` | `(grid: Grid)` | Share as Sui object |
| `place` | `(grid, entity_id, x, y)` | Place entity; asserts bounds + not occupied |
| `remove` | `(grid, x, y): ID` | Remove and return entity ID |
| `move_on_grid` | `(grid, entity_id, from_x, from_y, to_x, to_y)` | Atomic remove + place |
| `in_bounds` | `(grid, x, y): bool` | Bounds check |
| `is_occupied` | `(grid, x, y): bool` | Cell occupied? |
| `get_entity_at` | `(grid, x, y): ID` | Get entity at cell |
| `is_full` | `(grid): bool` | All cells occupied? |
| `width` / `height` / `occupied_count` | getters | Grid dimensions |
| `to_index` | `(x, y, width): u64` | Convert coords to flat index |
| `destroy_empty` | `(grid: Grid)` | Destroy grid (must be empty) |

---

### 3. movement_sys — Grid Movement

| Function | Signature | Description |
|----------|-----------|-------------|
| `move_entity` | `(entity, grid, to_x, to_y)` | Validates bounds, occupancy, speed, pattern; updates grid + Position component |

**Movement patterns:** walk (Manhattan), fly (ignores obstacles), teleport (unlimited range).
Emits `MoveEvent`.

---

### 4. combat_sys — Damage Resolution

| Function | Signature | Description |
|----------|-----------|-------------|
| `attack` | `(attacker: &Entity, defender: &mut Entity): u64` | Check alive, range; apply damage with defense reduction. Returns actual damage dealt. |

Emits `AttackEvent` and `DeathEvent`.

---

### 5. turn_sys — Turn Management

**Struct:** `TurnState has key { id, player_count, current_player, turn_number, phase, mode }`

| Function | Signature | Description |
|----------|-----------|-------------|
| `create_turn_state` | `(player_count, mode, &mut TxContext): TurnState` | New turn state |
| `share` | `(state: TurnState)` | Share as Sui object |
| `end_turn` | `(state: &mut TurnState)` | Advance to next player. In phase mode, requires phase == END |
| `advance_phase` | `(state: &mut TurnState)` | DRAW → PLAY → COMBAT → END |
| `is_player_turn` | `(state, player_index: u8): bool` | Check if it's a player's turn |
| `current_player` / `player_count` / `turn_number` / `phase` / `mode` | getters | State queries |
| `destroy` | `(state: TurnState)` | Cleanup |

**Modes:** `mode_simple()` (just rotate), `mode_phase()` (draw/play/combat/end per turn)
**Phases:** `phase_draw()`, `phase_play()`, `phase_combat()`, `phase_end()`

---

### 6. swap_sys — Position Swap

| Function | Signature | Description |
|----------|-----------|-------------|
| `swap` | `(e1, e2, grid)` | Swap positions of two entities on the grid |

---

### 7. capture_sys — Grid Capture

| Function | Signature | Description |
|----------|-----------|-------------|
| `capture` | `(capturer, target, grid)` | Remove target from grid if adjacent to capturer |

---

### 8. objective_sys — Flag / Capture the Flag

| Function | Signature | Description |
|----------|-----------|-------------|
| `pick_up` | `(carrier: &Entity, flag: &mut Entity)` | Carrier picks up objective |
| `drop_flag` | `(carrier: &Entity, flag: &mut Entity)` | Drop held objective |
| `score` | `(carrier: &Entity, flag: &mut Entity, team: u8)` | Score the objective |

Operates on entities with the Objective component.

---

### 9. territory_sys — Zone Control

| Function | Signature | Description |
|----------|-----------|-------------|
| `claim` | `(entity: &Entity, zone: &mut Entity)` | Instantly claim zone for entity's team |
| `contest` | `(entity: &Entity, zone: &mut Entity, amount: u64)` | Add capture progress (caps at 100) |
| `capture_zone` | `(zone: &mut Entity, team: u8)` | Finalize zone capture for team |

Operates on entities with the Zone component.

---

### 10. win_condition_sys — Game Over

| Function | Signature | Description |
|----------|-----------|-------------|
| `check_elimination` | `(entity: &Entity): bool` | Is entity dead? |
| `declare_winner` | `(winner_id, condition, &Clock)` | Emit `GameOverEvent` |

**Conditions:** `condition_elimination()`, `condition_board_full()`, `condition_objective()`, `condition_surrender()`, `condition_timeout()`, `condition_custom()`

---

### 11. status_effect_sys — Buffs & Debuffs

| Function | Signature | Description |
|----------|-----------|-------------|
| `apply_effect` | `(entity, effect_type: u8, stacks, duration: u8)` | Add/stack status effect |
| `tick_effects` | `(entity): u64` | Process effect (poison damage, regen); returns value processed |
| `remove_expired` | `(entity): bool` | Remove if duration == 0; returns true if removed |

---

### 12. energy_sys — Action Points

| Function | Signature | Description |
|----------|-----------|-------------|
| `spend_energy` | `(entity, cost: u8)` | Deducts energy; asserts enough |
| `regenerate_energy` | `(entity)` | Adds regen_rate to current (caps at max) |
| `has_enough_energy` | `(entity, cost: u8): bool` | Check without spending |

---

### 13. card_sys — Deck Builder

| Function | Signature | Description |
|----------|-----------|-------------|
| `draw_cards` | `(entity, count): u64` | Draw from pile to hand; returns actual drawn |
| `play_card` | `(entity, hand_index): CardData` | Remove from hand, return it |
| `discard_card` | `(entity, hand_index)` | Move card from hand to discard pile |
| `shuffle_deck` | `(entity, &Random, &mut TxContext)` | Shuffle discard into draw pile |

---

### 14. encounter_sys — Floor Encounters

| Function | Signature | Description |
|----------|-----------|-------------|
| `generate_encounter` | `(floor: u8, enemy_count, &Clock, &mut TxContext): vector<Entity>` | Spawn scaled enemies for a floor |

Enemy HP/ATK scale with floor number.

---

### 15. reward_sys — Loot Grants

| Function | Signature | Description |
|----------|-----------|-------------|
| `grant_gold` | `(entity, amount)` | Add gold to entity |
| `grant_card` | `(entity, card: CardData)` | Add card to draw pile |
| `grant_relic` | `(entity, relic_type: u8, modifier_value)` | Give relic component |

**Constants:** `reward_gold()`, `reward_card()`, `reward_relic()`

---

### 16. shop_sys — Buy / Sell

| Function | Signature | Description |
|----------|-----------|-------------|
| `buy_card` | `(entity, card, cost)` | Spend gold, add card to draw pile |
| `buy_relic` | `(entity, relic_type: u8, modifier_value, cost)` | Spend gold, equip relic |
| `remove_card` | `(entity, draw_pile_index, cost)` | Spend gold, thin deck |

---

### 17. map_sys — Roguelike Map Progression

| Function | Signature | Description |
|----------|-----------|-------------|
| `choose_path` | `(entity, node: u8)` | Set current node on floor |
| `advance_floor` | `(entity)` | Increment floor, reset node |
| `current_floor` | `(entity): u8` | Get current floor |
| `current_node` | `(entity): u8` | Get current node |

---

### 18. relic_sys — Relic Management

| Function | Signature | Description |
|----------|-----------|-------------|
| `add_relic` | `(entity, relic_type: u8, modifier_type: u8, modifier_value)` | Attach relic component |
| `apply_relic_bonus` | `(entity): u64` | Returns the modifier value (for game logic to use) |
| `remove_relic` | `(entity)` | Strip relic from entity |

---

## System Categories

```
┌─────────────────────────────────────────────┐
│  Core (any game)                            │
│  spawn_sys · grid_sys · movement_sys        │
│  combat_sys · turn_sys · win_condition_sys   │
│  swap_sys · capture_sys                     │
├─────────────────────────────────────────────┤
│  PvP / Territory                            │
│  objective_sys · territory_sys              │
├─────────────────────────────────────────────┤
│  Roguelike                                  │
│  status_effect_sys · energy_sys · card_sys  │
│  encounter_sys · reward_sys · shop_sys      │
│  map_sys · relic_sys                        │
└─────────────────────────────────────────────┘
```
