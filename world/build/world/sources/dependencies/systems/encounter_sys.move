/// EncounterSystem — Generate encounters for roguelike floors.
/// Creates enemy entities directly (no spawn_sys import).
module systems::encounter_sys;

use std::ascii;
use sui::clock::Clock;
use sui::event;
use entity::entity;

// Components
use components::position;
use components::identity;
use components::health;
use components::attack;

// ─── Events ─────────────────────────────────

public struct EncounterGeneratedEvent has copy, drop {
    floor: u8,
    enemy_count: u64,
}

// ─── Entry Function ─────────────────────────

/// Generate an encounter for a given floor level.
/// Spawns enemies with stats scaled by floor.
/// Returns a vector of enemy entities (caller must share or transfer them).
public fun generate_encounter(
    floor: u8,
    enemy_count: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): vector<entity::Entity> {
    let mut enemies = vector[];
    let floor_u64 = (floor as u64);

    let mut i: u64 = 0;
    while (i < enemy_count) {
        let entity_type = ascii::string(entity::npc_type());
        let mut e = entity::new(entity_type, clock, ctx);

        // Position enemies in a row starting at (i, 0)
        position::add(&mut e, position::new(i, 0));
        identity::add(&mut e, identity::new(ascii::string(b"enemy"), 1));

        // Scale HP and damage by floor
        let hp = 20 + (floor_u64 * 10);
        let dmg = 5 + (floor_u64 * 3);
        health::add(&mut e, health::new(hp));
        attack::add(&mut e, attack::new(dmg, 1, 0));

        enemies.push_back(e);
        i = i + 1;
    };

    event::emit(EncounterGeneratedEvent {
        floor,
        enemy_count,
    });

    enemies
}
