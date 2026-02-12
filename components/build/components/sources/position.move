/// Position — 2D grid coordinates.
module components::position;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

public struct Position has store, copy, drop {
    x: u64,
    y: u64,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"position") }

// ─── Constructor ────────────────────────────

public fun new(x: u64, y: u64): Position {
    Position { x, y }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, pos: Position) {
    entity.add_component(entity::position_bit(), key(), pos);
}

public fun remove(entity: &mut Entity): Position {
    entity.remove_component(entity::position_bit(), key())
}

public fun borrow(entity: &Entity): &Position {
    entity.borrow_component<Position>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Position {
    entity.borrow_mut_component<Position>(key())
}

// ─── Getters ────────────────────────────────

public fun x(self: &Position): u64 { self.x }
public fun y(self: &Position): u64 { self.y }

// ─── Setters ────────────────────────────────

public fun set_x(self: &mut Position, x: u64) { self.x = x; }
public fun set_y(self: &mut Position, y: u64) { self.y = y; }
public fun set(self: &mut Position, x: u64, y: u64) {
    self.x = x;
    self.y = y;
}

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Position { Position { x: 0, y: 0 } }
