/// TurnSystem — Dual-mode turn management.
/// Simple mode: counter-based (P0 → P1 → P0 → ...)
/// Phase mode: Draw(0) → Play(1) → Combat(2) → End(3) per turn.
module systems::turn_sys;

use sui::event;

// ─── Error Constants ────────────────────────

const ENotYourTurn: u64 = 0;
const EInvalidPhase: u64 = 1;
const EGameNotStarted: u64 = 2;

// ─── Mode Constants ─────────────────────────

const MODE_SIMPLE: u8 = 0;
const MODE_PHASE: u8 = 1;

// ─── Phase Constants ────────────────────────

const PHASE_DRAW: u8 = 0;
const PHASE_PLAY: u8 = 1;
const PHASE_COMBAT: u8 = 2;
const PHASE_END: u8 = 3;
const PHASE_COUNT: u8 = 4;

// ─── Struct ─────────────────────────────────

public struct TurnState has key {
    id: UID,
    current_player: u8,
    player_count: u8,
    turn_number: u64,
    phase: u8,        // only used in phase mode
    mode: u8,         // 0=simple, 1=phase
}

// ─── Events ─────────────────────────────────

public struct TurnEndEvent has copy, drop {
    turn_number: u64,
    next_player: u8,
}

public struct PhaseAdvanceEvent has copy, drop {
    turn_number: u64,
    player: u8,
    new_phase: u8,
}

// ─── Constructor ────────────────────────────

/// Create a turn state. `mode`: 0=simple, 1=phase.
public fun create_turn_state(
    player_count: u8,
    mode: u8,
    ctx: &mut TxContext,
): TurnState {
    TurnState {
        id: object::new(ctx),
        current_player: 0,
        player_count,
        turn_number: 0,
        phase: 0,
        mode,
    }
}

/// Share the turn state as a shared object.
public fun share(state: TurnState) {
    transfer::share_object(state);
}

// ─── Getters ────────────────────────────────

public fun current_player(state: &TurnState): u8 { state.current_player }
public fun player_count(state: &TurnState): u8 { state.player_count }
public fun turn_number(state: &TurnState): u64 { state.turn_number }
public fun phase(state: &TurnState): u8 { state.phase }
public fun mode(state: &TurnState): u8 { state.mode }

// ─── Mode Accessors ─────────────────────────

public fun mode_simple(): u8 { MODE_SIMPLE }
public fun mode_phase(): u8 { MODE_PHASE }

// ─── Phase Accessors ────────────────────────

public fun phase_draw(): u8 { PHASE_DRAW }
public fun phase_play(): u8 { PHASE_PLAY }
public fun phase_combat(): u8 { PHASE_COMBAT }
public fun phase_end(): u8 { PHASE_END }

// ─── Turn Logic ─────────────────────────────

/// End the current turn, advance to next player, increment turn counter.
/// In simple mode, advances player immediately.
/// In phase mode, only advances when phase == PHASE_END.
public fun end_turn(state: &mut TurnState) {
    if (state.mode == MODE_PHASE) {
        assert!(state.phase == PHASE_END, EInvalidPhase);
    };

    state.current_player = (state.current_player + 1) % state.player_count;
    state.turn_number = state.turn_number + 1;
    state.phase = 0;

    event::emit(TurnEndEvent {
        turn_number: state.turn_number,
        next_player: state.current_player,
    });
}

/// Advance to the next phase. Only valid in phase mode.
/// Cycles: Draw → Play → Combat → End.
public fun advance_phase(state: &mut TurnState) {
    assert!(state.mode == MODE_PHASE, EInvalidPhase);
    assert!(state.phase < PHASE_END, EInvalidPhase);

    state.phase = state.phase + 1;

    event::emit(PhaseAdvanceEvent {
        turn_number: state.turn_number,
        player: state.current_player,
        new_phase: state.phase,
    });
}

/// Check if it's a given player's turn.
public fun is_player_turn(state: &TurnState, player_index: u8): bool {
    state.current_player == player_index
}

// ─── Cleanup ────────────────────────────────

public fun destroy(state: TurnState) {
    let TurnState { id, .. } = state;
    id.delete();
}

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun create_for_testing(
    player_count: u8,
    mode: u8,
    ctx: &mut TxContext,
): TurnState {
    create_turn_state(player_count, mode, ctx)
}
