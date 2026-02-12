/// Objective — Flags, goals, and capture-the-flag mechanics.
module components::objective;

use std::ascii::{Self, String};
use sui::object::ID;
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

/// `store, drop` — Option<ID> is not copyable.
public struct Objective has store, drop {
    objective_type: u8,         // 0=flag, 1=goal, etc.
    holder: Option<ID>,         // entity ID of whoever holds this objective
    origin_x: u64,              // where it spawned (for return mechanics)
    origin_y: u64,
}

// ─── Objective Type Constants ───────────────

const OBJECTIVE_FLAG: u8 = 0;
const OBJECTIVE_GOAL: u8 = 1;

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"objective") }

// ─── Constructor ────────────────────────────

public fun new(objective_type: u8, origin_x: u64, origin_y: u64): Objective {
    Objective {
        objective_type,
        holder: option::none(),
        origin_x,
        origin_y,
    }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, obj: Objective) {
    entity.add_component(entity::objective_bit(), key(), obj);
}

public fun remove(entity: &mut Entity): Objective {
    entity.remove_component(entity::objective_bit(), key())
}

public fun borrow(entity: &Entity): &Objective {
    entity.borrow_component<Objective>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Objective {
    entity.borrow_mut_component<Objective>(key())
}

// ─── Getters ────────────────────────────────

public fun objective_type(self: &Objective): u8 { self.objective_type }
public fun holder(self: &Objective): &Option<ID> { &self.holder }
public fun origin_x(self: &Objective): u64 { self.origin_x }
public fun origin_y(self: &Objective): u64 { self.origin_y }
public fun is_held(self: &Objective): bool { self.holder.is_some() }

// ─── Type Accessors ─────────────────────────

public fun flag_type(): u8 { OBJECTIVE_FLAG }
public fun goal_type(): u8 { OBJECTIVE_GOAL }

// ─── Setters ────────────────────────────────

public fun pick_up(self: &mut Objective, holder_id: ID) {
    self.holder = option::some(holder_id);
}

public fun drop_objective(self: &mut Objective) {
    self.holder = option::none();
}

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Objective {
    Objective { objective_type: 0, holder: option::none(), origin_x: 0, origin_y: 0 }
}
