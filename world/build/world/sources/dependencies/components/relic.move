/// Relic — Passive bonus modifier.
module components::relic;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

public struct Relic has store, copy, drop {
    relic_type: u8,
    modifier_type: u8,     // 0=flat, 1=percent, etc.
    modifier_value: u64,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"relic") }

// ─── Constructor ────────────────────────────

public fun new(relic_type: u8, modifier_type: u8, modifier_value: u64): Relic {
    Relic { relic_type, modifier_type, modifier_value }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, relic: Relic) {
    entity.add_component(entity::relic_bit(), key(), relic);
}

public fun remove(entity: &mut Entity): Relic {
    entity.remove_component(entity::relic_bit(), key())
}

public fun borrow(entity: &Entity): &Relic {
    entity.borrow_component<Relic>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Relic {
    entity.borrow_mut_component<Relic>(key())
}

// ─── Getters ────────────────────────────────

public fun relic_type(self: &Relic): u8 { self.relic_type }
public fun modifier_type(self: &Relic): u8 { self.modifier_type }
public fun modifier_value(self: &Relic): u64 { self.modifier_value }

// ─── Setters ────────────────────────────────

public fun set_modifier_value(self: &mut Relic, val: u64) { self.modifier_value = val; }

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Relic { Relic { relic_type: 0, modifier_type: 0, modifier_value: 5 } }
