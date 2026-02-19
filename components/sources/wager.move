/// Wager — Per-player wager data for the wagering subsystem.
///
/// Tracks the amount wagered, the player's address, and the current
/// status of the wager (pending, locked, won, lost, refunded).
module components::wager;

use std::ascii::{Self, String};
use entity::entity::{Self, Entity};

// ─── Status Constants ───────────────────────

const STATUS_PENDING: u8  = 0;
const STATUS_LOCKED: u8   = 1;
const STATUS_WON: u8      = 2;
const STATUS_LOST: u8     = 3;
const STATUS_REFUNDED: u8 = 4;

// ─── Error Constants ────────────────────────

const EInvalidStatus: u64 = 0;

// ─── Struct ─────────────────────────────────

public struct Wager has store, copy, drop {
    amount: u64,      // MIST
    status: u8,       // 0=pending, 1=locked, 2=won, 3=lost, 4=refunded
    player: address,
}

// ─── Key ────────────────────────────────────

public fun key(): String { ascii::string(b"wager") }

// ─── Constructor ────────────────────────────

/// Create a new wager in PENDING status.
public fun new(amount: u64, player: address): Wager {
    Wager { amount, status: STATUS_PENDING, player }
}

// ─── Entity Integration ─────────────────────

public fun add(entity: &mut Entity, wager: Wager) {
    entity.add_component(entity::wager_bit(), key(), wager);
}

public fun remove(entity: &mut Entity): Wager {
    entity.remove_component(entity::wager_bit(), key())
}

public fun borrow(entity: &Entity): &Wager {
    entity.borrow_component<Wager>(key())
}

public fun borrow_mut(entity: &mut Entity): &mut Wager {
    entity.borrow_mut_component<Wager>(key())
}

// ─── Getters ────────────────────────────────

public fun amount(self: &Wager): u64 { self.amount }
public fun status(self: &Wager): u8 { self.status }
public fun player(self: &Wager): address { self.player }

public fun is_pending(self: &Wager): bool { self.status == STATUS_PENDING }
public fun is_locked(self: &Wager): bool { self.status == STATUS_LOCKED }
public fun is_won(self: &Wager): bool { self.status == STATUS_WON }
public fun is_lost(self: &Wager): bool { self.status == STATUS_LOST }
public fun is_refunded(self: &Wager): bool { self.status == STATUS_REFUNDED }

// ─── Setters ────────────────────────────────

public fun set_status(self: &mut Wager, status: u8) {
    assert!(status <= STATUS_REFUNDED, EInvalidStatus);
    self.status = status;
}

// ─── Status Constants Accessors ─────────────

public fun status_pending(): u8 { STATUS_PENDING }
public fun status_locked(): u8 { STATUS_LOCKED }
public fun status_won(): u8 { STATUS_WON }
public fun status_lost(): u8 { STATUS_LOST }
public fun status_refunded(): u8 { STATUS_REFUNDED }

// ─── Test Helpers ───────────────────────────

#[test_only]
public fun new_for_testing(): Wager {
    Wager { amount: 10_000_000_000, status: STATUS_PENDING, player: @0x1 }
}
