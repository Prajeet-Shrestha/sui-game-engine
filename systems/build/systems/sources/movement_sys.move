/// MovementSystem — Move entities on a grid with rule validation.
/// Validates bounds, speed range, movement pattern, and collision.
module systems::movement_sys;

use sui::event;
use entity::entity::Entity;
use systems::grid_sys::{Self, Grid};

// Components
use components::position;
use components::movement;

// ─── Error Constants ────────────────────────

const EOutOfRange: u64 = 0;
const EOutOfBounds: u64 = 1;
const ECellOccupied: u64 = 2;
const EInvalidPattern: u64 = 3;

// ─── Movement Pattern Constants ─────────────
// Mirrors components::movement patterns

const PATTERN_WALK: u8 = 0;
const PATTERN_FLY: u8 = 1;
const PATTERN_TELEPORT: u8 = 2;
const PATTERN_DIAGONAL: u8 = 3;
const PATTERN_L_SHAPE: u8 = 4;

// ─── Events ─────────────────────────────────

public struct MoveEvent has copy, drop {
    entity_id: ID,
    from_x: u64,
    from_y: u64,
    to_x: u64,
    to_y: u64,
}

// ─── Inline Helpers ─────────────────────────

fun abs_diff(a: u64, b: u64): u64 {
    if (a >= b) { a - b } else { b - a }
}

fun manhattan_distance(x1: u64, y1: u64, x2: u64, y2: u64): u64 {
    abs_diff(x1, x2) + abs_diff(y1, y2)
}

/// Validate movement pattern.
fun validate_pattern(pattern: u8, from_x: u64, from_y: u64, to_x: u64, to_y: u64): bool {
    let dx = abs_diff(from_x, to_x);
    let dy = abs_diff(from_y, to_y);

    if (pattern == PATTERN_WALK) {
        // Cardinal only (up/down/left/right), 1 step at a time checked by speed
        (dx + dy) > 0
    } else if (pattern == PATTERN_FLY) {
        // Any direction, any distance (speed is the only limit)
        (dx + dy) > 0
    } else if (pattern == PATTERN_TELEPORT) {
        // Any cell (no path restriction)
        true
    } else if (pattern == PATTERN_DIAGONAL) {
        // Diagonal only
        dx == dy && dx > 0
    } else if (pattern == PATTERN_L_SHAPE) {
        // Chess knight: 2+1 or 1+2
        (dx == 2 && dy == 1) || (dx == 1 && dy == 2)
    } else {
        false
    }
}

// ─── Entry Function ─────────────────────────

/// Move an entity to (to_x, to_y). Validates:
/// 1. Grid bounds
/// 2. Destination not occupied
/// 3. Distance <= speed
/// 4. Movement pattern is valid
public fun move_entity(
    entity: &mut Entity,
    grid: &mut Grid,
    to_x: u64,
    to_y: u64,
) {
    // Read current position
    let pos = position::borrow(entity);
    let from_x = pos.x();
    let from_y = pos.y();

    // Validate bounds
    assert!(grid_sys::in_bounds(grid, to_x, to_y), EOutOfBounds);

    // Validate destination not occupied
    assert!(!grid_sys::is_occupied(grid, to_x, to_y), ECellOccupied);

    // Read movement component
    let mov = movement::borrow(entity);
    let speed = (mov.speed() as u64);
    let pattern = mov.move_pattern();

    // Validate distance within speed
    let dist = manhattan_distance(from_x, from_y, to_x, to_y);
    assert!(dist <= speed, EOutOfRange);

    // Validate movement pattern
    assert!(validate_pattern(pattern, from_x, from_y, to_x, to_y), EInvalidPattern);

    // Update grid
    grid_sys::move_on_grid(grid, object::id(entity), from_x, from_y, to_x, to_y);

    // Update position component
    let pos_mut = position::borrow_mut(entity);
    pos_mut.set(to_x, to_y);

    event::emit(MoveEvent {
        entity_id: object::id(entity),
        from_x, from_y,
        to_x, to_y,
    });
}
