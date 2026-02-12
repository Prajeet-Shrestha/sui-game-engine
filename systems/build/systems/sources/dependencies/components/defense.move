/// Defense — Armor and block values.
module components::defense;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

public struct Defense has store, copy, drop {
    armor: u64,
    block: u64,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"defense") }

// ─── Constructor ────────────────────────────

public fun new(armor: u64, block: u64): Defense {
    Defense { armor, block }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, defense: Defense) {
    entity.add_component(entity::defense_bit(), key(), defense);
}

public fun remove(entity: &mut Entity): Defense {
    entity.remove_component(entity::defense_bit(), key())
}

public fun borrow(entity: &Entity): &Defense {
    entity.borrow_component<Defense>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Defense {
    entity.borrow_mut_component<Defense>(key())
}

// ─── Getters ────────────────────────────────

public fun armor(self: &Defense): u64 { self.armor }
public fun block(self: &Defense): u64 { self.block }

/// Calculate effective damage reduction.
public fun reduce_damage(self: &Defense, incoming: u64): u64 {
    let blocked = std::u64::min(self.block, incoming);
    let after_block = incoming - blocked;
    let absorbed = std::u64::min(self.armor, after_block);
    after_block - absorbed
}

// ─── Setters ────────────────────────────────

public fun set_armor(self: &mut Defense, armor: u64) { self.armor = armor; }
public fun set_block(self: &mut Defense, block: u64) { self.block = block; }

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Defense { Defense { armor: 5, block: 0 } }
