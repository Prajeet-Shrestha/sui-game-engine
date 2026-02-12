/// Marker — Board game symbol (e.g. X=1, O=2).
module components::marker;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

public struct Marker has store, copy, drop {
    symbol: u8,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"marker") }

// ─── Constructor ────────────────────────────

public fun new(symbol: u8): Marker {
    Marker { symbol }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, marker: Marker) {
    entity.add_component(entity::marker_bit(), key(), marker);
}

public fun remove(entity: &mut Entity): Marker {
    entity.remove_component(entity::marker_bit(), key())
}

public fun borrow(entity: &Entity): &Marker {
    entity.borrow_component<Marker>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Marker {
    entity.borrow_mut_component<Marker>(key())
}

// ─── Getters ────────────────────────────────

public fun symbol(self: &Marker): u8 { self.symbol }

// ─── Setters ────────────────────────────────

public fun set_symbol(self: &mut Marker, symbol: u8) { self.symbol = symbol; }

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Marker { Marker { symbol: 1 } }
