# World Package

> **Package:** `world` · **Module:** `world::world`
> **Path:** `engine/world/`
> **Dependencies:** `entity`, `components`, `systems`, Sui Framework

---

## Concept

The **World** is a **facade** — a single shared Sui object that wraps all 18 engine systems behind one import. It adds two cross-cutting concerns that individual systems don't handle:

1. **Pause control** — every state-changing operation calls `assert_not_paused(world)`
2. **Entity counting** — spawn wrappers increment `entity_count` and enforce `max_entities`

Game developers import `world::world` instead of importing individual systems. For read-only queries (grid dimensions, turn state, component getters), they can still access `systems::*` and `components::*` directly since `world` re-exports those dependencies transitively.

```
                   ┌─────────────────┐
  Game Contract ──▶│      World      │
                   │  (pause + count)│
                   └────────┬────────┘
                            │ delegates to
              ┌─────────────┼──────────────┐
              ▼             ▼              ▼
          systems       components      entity
```

---

## Struct

```move
public struct World has key {
    id: UID,
    name: String,          // World name (e.g. "MyGame")
    version: u64,          // Schema version (starts at 1)
    creator: address,      // Game master — gates pause/resume/destroy
    paused: bool,          // When true, ALL operations blocked
    entity_count: u64,     // Entities spawned through this world
    max_entities: u64,     // Hard cap
}
```

---

## Admin API

| Function | Signature | Description |
|----------|-----------|-------------|
| `create_world` | `(name, max_entities, &mut TxContext): World` | Create world. `creator = tx.sender()`. Emits `WorldCreatedEvent`. |
| `share` | `(world: World)` | Make world a shared Sui object |
| `pause` | `(world, &TxContext)` | **Creator only.** Block all operations. Emits `WorldPausedEvent`. |
| `resume` | `(world, &TxContext)` | **Creator only.** Unblock. Emits `WorldPausedEvent`. |
| `destroy` | `(world, &TxContext)` | **Creator only.** Destroy the world object. |

### Getters

| Function | Returns | Description |
|----------|---------|-------------|
| `name` | `String` | World name |
| `version` | `u64` | Schema version |
| `creator` | `address` | Game master address |
| `is_paused` | `bool` | Whether paused |
| `entity_count` | `u64` | Entities spawned via world |
| `max_entities` | `u64` | Hard cap |

---

## Spawn Wrappers (increment entity_count)

| Function | Delegates To | Notes |
|----------|-------------|-------|
| `spawn_player(world, name, x, y, max_hp, team_id, &Clock, ctx): Entity` | `spawn_sys::spawn_player` | +1 entity_count |
| `spawn_npc(world, name, x, y, max_hp, atk_dmg, team_id, &Clock, ctx): Entity` | `spawn_sys::spawn_npc` | +1 entity_count |
| `spawn_tile(world, x, y, symbol, &Clock, ctx): Entity` | `spawn_sys::spawn_tile` | +1 entity_count |
| `generate_encounter(world, floor, enemy_count, &Clock, ctx): vector<Entity>` | `encounter_sys::generate_encounter` | +N entity_count |

---

## Grid Wrappers

| Function | Delegates To |
|----------|-------------|
| `create_grid(world, width, height, ctx): Grid` | `grid_sys::create_grid` |
| `share_grid(grid)` | `grid_sys::share` |
| `place(world, grid, entity_id, x, y)` | `grid_sys::place` |
| `remove_from_grid(world, grid, x, y): ID` | `grid_sys::remove` |

---

## Movement & Position Wrappers

| Function | Delegates To |
|----------|-------------|
| `move_entity(world, entity, grid, to_x, to_y)` | `movement_sys::move_entity` |
| `swap(world, e1, e2, grid)` | `swap_sys::swap` |
| `capture(world, capturer, target, grid)` | `capture_sys::capture` |

---

## Combat Wrapper

| Function | Delegates To |
|----------|-------------|
| `attack(world, attacker, defender): u64` | `combat_sys::attack` |

---

## Turn Wrappers

| Function | Delegates To |
|----------|-------------|
| `create_turn_state(world, player_count, mode, ctx): TurnState` | `turn_sys::create_turn_state` |
| `share_turn_state(state)` | `turn_sys::share` |
| `end_turn(world, state)` | `turn_sys::end_turn` |
| `advance_phase(world, state)` | `turn_sys::advance_phase` |

---

## Status Effect Wrappers

| Function | Delegates To |
|----------|-------------|
| `apply_effect(world, entity, effect_type, stacks, duration)` | `status_effect_sys::apply_effect` |
| `tick_effects(world, entity): u64` | `status_effect_sys::tick_effects` |
| `remove_expired(world, entity): bool` | `status_effect_sys::remove_expired` |

---

## Energy Wrappers

| Function | Delegates To |
|----------|-------------|
| `spend_energy(world, entity, cost: u8)` | `energy_sys::spend_energy` |
| `regenerate_energy(world, entity)` | `energy_sys::regenerate_energy` |
| `has_enough_energy(world, entity, cost: u8): bool` | `energy_sys::has_enough_energy` |

---

## Card Wrappers

| Function | Delegates To |
|----------|-------------|
| `draw_cards(world, entity, count): u64` | `card_sys::draw_cards` |
| `play_card(world, entity, hand_index): CardData` | `card_sys::play_card` |
| `discard_card(world, entity, hand_index)` | `card_sys::discard_card` |
| `shuffle_deck(world, entity, &Random, ctx)` | `card_sys::shuffle_deck` |

---

## Reward Wrappers

| Function | Delegates To |
|----------|-------------|
| `grant_gold(world, entity, amount)` | `reward_sys::grant_gold` |
| `grant_card(world, entity, card)` | `reward_sys::grant_card` |
| `grant_relic(world, entity, relic_type: u8, modifier_value)` | `reward_sys::grant_relic` |

---

## Shop Wrappers

| Function | Delegates To |
|----------|-------------|
| `buy_card(world, entity, card, cost)` | `shop_sys::buy_card` |
| `buy_relic(world, entity, relic_type: u8, modifier_value, cost)` | `shop_sys::buy_relic` |
| `remove_card(world, entity, draw_pile_index, cost)` | `shop_sys::remove_card` |

---

## Map Wrappers

| Function | Delegates To |
|----------|-------------|
| `choose_path(world, entity, node: u8)` | `map_sys::choose_path` |
| `advance_floor(world, entity)` | `map_sys::advance_floor` |
| `current_floor(entity): u8` | `map_sys::current_floor` — no pause check (read-only) |
| `current_node(entity): u8` | `map_sys::current_node` — no pause check (read-only) |

---

## Relic Wrappers

| Function | Delegates To |
|----------|-------------|
| `add_relic(world, entity, relic_type: u8, modifier_type: u8, modifier_value)` | `relic_sys::add_relic` |
| `apply_relic_bonus(world, entity): u64` | `relic_sys::apply_relic_bonus` |
| `remove_relic(world, entity)` | `relic_sys::remove_relic` |

---

## Objective Wrappers

| Function | Delegates To |
|----------|-------------|
| `pick_up(world, carrier, flag_entity)` | `objective_sys::pick_up` |
| `drop_flag(world, carrier, flag_entity)` | `objective_sys::drop_flag` |
| `score(world, carrier, flag_entity, team: u8)` | `objective_sys::score` |

---

## Territory Wrappers

| Function | Delegates To |
|----------|-------------|
| `claim(world, entity, zone_entity)` | `territory_sys::claim` |
| `contest(world, entity, zone_entity, amount)` | `territory_sys::contest` |
| `capture_zone(world, zone_entity, team: u8)` | `territory_sys::capture_zone` |

---

## Win Condition Wrappers

| Function | Delegates To |
|----------|-------------|
| `check_elimination(entity): bool` | `win_condition_sys::check_elimination` — no pause check (read-only) |
| `declare_winner(world, winner_id, condition, &Clock)` | `win_condition_sys::declare_winner` |

---

## Wager Wrappers

| Function | Delegates To |
|----------|-------------|
| `create_wager_pool(world, wager_amount, max_players, protocol_fee_bps, fee_recipient, payout_mode, timeout_ms, &Clock, ctx): (Entity, SettlementCap)` | `wager_sys::create_pool` |
| `place_wager(world, &cap, pool, player, Coin<SUI>, ctx)` | `wager_sys::place_wager` |
| `lock_wagers(world, &cap, pool, players)` | `wager_sys::lock_wagers` |
| `settle_winner(world, &cap, pool, winner, losers, ctx)` | `wager_sys::settle_winner` |
| `settle_with_fee(world, &cap, pool, winner, losers, ctx)` | `wager_sys::settle_with_fee` |
| `settle_proportional(world, &cap, pool, winners, shares, losers, ctx)` | `wager_sys::settle_proportional` |
| `settle_timeout(world, &cap, pool, winner, loser, &Clock, ctx)` | `wager_sys::settle_timeout` |
| `refund_all(world, &cap, pool, players, ctx)` | `wager_sys::refund_all` |
| `refund_player(world, &cap, pool, player, ctx)` | `wager_sys::refund_player` |
| `destroy_empty_pool(world, &cap, pool)` | `wager_sys::destroy_empty_pool` |
| `destroy_settlement_cap(cap)` | `wager_sys::destroy_cap` — no pause check |
| `wager_cap_pool_id(&cap): ID` | `wager_sys::cap_pool_id` — no pause check |

---

## Re-exported Constants

| Function | Source |
|----------|-------|
| `mode_simple()` / `mode_phase()` | `turn_sys` |
| `phase_draw()` / `phase_play()` / `phase_combat()` / `phase_end()` | `turn_sys` |
| `condition_elimination()` / `condition_board_full()` / `condition_objective()` / `condition_surrender()` / `condition_timeout()` / `condition_custom()` | `win_condition_sys` |

---

## Errors

| Constant | Code | Meaning |
|----------|------|---------|
| `EWorldPaused` | 0 | Operation blocked — world is paused |
| `EMaxEntities` | 1 | Entity count would exceed max_entities |
| `ENotCreator` | 2 | Caller is not the world creator |

---

## Events

| Event | Fields | Emitted By |
|-------|--------|------------|
| `WorldCreatedEvent` | `world_id`, `name`, `creator` | `create_world` |
| `WorldPausedEvent` | `world_id`, `paused: bool` | `pause` / `resume` |

---

## What's NOT Wrapped

Read-only query functions are accessible directly via `systems::*`:

- `grid_sys::width()`, `height()`, `is_occupied()`, `get_entity_at()`, `in_bounds()`, `is_full()`, `to_index()`, `occupied_count()`
- `turn_sys::current_player()`, `player_count()`, `turn_number()`, `phase()`, `mode()`, `is_player_turn()`
- `turn_sys::destroy()`, `grid_sys::destroy_empty()` — cleanup functions
- `reward_sys::reward_gold()`, `reward_card()`, `reward_relic()` — constants
- `wager_sys::cap_pool_id()` — read-only cap accessor

These don't need pause-checking since they only read state.
