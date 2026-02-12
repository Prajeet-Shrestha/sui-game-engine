/// Inventory — Item storage with capacity.
module components::inventory;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Item Data (inline struct) ──────────────

public struct ItemData has store, copy, drop {
    item_type: u8,
    value: u64,
}

// ─── Struct ─────────────────────────────────

public struct Inventory has store, drop {
    items: vector<ItemData>,
    capacity: u64,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"inventory") }

// ─── Constructor ────────────────────────────

public fun new(capacity: u64): Inventory {
    Inventory { items: vector[], capacity }
}

public fun new_item(item_type: u8, value: u64): ItemData {
    ItemData { item_type, value }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, inv: Inventory) {
    entity.add_component(entity::inventory_bit(), key(), inv);
}

public fun remove(entity: &mut Entity): Inventory {
    entity.remove_component(entity::inventory_bit(), key())
}

public fun borrow(entity: &Entity): &Inventory {
    entity.borrow_component<Inventory>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Inventory {
    entity.borrow_mut_component<Inventory>(key())
}

// ─── Getters ────────────────────────────────

public fun items(self: &Inventory): &vector<ItemData> { &self.items }
public fun capacity(self: &Inventory): u64 { self.capacity }
public fun count(self: &Inventory): u64 { self.items.length() }
public fun is_full(self: &Inventory): bool { self.items.length() >= self.capacity }

public fun item_type(item: &ItemData): u8 { item.item_type }
public fun item_value(item: &ItemData): u64 { item.value }

// ─── Mutations ──────────────────────────────

/// Add an item. Aborts if inventory is full.
public fun add_item(self: &mut Inventory, item: ItemData) {
    assert!(!self.is_full(), 0);
    self.items.push_back(item);
}

/// Remove item by index.
public fun remove_item(self: &mut Inventory, index: u64): ItemData {
    self.items.swap_remove(index)
}

public fun set_capacity(self: &mut Inventory, cap: u64) { self.capacity = cap; }

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Inventory {
    Inventory { items: vector[], capacity: 10 }
}
