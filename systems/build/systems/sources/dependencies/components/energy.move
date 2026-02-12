/// Energy — Action resource (mana, stamina, action points).
module components::energy;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

public struct Energy has store, copy, drop {
    current: u8,
    max: u8,
    regen: u8,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"energy") }

// ─── Constructor ────────────────────────────

public fun new(max: u8, regen: u8): Energy {
    Energy { current: max, max, regen }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, energy: Energy) {
    entity.add_component(entity::energy_bit(), key(), energy);
}

public fun remove(entity: &mut Entity): Energy {
    entity.remove_component(entity::energy_bit(), key())
}

public fun borrow(entity: &Entity): &Energy {
    entity.borrow_component<Energy>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Energy {
    entity.borrow_mut_component<Energy>(key())
}

// ─── Getters ────────────────────────────────

public fun current(self: &Energy): u8 { self.current }
public fun max(self: &Energy): u8 { self.max }
public fun regen(self: &Energy): u8 { self.regen }
public fun has_enough(self: &Energy, cost: u8): bool { self.current >= cost }

// ─── Setters ────────────────────────────────

public fun spend(self: &mut Energy, cost: u8) {
    assert!(self.current >= cost, 0);
    self.current = self.current - cost;
}

public fun regenerate(self: &mut Energy) {
    let new_val = (self.current as u16) + (self.regen as u16);
    if (new_val > (self.max as u16)) {
        self.current = self.max;
    } else {
        self.current = (new_val as u8);
    };
}

public fun set_current(self: &mut Energy, val: u8) { self.current = val; }
public fun set_max(self: &mut Energy, val: u8) { self.max = val; }

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Energy { Energy { current: 3, max: 3, regen: 1 } }

#[test_only]
public fun set_current_for_testing(self: &mut Energy, value: u8) {
    self.current = value;
}
