# Entity Package

> **Package:** `entity` · **Module:** `entity::entity`
> **Path:** `engine/entity/`
> **Dependencies:** Sui Framework (MoveStdlib, `sui::dynamic_field`, `sui::clock`)

---

## Concept

An **Entity** is the core ECS primitive — a lightweight Sui object that acts as a container. It holds no game data itself; instead, **components** (Position, Health, Attack, etc.) are attached as dynamic fields keyed by ascii strings.

A **u256 bitmask** (`component_mask`) provides O(1) "has component?" checks without dynamic field lookups. Each component type is assigned a unique power-of-two constant.

```
Entity (Sui Object)
├── id: UID
├── type: String        ← "player", "npc", "item", "tile", etc.
├── created_at: u64     ← timestamp in ms
├── component_mask: u256 ← O(1) presence checking
└── [dynamic fields]    ← actual component data
```

---

## Struct

```move
public struct Entity has key {
    id: UID,
    type: String,
    created_at: u64,
    component_mask: u256,
}
```

---

## API Reference

### Lifecycle

| Function | Signature | Description |
|----------|-----------|-------------|
| `new` | `(entity_type: String, clock: &Clock, ctx: &mut TxContext): Entity` | Create a new entity. Emits `EntityCreated`. |
| `share` | `(entity: Entity)` | Make entity a shared object. |
| `destroy` | `(entity: Entity)` | Destroy entity. All components must be removed first. Emits `EntityDestroyed`. |

### Component Operations

| Function | Signature | Description |
|----------|-----------|-------------|
| `add_component<T>` | `(entity: &mut Entity, bit: u256, key: String, value: T)` | Attach component. Sets bit in mask. Aborts if already exists. |
| `remove_component<T>` | `(entity: &mut Entity, bit: u256, key: String): T` | Remove and return component. Clears bit. |
| `has_component` | `(entity: &Entity, bit: u256): bool` | O(1) bitmask check. Can OR bits: `has_component(e, POSITION \| HEALTH)`. |
| `has_component_by_key` | `(entity: &Entity, key: String): bool` | Dynamic field existence check by key string. |
| `borrow_component<T>` | `(entity: &Entity, key: String): &T` | Borrow component immutably. |
| `borrow_mut_component<T>` | `(entity: &mut Entity, key: String): &mut T` | Borrow component mutably. |

### Getters

| Function | Returns | Description |
|----------|---------|-------------|
| `entity_type` | `String` | Type tag (e.g. "player") |
| `component_mask` | `u256` | Raw bitmask |
| `created_at` | `u64` | Creation timestamp (ms) |
| `uid` / `uid_mut` | `&UID` / `&mut UID` | Access UID for external dynamic field ops |

### Component Bit Constants

Each component is assigned a unique power-of-two:

| Function | Bit | Component |
|----------|-----|-----------|
| `position_bit()` | 0 | Position |
| `health_bit()` | 1 | Health |
| `attack_bit()` | 2 | Attack |
| `identity_bit()` | 3 | Identity |
| `movement_bit()` | 4 | Movement |
| `defense_bit()` | 5 | Defense |
| `team_bit()` | 6 | Team |
| `zone_bit()` | 7 | Zone |
| `objective_bit()` | 8 | Objective |
| `energy_bit()` | 9 | Energy |
| `status_effect_bit()` | 10 | StatusEffect |
| `stats_bit()` | 11 | Stats |
| `deck_bit()` | 12 | Deck |
| `inventory_bit()` | 13 | Inventory |
| `relic_bit()` | 14 | Relic |
| `gold_bit()` | 15 | Gold |
| `map_progress_bit()` | 16 | MapProgress |
| `marker_bit()` | 17 | Marker |
| `wager_bit()` | 18 | Wager |
| `wager_pool_bit()` | 19 | WagerPool |

### Entity Type Constants

| Function | Value |
|----------|-------|
| `player_type()` | `b"player"` |
| `npc_type()` | `b"npc"` |
| `item_type()` | `b"item"` |
| `tile_type()` | `b"tile"` |
| `grid_type()` | `b"grid"` |
| `projectile_type()` | `b"projectile"` |

### Events

| Event | Fields | Emitted By |
|-------|--------|------------|
| `EntityCreated` | `entity_id`, `entity_type`, `created_at` | `new()` |
| `EntityDestroyed` | `entity_id` | `destroy()` |

---

## Errors

| Constant | Code | Meaning |
|----------|------|---------|
| `EComponentAlreadyExists` | 0 | Trying to add a component that already exists |
| `EComponentNotFound` | 1 | Trying to remove/access a component that doesn't exist |

---

## Usage

```move
use entity::entity;
use sui::clock::Clock;

// Create
let e = entity::new(ascii::string(b"player"), &clock, ctx);

// Check components
if (e.has_component(entity::health_bit() | entity::position_bit())) { ... }

// Share for multi-party access
entity::share(e);
```
