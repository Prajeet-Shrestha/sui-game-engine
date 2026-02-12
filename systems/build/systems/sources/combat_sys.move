/// CombatSystem — Damage pipeline with range checking and defense.
module systems::combat_sys;

use sui::event;
use entity::entity::{Self, Entity};

// Components
use components::position;
use components::attack;
use components::health;
use components::defense;

// ─── Error Constants ────────────────────────

const EAttackerDead: u64 = 0;
const EDefenderDead: u64 = 1;
const EOutOfRange: u64 = 2;

// ─── Events ─────────────────────────────────

public struct AttackEvent has copy, drop {
    attacker_id: ID,
    defender_id: ID,
    raw_damage: u64,
    actual_damage: u64,
}

public struct DeathEvent has copy, drop {
    entity_id: ID,
    killed_by: ID,
}

// ─── Inline Helpers ─────────────────────────

fun abs_diff(a: u64, b: u64): u64 {
    if (a >= b) { a - b } else { b - a }
}

fun manhattan_distance(x1: u64, y1: u64, x2: u64, y2: u64): u64 {
    abs_diff(x1, x2) + abs_diff(y1, y2)
}

// ─── Entry Function ─────────────────────────

/// Attack a defender. Checks range, applies defense reduction, deals damage.
/// Returns the actual damage dealt.
public fun attack(
    attacker: &Entity,
    defender: &mut Entity,
): u64 {
    // Capture IDs up front (before any mutable borrows)
    let attacker_id = object::id(attacker);
    let defender_id = object::id(defender);

    // Validate both alive
    let atk_hp = health::borrow(attacker);
    assert!(atk_hp.is_alive(), EAttackerDead);
    let def_hp = health::borrow(defender);
    assert!(def_hp.is_alive(), EDefenderDead);

    // Check range
    let atk_pos = position::borrow(attacker);
    let def_pos = position::borrow(defender);
    let dist = manhattan_distance(atk_pos.x(), atk_pos.y(), def_pos.x(), def_pos.y());

    let atk = attack::borrow(attacker);
    assert!(dist <= (atk.range() as u64), EOutOfRange);

    let raw_damage = atk.damage();

    // Apply defense if defender has it
    let actual_damage = if (defender.has_component(entity::defense_bit())) {
        let def = defense::borrow(defender);
        def.reduce_damage(raw_damage)
    } else {
        raw_damage
    };

    // Deal damage
    let def_hp_mut = health::borrow_mut(defender);
    def_hp_mut.take_damage(actual_damage);
    let is_dead = !def_hp_mut.is_alive();

    // Emit events (no active mutable borrows here)
    event::emit(AttackEvent {
        attacker_id,
        defender_id,
        raw_damage,
        actual_damage,
    });

    if (is_dead) {
        event::emit(DeathEvent {
            entity_id: defender_id,
            killed_by: attacker_id,
        });
    };

    actual_damage
}
