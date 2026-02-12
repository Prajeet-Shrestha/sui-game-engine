/// GridSystem — 2D grid as a shared object with Table-backed cells.
module systems::grid_sys;

use sui::event;
use sui::table::{Self, Table};

// ─── Error Constants ────────────────────────

const EOutOfBounds: u64 = 0;
const ECellOccupied: u64 = 1;
const ECellEmpty: u64 = 2;

// ─── Struct ─────────────────────────────────

/// A 2D grid. Cells are stored in a Table keyed by `y * width + x`.
/// `occupied_count` is tracked for O(1) fullness checks.
public struct Grid has key {
    id: UID,
    width: u64,
    height: u64,
    cells: Table<u64, ID>,
    occupied_count: u64,
}

// ─── Events ─────────────────────────────────

public struct PlaceEvent has copy, drop {
    entity_id: ID,
    x: u64,
    y: u64,
}

public struct GridMoveEvent has copy, drop {
    entity_id: ID,
    from_x: u64,
    from_y: u64,
    to_x: u64,
    to_y: u64,
}

// ─── Constructor ────────────────────────────

/// Create a new grid and share it.
public fun create_grid(
    width: u64,
    height: u64,
    ctx: &mut TxContext,
): Grid {
    Grid {
        id: object::new(ctx),
        width,
        height,
        cells: table::new(ctx),
        occupied_count: 0,
    }
}

/// Share the grid as a shared object.
public fun share(grid: Grid) {
    transfer::share_object(grid);
}

// ─── Cell Index ─────────────────────────────

/// Convert (x, y) to a flat index.
public fun to_index(x: u64, y: u64, width: u64): u64 {
    y * width + x
}

// ─── Queries ────────────────────────────────

/// Check if coordinates are within grid bounds.
public fun in_bounds(grid: &Grid, x: u64, y: u64): bool {
    x < grid.width && y < grid.height
}

/// Check if a cell is occupied.
public fun is_occupied(grid: &Grid, x: u64, y: u64): bool {
    let idx = to_index(x, y, grid.width);
    grid.cells.contains(idx)
}

/// Get the entity ID at a cell. Aborts if cell is empty.
public fun get_entity_at(grid: &Grid, x: u64, y: u64): ID {
    assert!(in_bounds(grid, x, y), EOutOfBounds);
    let idx = to_index(x, y, grid.width);
    assert!(grid.cells.contains(idx), ECellEmpty);
    *grid.cells.borrow(idx)
}

/// Get grid width.
public fun width(grid: &Grid): u64 { grid.width }

/// Get grid height.
public fun height(grid: &Grid): u64 { grid.height }

/// Get count of occupied cells.
public fun occupied_count(grid: &Grid): u64 { grid.occupied_count }

/// Check if grid is completely full.
public fun is_full(grid: &Grid): bool {
    grid.occupied_count == grid.width * grid.height
}

// ─── Mutations ──────────────────────────────

/// Place an entity at (x, y). Aborts if out of bounds or cell occupied.
public fun place(grid: &mut Grid, entity_id: ID, x: u64, y: u64) {
    assert!(in_bounds(grid, x, y), EOutOfBounds);
    let idx = to_index(x, y, grid.width);
    assert!(!grid.cells.contains(idx), ECellOccupied);

    grid.cells.add(idx, entity_id);
    grid.occupied_count = grid.occupied_count + 1;

    event::emit(PlaceEvent { entity_id, x, y });
}

/// Remove the entity at (x, y). Aborts if out of bounds or cell empty.
public fun remove(grid: &mut Grid, x: u64, y: u64): ID {
    assert!(in_bounds(grid, x, y), EOutOfBounds);
    let idx = to_index(x, y, grid.width);
    assert!(grid.cells.contains(idx), ECellEmpty);

    let entity_id = grid.cells.remove(idx);
    grid.occupied_count = grid.occupied_count - 1;
    entity_id
}

/// Move an entity from one cell to another. Validates bounds and collision.
public fun move_on_grid(
    grid: &mut Grid,
    entity_id: ID,
    from_x: u64,
    from_y: u64,
    to_x: u64,
    to_y: u64,
) {
    assert!(in_bounds(grid, from_x, from_y), EOutOfBounds);
    assert!(in_bounds(grid, to_x, to_y), EOutOfBounds);

    let from_idx = to_index(from_x, from_y, grid.width);
    let to_idx = to_index(to_x, to_y, grid.width);

    assert!(grid.cells.contains(from_idx), ECellEmpty);
    assert!(!grid.cells.contains(to_idx), ECellOccupied);

    grid.cells.remove(from_idx);
    grid.cells.add(to_idx, entity_id);

    event::emit(GridMoveEvent {
        entity_id,
        from_x, from_y,
        to_x, to_y,
    });
}

// ─── Cleanup ────────────────────────────────

/// Destroy an empty grid. Aborts if grid has cells remaining.
public fun destroy_empty(grid: Grid) {
    let Grid { id, cells, .. } = grid;
    cells.destroy_empty();
    id.delete();
}

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun create_for_testing(width: u64, height: u64, ctx: &mut TxContext): Grid {
    create_grid(width, height, ctx)
}
