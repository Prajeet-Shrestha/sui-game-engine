/// Team — Team affiliation for PvP / faction games.
module components::team;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Struct ─────────────────────────────────

public struct Team has store, copy, drop {
    team_id: u8,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"team") }

// ─── Constructor ────────────────────────────

public fun new(team_id: u8): Team {
    Team { team_id }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, team: Team) {
    entity.add_component(entity::team_bit(), key(), team);
}

public fun remove(entity: &mut Entity): Team {
    entity.remove_component(entity::team_bit(), key())
}

public fun borrow(entity: &Entity): &Team {
    entity.borrow_component<Team>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Team {
    entity.borrow_mut_component<Team>(key())
}

// ─── Getters ────────────────────────────────

public fun team_id(self: &Team): u8 { self.team_id }

/// Check if two teams are the same.
public fun same_team(a: &Team, b: &Team): bool { a.team_id == b.team_id }

// ─── Setters ────────────────────────────────

public fun set_team_id(self: &mut Team, team_id: u8) { self.team_id = team_id; }

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Team { Team { team_id: 0 } }
