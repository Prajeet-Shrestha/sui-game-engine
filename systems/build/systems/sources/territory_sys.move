/// TerritorySystem — Zone claiming, contesting, and capturing.
module systems::territory_sys;

use sui::event;
use entity::entity::Entity;

// Components
use components::zone;
use components::team;

// ─── Error Constants ────────────────────────

const EAlreadyControlled: u64 = 0;
const ENotContested: u64 = 1;
const ECaptureNotComplete: u64 = 2;

// ─── Events ─────────────────────────────────

public struct ZoneClaimEvent has copy, drop {
    zone_id: ID,
    team_id: u8,
}

public struct ZoneContestEvent has copy, drop {
    zone_id: ID,
    team_id: u8,
    progress: u64,
}

public struct ZoneCaptureEvent has copy, drop {
    zone_id: ID,
    team_id: u8,
}

// ─── Entry Functions ────────────────────────

/// Claim an uncontrolled zone instantly. Aborts if zone already controlled.
public fun claim(
    entity: &Entity,
    zone_entity: &mut Entity,
) {
    let z = zone::borrow_mut(zone_entity);
    assert!(!z.is_controlled(), EAlreadyControlled);

    let t = team::borrow(entity);
    let team_id = t.team_id();

    z.set_controlled_by(team_id);
    z.set_capture_progress(100);

    event::emit(ZoneClaimEvent {
        zone_id: object::id(zone_entity),
        team_id,
    });
}

/// Contest a zone, incrementing capture progress.
/// Used when an entity is on or adjacent to a zone.
public fun contest(
    entity: &Entity,
    zone_entity: &mut Entity,
    amount: u64,
) {
    let t = team::borrow(entity);
    let team_id = t.team_id();

    let z = zone::borrow_mut(zone_entity);
    let current = z.capture_progress();
    let new_progress = std::u64::min(current + amount, 100);
    z.set_capture_progress(new_progress);
    z.set_controlled_by(team_id);

    event::emit(ZoneContestEvent {
        zone_id: object::id(zone_entity),
        team_id,
        progress: new_progress,
    });
}

/// Finalize capture of a zone. Requires progress == 100.
public fun capture_zone(
    zone_entity: &mut Entity,
    team_id: u8,
) {
    let z = zone::borrow_mut(zone_entity);
    assert!(z.capture_progress() >= 100, ECaptureNotComplete);

    z.set_controlled_by(team_id);
    z.set_capture_progress(100);

    event::emit(ZoneCaptureEvent {
        zone_id: object::id(zone_entity),
        team_id,
    });
}
