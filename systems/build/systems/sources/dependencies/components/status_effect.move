/// StatusEffect — Buff/debuff tracking (poison, strength, weakness, etc.)
module components::status_effect;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

public struct StatusEffect has store, copy, drop {
    effect_type: u8,    // which effect
    stacks: u64,        // intensity / stack count
    duration: u8,       // remaining turns
}

// ─── Effect Type Constants ──────────────────

const EFFECT_POISON: u8 = 0;
const EFFECT_STRENGTH: u8 = 1;
const EFFECT_WEAKNESS: u8 = 2;
const EFFECT_SHIELD: u8 = 3;
const EFFECT_STUN: u8 = 4;
const EFFECT_REGEN: u8 = 5;

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"status_effect") }

// ─── Constructor ────────────────────────────

public fun new(effect_type: u8, stacks: u64, duration: u8): StatusEffect {
    StatusEffect { effect_type, stacks, duration }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, effect: StatusEffect) {
    entity.add_component(entity::status_effect_bit(), key(), effect);
}

public fun remove(entity: &mut Entity): StatusEffect {
    entity.remove_component(entity::status_effect_bit(), key())
}

public fun borrow(entity: &Entity): &StatusEffect {
    entity.borrow_component<StatusEffect>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut StatusEffect {
    entity.borrow_mut_component<StatusEffect>(key())
}

// ─── Getters ────────────────────────────────

public fun effect_type(self: &StatusEffect): u8 { self.effect_type }
public fun stacks(self: &StatusEffect): u64 { self.stacks }
public fun duration(self: &StatusEffect): u8 { self.duration }
public fun is_expired(self: &StatusEffect): bool { self.duration == 0 }

// ─── Effect Type Accessors ──────────────────

public fun poison(): u8 { EFFECT_POISON }
public fun strength(): u8 { EFFECT_STRENGTH }
public fun weakness(): u8 { EFFECT_WEAKNESS }
public fun shield(): u8 { EFFECT_SHIELD }
public fun stun(): u8 { EFFECT_STUN }
public fun regen(): u8 { EFFECT_REGEN }

// ─── Setters ────────────────────────────────

public fun add_stacks(self: &mut StatusEffect, amount: u64) {
    self.stacks = self.stacks + amount;
}

public fun tick(self: &mut StatusEffect) {
    if (self.duration > 0) { self.duration = self.duration - 1; };
}

public fun set_duration(self: &mut StatusEffect, d: u8) { self.duration = d; }
public fun set_stacks(self: &mut StatusEffect, s: u64) { self.stacks = s; }

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): StatusEffect {
    StatusEffect { effect_type: 0, stacks: 1, duration: 3 }
}
