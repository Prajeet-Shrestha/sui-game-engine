/// MapProgress — Roguelike map progression tracking.
module components::map_progress;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

public struct MapProgress has store, drop {
    current_floor: u8,
    current_node: u8,
    path_chosen: vector<u8>,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"map_progress") }

// ─── Constructor ────────────────────────────

public fun new(): MapProgress {
    MapProgress {
        current_floor: 0,
        current_node: 0,
        path_chosen: vector[],
    }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, mp: MapProgress) {
    entity.add_component(entity::map_progress_bit(), key(), mp);
}

public fun remove(entity: &mut Entity): MapProgress {
    entity.remove_component(entity::map_progress_bit(), key())
}

public fun borrow(entity: &Entity): &MapProgress {
    entity.borrow_component<MapProgress>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut MapProgress {
    entity.borrow_mut_component<MapProgress>(key())
}

// ─── Getters ────────────────────────────────

public fun current_floor(self: &MapProgress): u8 { self.current_floor }
public fun current_node(self: &MapProgress): u8 { self.current_node }
public fun path_chosen(self: &MapProgress): &vector<u8> { &self.path_chosen }

// ─── Setters ────────────────────────────────

public fun advance_floor(self: &mut MapProgress) {
    self.current_floor = self.current_floor + 1;
    self.current_node = 0;
}

public fun set_node(self: &mut MapProgress, node: u8) {
    self.current_node = node;
}

public fun choose_path(self: &mut MapProgress, node: u8) {
    self.path_chosen.push_back(node);
    self.current_node = node;
}

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): MapProgress {
    MapProgress { current_floor: 0, current_node: 0, path_chosen: vector[] }
}
