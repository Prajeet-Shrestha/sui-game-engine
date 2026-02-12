/// SpawnSystem — Entity factories for creating game entities with initial components.
module systems::spawn_sys;

use std::ascii::{Self, String};
use sui::clock::Clock;
use sui::event;
use entity::entity::{Self, Entity};

// Components
use components::position;
use components::identity;
use components::health;
use components::attack;
use components::team;
use components::marker;

// ─── Events ─────────────────────────────────

public struct SpawnEvent has copy, drop {
    entity_id: ID,
    entity_type: String,
    x: u64,
    y: u64,
    timestamp: u64,
}

// ─── Spawn Functions ────────────────────────

/// Spawn a player entity with position, identity, health, and team.
public fun spawn_player(
    name: String,
    x: u64,
    y: u64,
    max_hp: u64,
    team_id: u8,
    clock: &Clock,
    ctx: &mut TxContext,
): Entity {
    let entity_type = ascii::string(entity::player_type());
    let mut e = entity::new(entity_type, clock, ctx);

    position::add(&mut e, position::new(x, y));
    identity::add(&mut e, identity::new(name, 0));
    health::add(&mut e, health::new(max_hp));
    team::add(&mut e, team::new(team_id));

    event::emit(SpawnEvent {
        entity_id: object::id(&e),
        entity_type,
        x, y,
        timestamp: clock.timestamp_ms(),
    });

    e
}

/// Spawn an NPC entity with position, identity, health, and attack.
public fun spawn_npc(
    name: String,
    x: u64,
    y: u64,
    max_hp: u64,
    atk_damage: u64,
    atk_range: u8,
    clock: &Clock,
    ctx: &mut TxContext,
): Entity {
    let entity_type = ascii::string(entity::npc_type());
    let mut e = entity::new(entity_type, clock, ctx);

    position::add(&mut e, position::new(x, y));
    identity::add(&mut e, identity::new(name, 1));
    health::add(&mut e, health::new(max_hp));
    attack::add(&mut e, attack::new(atk_damage, atk_range, 0));

    event::emit(SpawnEvent {
        entity_id: object::id(&e),
        entity_type,
        x, y,
        timestamp: clock.timestamp_ms(),
    });

    e
}

/// Spawn a tile entity with position and marker.
public fun spawn_tile(
    x: u64,
    y: u64,
    symbol: u8,
    clock: &Clock,
    ctx: &mut TxContext,
): Entity {
    let entity_type = ascii::string(entity::tile_type());
    let mut e = entity::new(entity_type, clock, ctx);

    position::add(&mut e, position::new(x, y));
    marker::add(&mut e, marker::new(symbol));

    event::emit(SpawnEvent {
        entity_id: object::id(&e),
        entity_type,
        x, y,
        timestamp: clock.timestamp_ms(),
    });

    e
}
