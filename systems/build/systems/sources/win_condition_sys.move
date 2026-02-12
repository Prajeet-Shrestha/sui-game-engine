/// WinConditionSystem — Generic game-over emitter.
/// Provides reusable checks (elimination) and a generic declare_winner function.
/// Game-specific win conditions (board full, king captured, flag scored, etc.)
/// belong in the game module, which calls `declare_winner()` when its condition is met.
module systems::win_condition_sys;

use sui::clock::Clock;
use sui::event;
use entity::entity::Entity;

// Components
use components::health;

// ─── Condition Constants ────────────────────

const CONDITION_ELIMINATION: u8 = 0;
const CONDITION_BOARD_FULL: u8 = 1;
const CONDITION_OBJECTIVE: u8 = 2;
const CONDITION_SURRENDER: u8 = 3;
const CONDITION_TIMEOUT: u8 = 4;
const CONDITION_CUSTOM: u8 = 255;

// ─── Events ─────────────────────────────────

public struct GameOverEvent has copy, drop {
    winner_id: ID,
    condition: u8,
    timestamp: u64,
}

// ─── Condition Accessors ────────────────────

public fun condition_elimination(): u8 { CONDITION_ELIMINATION }
public fun condition_board_full(): u8 { CONDITION_BOARD_FULL }
public fun condition_objective(): u8 { CONDITION_OBJECTIVE }
public fun condition_surrender(): u8 { CONDITION_SURRENDER }
public fun condition_timeout(): u8 { CONDITION_TIMEOUT }
public fun condition_custom(): u8 { CONDITION_CUSTOM }

// ─── Generic Checks ─────────────────────────

/// Check if an entity has been eliminated (health == 0).
public fun check_elimination(entity: &Entity): bool {
    let h = health::borrow(entity);
    !h.is_alive()
}

// ─── Declare Winner ─────────────────────────

/// Emit a GameOverEvent. Call this from your game module when a win condition is met.
public fun declare_winner(
    winner_id: ID,
    condition: u8,
    clock: &Clock,
) {
    event::emit(GameOverEvent {
        winner_id,
        condition,
        timestamp: clock.timestamp_ms(),
    });
}
