/// CaptureSystem — Remove a captured piece from the grid.
module systems::capture_sys;

use sui::event;
use entity::entity::Entity;
use systems::grid_sys::{Self, Grid};

// Components
use components::position;

// ─── Events ─────────────────────────────────

public struct CaptureEvent has copy, drop {
    capturer_id: ID,
    target_id: ID,
    x: u64,
    y: u64,
}

// ─── Entry Function ─────────────────────────

/// Capture a target entity: remove it from the grid.
/// The capturer entity is provided for event tracking.
/// The target's position component is left intact (caller can remove/destroy the entity).
public fun capture(
    capturer: &Entity,
    target: &Entity,
    grid: &mut Grid,
) {
    let target_pos = position::borrow(target);
    let x = target_pos.x();
    let y = target_pos.y();

    // Remove target from grid
    grid_sys::remove(grid, x, y);

    event::emit(CaptureEvent {
        capturer_id: object::id(capturer),
        target_id: object::id(target),
        x,
        y,
    });
}
