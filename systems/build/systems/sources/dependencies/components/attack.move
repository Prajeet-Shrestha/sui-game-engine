/// Attack — Damage, range, and cooldown.
module components::attack;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

public struct Attack has store, copy, drop {
    damage: u64,
    range: u8,
    cooldown_ms: u64,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"attack") }

// ─── Constructor ────────────────────────────

public fun new(damage: u64, range: u8, cooldown_ms: u64): Attack {
    Attack { damage, range, cooldown_ms }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, atk: Attack) {
    entity.add_component(entity::attack_bit(), key(), atk);
}

public fun remove(entity: &mut Entity): Attack {
    entity.remove_component(entity::attack_bit(), key())
}

public fun borrow(entity: &Entity): &Attack {
    entity.borrow_component<Attack>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Attack {
    entity.borrow_mut_component<Attack>(key())
}

// ─── Getters ────────────────────────────────

public fun damage(self: &Attack): u64 { self.damage }
public fun range(self: &Attack): u8 { self.range }
public fun cooldown_ms(self: &Attack): u64 { self.cooldown_ms }

// ─── Setters ────────────────────────────────

public fun set_damage(self: &mut Attack, damage: u64) { self.damage = damage; }
public fun set_range(self: &mut Attack, range: u8) { self.range = range; }
public fun set_cooldown_ms(self: &mut Attack, cd: u64) { self.cooldown_ms = cd; }

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Attack { Attack { damage: 10, range: 1, cooldown_ms: 0 } }
