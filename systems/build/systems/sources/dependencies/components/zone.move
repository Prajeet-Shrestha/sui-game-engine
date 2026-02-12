/// Zone — Territory / control point data.
module components::zone;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

public struct Zone has store, copy, drop {
    zone_type: u8,           // 0=neutral, 1=control_point, 2=spawn, etc.
    controlled_by: u8,       // team_id of controller (0 = uncontrolled)
    capture_progress: u64,   // progress toward capture (0..100)
}

// ─── Zone Type Constants ────────────────────

const ZONE_NEUTRAL: u8 = 0;
const ZONE_CONTROL_POINT: u8 = 1;
const ZONE_SPAWN: u8 = 2;

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"zone") }

// ─── Constructor ────────────────────────────

public fun new(zone_type: u8): Zone {
    Zone { zone_type, controlled_by: 0, capture_progress: 0 }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, zone: Zone) {
    entity.add_component(entity::zone_bit(), key(), zone);
}

public fun remove(entity: &mut Entity): Zone {
    entity.remove_component(entity::zone_bit(), key())
}

public fun borrow(entity: &Entity): &Zone {
    entity.borrow_component<Zone>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Zone {
    entity.borrow_mut_component<Zone>(key())
}

// ─── Getters ────────────────────────────────

public fun zone_type(self: &Zone): u8 { self.zone_type }
public fun controlled_by(self: &Zone): u8 { self.controlled_by }
public fun capture_progress(self: &Zone): u64 { self.capture_progress }
public fun is_controlled(self: &Zone): bool { self.controlled_by != 0 }

// ─── Type Accessors ─────────────────────────

public fun zone_neutral(): u8 { ZONE_NEUTRAL }
public fun zone_control_point(): u8 { ZONE_CONTROL_POINT }
public fun zone_spawn(): u8 { ZONE_SPAWN }

// ─── Setters ────────────────────────────────

public fun set_controlled_by(self: &mut Zone, team_id: u8) {
    self.controlled_by = team_id;
}

public fun set_capture_progress(self: &mut Zone, progress: u64) {
    self.capture_progress = progress;
}

public fun reset(self: &mut Zone) {
    self.controlled_by = 0;
    self.capture_progress = 0;
}

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Zone {
    Zone { zone_type: 1, controlled_by: 0, capture_progress: 0 }
}
