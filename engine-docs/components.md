# Components Package

> **Package:** `components` · **18 modules**
> **Path:** `engine/components/`
> **Dependencies:** `entity` (for `Entity`, component bits, `add_component`/`remove_component`)

---

## Concept

Components are **pure data structs** with `store, copy, drop` abilities. They attach to Entities as dynamic fields keyed by ascii strings. Each component module follows a uniform API pattern:

```
key() → String                        // dynamic field key
new(...) → T                          // constructor
add(entity, value)                    // attach to entity
remove(entity) → T                   // detach from entity
borrow(entity) → &T                  // immutable read
borrow_mut(entity) → &mut T          // mutable read
[getters / setters]                   // field access
```

Components **never call** other components or systems — they are just containers.

---

## Component Catalog

### Core Components

#### Position
**Module:** `components::position` · **Bit:** 0
**Struct:** `Position { x: u64, y: u64 }`

| Function | Signature |
|----------|-----------|
| `new` | `(x: u64, y: u64): Position` |
| `x` / `y` | `(&Position): u64` |
| `set_x` / `set_y` | `(&mut Position, u64)` |
| `set` | `(&mut Position, x: u64, y: u64)` |

---

#### Health
**Module:** `components::health` · **Bit:** 1
**Struct:** `Health { current: u64, max: u64 }`

| Function | Signature |
|----------|-----------|
| `new` | `(max_hp: u64): Health` — current starts at max |
| `current` / `max` | `(&Health): u64` |
| `is_alive` | `(&Health): bool` |
| `take_damage` | `(&mut Health, dmg: u64)` — floors at 0 |
| `heal` | `(&mut Health, amount: u64)` — caps at max |
| `set_current` / `set_max` | `(&mut Health, u64)` |

---

#### Attack
**Module:** `components::attack` · **Bit:** 2
**Struct:** `Attack { damage: u64, range: u64, pattern: u8 }`

| Function | Signature |
|----------|-----------|
| `new` | `(damage: u64, range: u64, pattern: u8): Attack` |
| `damage` / `range` / `pattern` | `(&Attack): u64 / u64 / u8` |
| `set_damage` / `set_range` / `set_pattern` | mutators |

---

#### Identity
**Module:** `components::identity` · **Bit:** 3
**Struct:** `Identity { name: String, level: u64 }`

| Function | Signature |
|----------|-----------|
| `new` | `(name: String, level: u64): Identity` |
| `name` / `level` | getters |
| `set_name` / `set_level` / `level_up` | mutators |

---

#### Movement
**Module:** `components::movement` · **Bit:** 4
**Struct:** `Movement { speed: u64, pattern: u64 }`

| Function | Signature |
|----------|-----------|
| `new` | `(speed: u64, pattern: u64): Movement` |
| `speed` / `pattern` | getters |
| `set_speed` / `set_pattern` | mutators |
| `pattern_walk()` / `pattern_fly()` / `pattern_teleport()` | constants |

---

#### Defense
**Module:** `components::defense` · **Bit:** 5
**Struct:** `Defense { armor: u64, resistance: u64 }`

| Function | Signature |
|----------|-----------|
| `new` | `(armor: u64, resistance: u64): Defense` |
| `armor` / `resistance` | getters |
| `reduce_damage` | `(&Defense, raw_damage: u64): u64` — returns `max(1, raw - armor)` |
| `set_armor` / `set_resistance` | mutators |

---

#### Team
**Module:** `components::team` · **Bit:** 6
**Struct:** `Team { team_id: u8 }`

| Function | Signature |
|----------|-----------|
| `new` | `(team_id: u8): Team` |
| `team_id` | `(&Team): u8` |
| `same_team` | `(&Team, &Team): bool` |
| `set_team_id` | `(&mut Team, u8)` |

---

#### Marker
**Module:** `components::marker` · **Bit:** 17
**Struct:** `Marker { symbol: u64 }`

| Function | Signature |
|----------|-----------|
| `new` | `(symbol: u64): Marker` |
| `symbol` | `(&Marker): u64` |
| `set_symbol` | `(&mut Marker, u64)` |

---

### PvP / Territory Components

#### Zone
**Module:** `components::zone` · **Bit:** 7
**Struct:** `Zone { zone_type: u8, controlled_by: u8, capture_progress: u64 }`

| Function | Signature |
|----------|-----------|
| `new` | `(zone_type: u8): Zone` |
| `zone_type` / `controlled_by` / `capture_progress` | getters |
| `is_controlled` | `(&Zone): bool` |
| `set_controlled_by` / `set_capture_progress` / `reset` | mutators |
| `zone_neutral()` / `zone_control_point()` / `zone_spawn()` | type constants |

---

#### Objective
**Module:** `components::objective` · **Bit:** 8
**Struct:** `Objective { objective_type: u8, holder: Option<ID>, origin_x: u64, origin_y: u64 }`

| Function | Signature |
|----------|-----------|
| `new` | `(type: u8, origin_x: u64, origin_y: u64): Objective` |
| `is_held` | `(&Objective): bool` |
| `pick_up` / `drop_objective` | mutators |
| `flag_type()` / `goal_type()` | type constants |

---

### Roguelike Components

#### Energy
**Module:** `components::energy` · **Bit:** 9
**Struct:** `Energy { current: u8, max: u8, regen_rate: u8 }`

| Function | Signature |
|----------|-----------|
| `new` | `(max: u8, regen_rate: u8): Energy` |
| `current` / `max` / `regen_rate` | getters |
| `spend` | `(&mut Energy, cost: u8)` — asserts enough |
| `regenerate` | `(&mut Energy)` — adds regen_rate, caps at max |
| `has_enough` | `(&Energy, cost: u8): bool` |

---

#### StatusEffect
**Module:** `components::status_effect` · **Bit:** 10
**Struct:** `StatusEffect { effect_type: u8, stacks: u64, duration: u8 }`

| Function | Signature |
|----------|-----------|
| `new` | `(effect_type: u8, stacks: u64, duration: u8): StatusEffect` |
| `is_expired` | `(&StatusEffect): bool` |
| `add_stacks` / `tick` | mutators |
| `poison()` / `strength()` / `weakness()` / `shield()` / `stun()` / `regen()` | type constants |

---

#### Stats
**Module:** `components::stats` · **Bit:** 11
**Struct:** `Stats { strength: u64, dexterity: u64, luck: u64 }`

| Function | Signature |
|----------|-----------|
| `new` | `(strength, dexterity, luck: u64): Stats` |
| `strength` / `dexterity` / `luck` | getters |
| `set_*` / `add_*` | mutators |

---

#### Deck
**Module:** `components::deck` · **Bit:** 12
**Struct:** `Deck { draw_pile: vector<CardData>, hand: vector<CardData>, discard_pile: vector<CardData> }`
**Struct:** `CardData { card_type: u8, cost: u8, value: u64 }` (has `store, copy, drop`)

| Function | Signature |
|----------|-----------|
| `new` | `(draw_pile: vector<CardData>): Deck` |
| `new_card` | `(card_type: u8, cost: u8, value: u64): CardData` |
| `draw` | `(&mut Deck): CardData` — moves from draw to hand |
| `play` | `(&mut Deck, hand_index: u64): CardData` — removes from hand |
| `discard` | `(&mut Deck, hand_index: u64)` — hand to discard |
| `hand_size` / `draw_pile_size` / `discard_pile_size` | getters |
| `shuffle_discard_into_draw` | `(&mut Deck, &Random, &mut TxContext)` |

---

#### Inventory
**Module:** `components::inventory` · **Bit:** 13
**Struct:** `Inventory { items: vector<u64>, max_size: u64 }`

| Function | Signature |
|----------|-----------|
| `new` | `(max_size: u64): Inventory` |
| `add_item` | `(&mut Inventory, item_id: u64)` — asserts not full |
| `remove_item` | `(&mut Inventory, index: u64): u64` |
| `has_item` | `(&Inventory, item_id: u64): bool` |
| `is_full` / `size` / `max_size` | getters |

---

#### Relic
**Module:** `components::relic` · **Bit:** 14
**Struct:** `Relic { relic_type: u8, modifier_type: u8, modifier_value: u64 }`

| Function | Signature |
|----------|-----------|
| `new` | `(relic_type: u8, modifier_type: u8, modifier_value: u64): Relic` |
| `relic_type` / `modifier_type` / `modifier_value` | getters |
| `set_modifier_value` | mutator |

---

#### Gold
**Module:** `components::gold` · **Bit:** 15
**Struct:** `Gold { amount: u64 }`

| Function | Signature |
|----------|-----------|
| `new` | `(amount: u64): Gold` |
| `amount` | `(&Gold): u64` |
| `add` | `(&mut Gold, amount: u64)` |
| `spend` | `(&mut Gold, amount: u64)` — asserts enough |
| `has_enough` | `(&Gold, amount: u64): bool` |

---

#### MapProgress
**Module:** `components::map_progress` · **Bit:** 16
**Struct:** `MapProgress { current_floor: u8, current_node: u8, floors_cleared: u8 }`

| Function | Signature |
|----------|-----------|
| `new` | `(): MapProgress` — starts at floor 0 |
| `current_floor` / `current_node` / `floors_cleared` | getters |
| `set_node` | `(&mut MapProgress, node: u8)` |
| `advance_floor` | `(&mut MapProgress)` — increments floor, resets node |

---

### Wagering Components

#### Wager
**Module:** `components::wager` · **Bit:** 18
**Struct:** `Wager { amount: u64, status: u8, player: address }` — `has store, copy, drop`

| Function | Signature |
|----------|-----------|
| `new` | `(amount: u64, player: address): Wager` — status starts at PENDING |
| `amount` / `status` / `player` | getters |
| `is_pending` / `is_locked` / `is_won` / `is_lost` / `is_refunded` | `(&Wager): bool` |
| `set_status` | `(&mut Wager, status: u8)` — validates status range |
| `status_pending()` / `status_locked()` / `status_won()` / `status_lost()` / `status_refunded()` | constants |

---

#### WagerPool
**Module:** `components::wager_pool` · **Bit:** 19
**Struct:** `WagerPool { pool: Balance<SUI>, wager_amount, player_count, max_players, settled, protocol_fee_bps, fee_recipient, payout_mode, created_at, timeout_ms }` — `has store` only (no copy/drop — `Balance<SUI>` prevents it)

| Function | Signature |
|----------|-----------|
| `new` | `(wager_amount, max_players, protocol_fee_bps, fee_recipient, payout_mode, created_at, timeout_ms): WagerPool` |
| `pool_value` / `wager_amount` / `player_count` / `max_players` / `is_settled` / `protocol_fee_bps` / `fee_recipient` / `payout_mode` / `created_at` / `timeout_ms` | getters |
| `is_full` | `(&WagerPool): bool` |
| `increment_player_count` / `set_settled` | mutators |
| `join_pool` | `(&mut WagerPool, Balance<SUI>)` — merge into pool |
| `split_pool` | `(&mut WagerPool, amount: u64): Balance<SUI>` — extract amount |
| `withdraw_all` | `(&mut WagerPool): Balance<SUI>` — extract all |
| `destroy_empty` | `(WagerPool)` — aborts if non-zero balance |
| `payout_winner_all()` / `payout_proportional()` / `payout_consolation()` | mode constants |

---

## Pattern

Every component follows this exact pattern:
```move
module components::X;

public struct X has store, copy, drop { ... }

public fun key(): String { ascii::string(b"x") }
public fun new(...): X { ... }
public fun add(entity: &mut Entity, val: X) {
    entity::add_component(entity, entity::x_bit(), key(), val);
}
public fun remove(entity: &mut Entity): X {
    entity::remove_component(entity, entity::x_bit(), key())
}
public fun borrow(entity: &Entity): &X {
    entity::borrow_component(entity, key())
}
public fun borrow_mut(entity: &mut Entity): &mut X {
    entity::borrow_mut_component(entity, key())
}
```
