/// Identity — Name and entity type classification.
module components::identity;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

/// `store, drop` — String is not copyable.
public struct Identity has store, drop {
    name: String,
    entity_type: u8,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"identity") }

// ─── Constructor ────────────────────────────

public fun new(name: String, entity_type: u8): Identity {
    Identity { name, entity_type }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, identity: Identity) {
    entity.add_component(entity::identity_bit(), key(), identity);
}

public fun remove(entity: &mut Entity): Identity {
    entity.remove_component(entity::identity_bit(), key())
}

public fun borrow(entity: &Entity): &Identity {
    entity.borrow_component<Identity>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Identity {
    entity.borrow_mut_component<Identity>(key())
}

// ─── Getters ────────────────────────────────

public fun name(self: &Identity): String { self.name }
public fun get_entity_type(self: &Identity): u8 { self.entity_type }

// ─── Setters ────────────────────────────────

public fun set_name(self: &mut Identity, name: String) { self.name = name; }
public fun set_entity_type(self: &mut Identity, t: u8) { self.entity_type = t; }

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Identity {
    Identity { name: ascii::string(b"test"), entity_type: 0 }
}
