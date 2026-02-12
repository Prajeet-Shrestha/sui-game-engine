/// Gold — In-game currency.
module components::gold;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

public struct Gold has store, copy, drop {
    amount: u64,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"gold") }

// ─── Constructor ────────────────────────────

public fun new(amount: u64): Gold {
    Gold { amount }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, gold: Gold) {
    entity.add_component(entity::gold_bit(), key(), gold);
}

public fun remove(entity: &mut Entity): Gold {
    entity.remove_component(entity::gold_bit(), key())
}

public fun borrow(entity: &Entity): &Gold {
    entity.borrow_component<Gold>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Gold {
    entity.borrow_mut_component<Gold>(key())
}

// ─── Getters ────────────────────────────────

public fun amount(self: &Gold): u64 { self.amount }
public fun has_enough(self: &Gold, cost: u64): bool { self.amount >= cost }

// ─── Setters ────────────────────────────────

public fun earn(self: &mut Gold, amount: u64) {
    self.amount = self.amount + amount;
}

public fun spend(self: &mut Gold, cost: u64) {
    assert!(self.amount >= cost, 0);
    self.amount = self.amount - cost;
}

public fun set_amount(self: &mut Gold, amount: u64) { self.amount = amount; }

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Gold { Gold { amount: 100 } }
