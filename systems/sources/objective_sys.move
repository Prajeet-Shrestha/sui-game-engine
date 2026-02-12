/// ObjectiveSystem — Flag / objective pickup, drop, and scoring.
module systems::objective_sys;

use sui::event;
use entity::entity::Entity;

// Components
use components::objective;

// ─── Error Constants ────────────────────────

const EAlreadyHeld: u64 = 0;
const ENotHeld: u64 = 1;
const EWrongHolder: u64 = 2;

// ─── Events ─────────────────────────────────

public struct FlagPickUpEvent has copy, drop {
    carrier_id: ID,
    flag_id: ID,
}

public struct FlagDropEvent has copy, drop {
    carrier_id: ID,
    flag_id: ID,
}

public struct FlagScoreEvent has copy, drop {
    carrier_id: ID,
    flag_id: ID,
    team_id: u8,
}

// ─── Entry Functions ────────────────────────

/// Pick up a flag/objective. The carrier's ID is stored as the holder.
public fun pick_up(
    carrier: &Entity,
    flag_entity: &mut Entity,
) {
    let obj = objective::borrow_mut(flag_entity);
    assert!(!obj.is_held(), EAlreadyHeld);

    obj.pick_up(object::id(carrier));

    event::emit(FlagPickUpEvent {
        carrier_id: object::id(carrier),
        flag_id: object::id(flag_entity),
    });
}

/// Drop a flag/objective. Clears the holder.
public fun drop_flag(
    carrier: &Entity,
    flag_entity: &mut Entity,
) {
    let obj = objective::borrow_mut(flag_entity);
    assert!(obj.is_held(), ENotHeld);

    obj.drop_objective();

    event::emit(FlagDropEvent {
        carrier_id: object::id(carrier),
        flag_id: object::id(flag_entity),
    });
}

/// Score with a flag — used when the carrier reaches the scoring zone.
/// Clears the holder and emits a score event.
public fun score(
    carrier: &Entity,
    flag_entity: &mut Entity,
    team_id: u8,
) {
    let obj = objective::borrow_mut(flag_entity);
    assert!(obj.is_held(), ENotHeld);

    obj.drop_objective();

    event::emit(FlagScoreEvent {
        carrier_id: object::id(carrier),
        flag_id: object::id(flag_entity),
        team_id,
    });
}
