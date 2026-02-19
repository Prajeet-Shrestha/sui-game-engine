/// Entity — Core ECS primitive.
///
/// An Entity is a lightweight Sui object that serves as a container for
/// components attached via dynamic fields. It holds a bitmask (`component_mask`)
/// for O(1) "has this component?" checks without a dynamic field lookup.
module entity::entity;

use std::ascii::String;
use sui::dynamic_field as df;
use sui::clock::Clock;
use sui::event;

// ─── Entity Struct ──────────────────────────────────────────────

/// A game entity — can be player, NPC, item, tile, etc.
/// Components are attached as dynamic fields keyed by `ascii::String`.
public struct Entity has key {
    id: UID,
    /// Human-readable type tag (e.g. b"player", b"npc").
    `type`: String,
    /// Timestamp (ms) when the entity was created.
    created_at: u64,
    /// Bitmask for O(1) component presence checks.
    /// Each component type is assigned a unique power-of-two constant.
    component_mask: u256,
}

// ─── Entity Type Constants ──────────────────────────────────────

const ENTITY_TYPE_PLAYER: vector<u8> = b"player";
const ENTITY_TYPE_NPC: vector<u8> = b"npc";
const ENTITY_TYPE_ITEM: vector<u8> = b"item";
const ENTITY_TYPE_TILE: vector<u8> = b"tile";
const ENTITY_TYPE_GRID: vector<u8> = b"grid";
const ENTITY_TYPE_PROJECTILE: vector<u8> = b"projectile";

// ─── Component Bit Constants ────────────────────────────────────
// Each component gets a unique power-of-two bit in the u256 mask.

const COMPONENT_POSITION: u256       = 1;          // bit 0
const COMPONENT_HEALTH: u256         = 2;          // bit 1
const COMPONENT_ATTACK: u256         = 4;          // bit 2
const COMPONENT_IDENTITY: u256       = 8;          // bit 3
const COMPONENT_MOVEMENT: u256       = 16;         // bit 4
const COMPONENT_DEFENSE: u256        = 32;         // bit 5
const COMPONENT_TEAM: u256           = 64;         // bit 6
const COMPONENT_ZONE: u256           = 128;        // bit 7
const COMPONENT_OBJECTIVE: u256      = 256;        // bit 8
const COMPONENT_ENERGY: u256         = 512;        // bit 9
const COMPONENT_STATUS_EFFECT: u256  = 1024;       // bit 10
const COMPONENT_STATS: u256          = 2048;       // bit 11
const COMPONENT_DECK: u256           = 4096;       // bit 12
const COMPONENT_INVENTORY: u256      = 8192;       // bit 13
const COMPONENT_RELIC: u256          = 16384;      // bit 14
const COMPONENT_GOLD: u256           = 32768;      // bit 15
const COMPONENT_MAP_PROGRESS: u256   = 65536;      // bit 16
const COMPONENT_MARKER: u256         = 131072;     // bit 17
const COMPONENT_WAGER: u256          = 262144;     // bit 18
const COMPONENT_WAGER_POOL: u256     = 524288;     // bit 19

// ─── Error Constants ────────────────────────────────────────────

const EComponentAlreadyExists: u64 = 0;
const EComponentNotFound: u64 = 1;

// ─── Events ─────────────────────────────────────────────────────

public struct EntityCreated has copy, drop {
    entity_id: ID,
    entity_type: String,
    created_at: u64,
}

public struct EntityDestroyed has copy, drop {
    entity_id: ID,
}

// ─── Constructor ────────────────────────────────────────────────

/// Create a new entity with the given type tag.
/// The entity starts with an empty component mask.
public fun new(
    entity_type: String,
    clock: &Clock,
    ctx: &mut TxContext,
): Entity {
    let ts = clock.timestamp_ms();
    let entity = Entity {
        id: object::new(ctx),
        `type`: entity_type,
        created_at: ts,
        component_mask: 0,
    };
    event::emit(EntityCreated {
        entity_id: object::id(&entity),
        entity_type,
        created_at: ts,
    });
    entity
}

// ─── Lifecycle ──────────────────────────────────────────────────

/// Make the entity a shared object so any transaction can operate on it.
public fun share(entity: Entity) {
    transfer::share_object(entity);
}

/// Destroy an entity. The entity MUST have no dynamic fields remaining
/// (all components must be removed first), otherwise this will abort.
public fun destroy(entity: Entity) {
    let Entity { id, .. } = entity;
    event::emit(EntityDestroyed {
        entity_id: id.to_inner(),
    });
    id.delete();
}

// ─── Component Operations ───────────────────────────────────────

/// Attach a component to this entity.
/// `component_bit` — the unique power-of-two constant for this component type.
/// `key` — the ascii string key (e.g. `b"health".to_ascii_string()`).
/// `value` — the component data (must have `store`).
///
/// Aborts if the component bit is already set in the mask OR the dynamic
/// field already exists.
public fun add_component<T: store>(
    entity: &mut Entity,
    component_bit: u256,
    key: String,
    value: T,
) {
    assert!((entity.component_mask & component_bit) == 0, EComponentAlreadyExists);
    entity.component_mask = entity.component_mask | component_bit;
    df::add(&mut entity.id, key, value);
}

/// Remove a component from this entity and return its value.
/// Clears the corresponding bit in the mask.
///
/// Aborts if the component bit is not set or the dynamic field doesn't exist.
public fun remove_component<T: store>(
    entity: &mut Entity,
    component_bit: u256,
    key: String,
): T {
    assert!((entity.component_mask & component_bit) != 0, EComponentNotFound);
    entity.component_mask = entity.component_mask & (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ^ component_bit);
    df::remove<String, T>(&mut entity.id, key)
}

/// O(1) bitmask check: does this entity have the given component bit(s) set?
/// You can OR multiple bits together to check for several at once:
///   `entity.has_component(COMPONENT_POSITION | COMPONENT_HEALTH)`
public fun has_component(entity: &Entity, component_bit: u256): bool {
    (entity.component_mask & component_bit) == component_bit
}

/// Dynamic-field existence check by key string.
/// Slightly more expensive than `has_component` but does not require
/// knowing the component bit.
public fun has_component_by_key(entity: &Entity, key: String): bool {
    df::exists_(&entity.id, key)
}

/// Borrow a component immutably.
public fun borrow_component<T: store>(entity: &Entity, key: String): &T {
    df::borrow<String, T>(&entity.id, key)
}

/// Borrow a component mutably.
public fun borrow_mut_component<T: store>(entity: &mut Entity, key: String): &mut T {
    df::borrow_mut<String, T>(&mut entity.id, key)
}

// ─── Getters ────────────────────────────────────────────────────

/// Returns the entity's type tag.
public fun entity_type(entity: &Entity): String {
    entity.`type`
}

/// Returns the raw component bitmask.
public fun component_mask(entity: &Entity): u256 {
    entity.component_mask
}

/// Returns the creation timestamp (ms).
public fun created_at(entity: &Entity): u64 {
    entity.created_at
}

/// Borrow the entity's UID (for external dynamic field operations).
public fun uid(entity: &Entity): &UID {
    &entity.id
}

/// Borrow the entity's UID mutably (for external dynamic field operations).
public fun uid_mut(entity: &mut Entity): &mut UID {
    &mut entity.id
}

// ─── Public Accessors for Constants ─────────────────────────────
// These let other packages reference component bits without hardcoding.

public fun position_bit(): u256 { COMPONENT_POSITION }
public fun health_bit(): u256 { COMPONENT_HEALTH }
public fun attack_bit(): u256 { COMPONENT_ATTACK }
public fun identity_bit(): u256 { COMPONENT_IDENTITY }
public fun movement_bit(): u256 { COMPONENT_MOVEMENT }
public fun defense_bit(): u256 { COMPONENT_DEFENSE }
public fun team_bit(): u256 { COMPONENT_TEAM }
public fun zone_bit(): u256 { COMPONENT_ZONE }
public fun objective_bit(): u256 { COMPONENT_OBJECTIVE }
public fun energy_bit(): u256 { COMPONENT_ENERGY }
public fun status_effect_bit(): u256 { COMPONENT_STATUS_EFFECT }
public fun stats_bit(): u256 { COMPONENT_STATS }
public fun deck_bit(): u256 { COMPONENT_DECK }
public fun inventory_bit(): u256 { COMPONENT_INVENTORY }
public fun relic_bit(): u256 { COMPONENT_RELIC }
public fun gold_bit(): u256 { COMPONENT_GOLD }
public fun map_progress_bit(): u256 { COMPONENT_MAP_PROGRESS }
public fun marker_bit(): u256 { COMPONENT_MARKER }
public fun wager_bit(): u256 { COMPONENT_WAGER }
public fun wager_pool_bit(): u256 { COMPONENT_WAGER_POOL }

// ─── Entity Type Accessors ──────────────────────────────────────

public fun player_type(): vector<u8> { ENTITY_TYPE_PLAYER }
public fun npc_type(): vector<u8> { ENTITY_TYPE_NPC }
public fun item_type(): vector<u8> { ENTITY_TYPE_ITEM }
public fun tile_type(): vector<u8> { ENTITY_TYPE_TILE }
public fun grid_type(): vector<u8> { ENTITY_TYPE_GRID }
public fun projectile_type(): vector<u8> { ENTITY_TYPE_PROJECTILE }

// ─── Test Helpers ───────────────────────────────────────────────

#[test_only]
/// Create a minimal entity for unit tests (no Clock required).
public fun new_for_testing(ctx: &mut TxContext): Entity {
    Entity {
        id: object::new(ctx),
        `type`: b"test".to_ascii_string(),
        created_at: 0,
        component_mask: 0,
    }
}
