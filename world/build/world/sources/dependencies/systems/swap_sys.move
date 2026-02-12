/// SwapSystem — Swap the positions of two entities on a grid.
module systems::swap_sys;

use sui::event;
use entity::entity::Entity;
use systems::grid_sys::{Self, Grid};

// Components
use components::position;

// ─── Events ─────────────────────────────────

public struct SwapEvent has copy, drop {
    entity_a_id: ID,
    entity_b_id: ID,
    a_x: u64,
    a_y: u64,
    b_x: u64,
    b_y: u64,
}

// ─── Entry Function ─────────────────────────

/// Swap the positions of two entities. Both must be on the grid.
public fun swap(
    entity_a: &mut Entity,
    entity_b: &mut Entity,
    grid: &mut Grid,
) {
    // Read positions
    let pos_a = position::borrow(entity_a);
    let a_x = pos_a.x();
    let a_y = pos_a.y();

    let pos_b = position::borrow(entity_b);
    let b_x = pos_b.x();
    let b_y = pos_b.y();

    // Swap on grid: remove both, re-place swapped
    grid_sys::remove(grid, a_x, a_y);
    grid_sys::remove(grid, b_x, b_y);
    grid_sys::place(grid, object::id(entity_a), b_x, b_y);
    grid_sys::place(grid, object::id(entity_b), a_x, a_y);

    // Swap position components
    let pos_a_mut = position::borrow_mut(entity_a);
    pos_a_mut.set(b_x, b_y);

    let pos_b_mut = position::borrow_mut(entity_b);
    pos_b_mut.set(a_x, a_y);

    event::emit(SwapEvent {
        entity_a_id: object::id(entity_a),
        entity_b_id: object::id(entity_b),
        a_x, a_y,
        b_x, b_y,
    });
}
