/// MapSystem — Roguelike map progression: choose paths and advance floors.
module systems::map_sys;

use sui::event;
use entity::entity::Entity;

// Components
use components::map_progress;

// ─── Events ─────────────────────────────────

public struct PathChosenEvent has copy, drop {
    entity_id: ID,
    floor: u8,
    node: u8,
}

public struct FloorAdvancedEvent has copy, drop {
    entity_id: ID,
    new_floor: u8,
}

// ─── Entry Functions ────────────────────────

/// Choose a path (node) on the current floor.
public fun choose_path(entity: &mut Entity, node: u8) {
    let mp = map_progress::borrow(entity);
    let floor = mp.current_floor();

    let mp_mut = map_progress::borrow_mut(entity);
    mp_mut.choose_path(node);

    event::emit(PathChosenEvent {
        entity_id: object::id(entity),
        floor,
        node,
    });
}

/// Advance to the next floor (after completing the current one).
public fun advance_floor(entity: &mut Entity) {
    let mp = map_progress::borrow_mut(entity);
    mp.advance_floor();

    let new_floor = mp.current_floor();

    event::emit(FloorAdvancedEvent {
        entity_id: object::id(entity),
        new_floor,
    });
}

/// Get the current floor number.
public fun current_floor(entity: &Entity): u8 {
    let mp = map_progress::borrow(entity);
    mp.current_floor()
}

/// Get the current node on the map.
public fun current_node(entity: &Entity): u8 {
    let mp = map_progress::borrow(entity);
    mp.current_node()
}
