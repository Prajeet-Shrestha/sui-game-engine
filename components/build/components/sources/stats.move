/// Stats — RPG-like stat modifiers.
module components::stats;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

public struct Stats has store, copy, drop {
    strength: u64,
    dexterity: u64,
    luck: u64,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"stats") }

// ─── Constructor ────────────────────────────

public fun new(strength: u64, dexterity: u64, luck: u64): Stats {
    Stats { strength, dexterity, luck }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, stats: Stats) {
    entity.add_component(entity::stats_bit(), key(), stats);
}

public fun remove(entity: &mut Entity): Stats {
    entity.remove_component(entity::stats_bit(), key())
}

public fun borrow(entity: &Entity): &Stats {
    entity.borrow_component<Stats>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Stats {
    entity.borrow_mut_component<Stats>(key())
}

// ─── Getters ────────────────────────────────

public fun strength(self: &Stats): u64 { self.strength }
public fun dexterity(self: &Stats): u64 { self.dexterity }
public fun luck(self: &Stats): u64 { self.luck }

// ─── Setters ────────────────────────────────

public fun set_strength(self: &mut Stats, val: u64) { self.strength = val; }
public fun set_dexterity(self: &mut Stats, val: u64) { self.dexterity = val; }
public fun set_luck(self: &mut Stats, val: u64) { self.luck = val; }

public fun add_strength(self: &mut Stats, val: u64) { self.strength = self.strength + val; }
public fun add_dexterity(self: &mut Stats, val: u64) { self.dexterity = self.dexterity + val; }
public fun add_luck(self: &mut Stats, val: u64) { self.luck = self.luck + val; }

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Stats { Stats { strength: 10, dexterity: 10, luck: 10 } }
