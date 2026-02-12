/// Movement — Speed and movement pattern.
module components::movement;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

public struct Movement has store, copy, drop {
    speed: u8,
    move_pattern: u8,  // 0=walk, 1=fly, 2=teleport, etc.
}

// ─── Move Pattern Constants ─────────────────

const PATTERN_WALK: u8 = 0;
const PATTERN_FLY: u8 = 1;
const PATTERN_TELEPORT: u8 = 2;
const PATTERN_DIAGONAL: u8 = 3;
const PATTERN_L_SHAPE: u8 = 4;   // chess knight

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"movement") }

// ─── Constructor ────────────────────────────

public fun new(speed: u8, move_pattern: u8): Movement {
    Movement { speed, move_pattern }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, movement: Movement) {
    entity.add_component(entity::movement_bit(), key(), movement);
}

public fun remove(entity: &mut Entity): Movement {
    entity.remove_component(entity::movement_bit(), key())
}

public fun borrow(entity: &Entity): &Movement {
    entity.borrow_component<Movement>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Movement {
    entity.borrow_mut_component<Movement>(key())
}

// ─── Getters ────────────────────────────────

public fun speed(self: &Movement): u8 { self.speed }
public fun move_pattern(self: &Movement): u8 { self.move_pattern }

// ─── Pattern Accessors ──────────────────────

public fun pattern_walk(): u8 { PATTERN_WALK }
public fun pattern_fly(): u8 { PATTERN_FLY }
public fun pattern_teleport(): u8 { PATTERN_TELEPORT }
public fun pattern_diagonal(): u8 { PATTERN_DIAGONAL }
public fun pattern_l_shape(): u8 { PATTERN_L_SHAPE }

// ─── Setters ────────────────────────────────

public fun set_speed(self: &mut Movement, speed: u8) { self.speed = speed; }
public fun set_move_pattern(self: &mut Movement, p: u8) { self.move_pattern = p; }

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Movement { Movement { speed: 1, move_pattern: 0 } }
